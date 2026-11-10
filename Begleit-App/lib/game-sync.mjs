// ForeverAI 0.9: opted-in download of public Forever data into a static WoW Lua
// data file. No game memory access, key injection, HTTP inside WoW or code from
// remote sources. The UI only sees changes on the next login or /reload.
import {promises as fs} from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import {AppError} from './common.mjs';
import {atomicWrite} from './storage.mjs';

export const SYNC_MIN_INTERVAL_MS=6*60*60*1000;
const SOURCE='https://forevercompanion.io/developers';
const PIN_BY_DUNGEON={
  'deadmines':'deadmines','shadowfang-keep':'shadowfang','wailing-caverns':'wailing',
  'gnomeregan':'gnomeregan','stockades':'stockades','the-stockade':'stockades',
  'ragefire-chasm':'ragefire','hall-of-thanes':'thanes'
};
const limit=(x,n=140)=>typeof x==='string'?Array.from(x.replace(/[\u0000-\u001f\u007f]/g,' ')).slice(0,n).join('').trim():'';
const arr=x=>Array.isArray(x)?x:[];
const number=(x,max=10000000)=>Number.isInteger(x)&&x>=0&&x<=max?x:null;
const slug=x=>/^[a-z0-9][a-z0-9-]{0,70}$/.test(x||'')?x:'';
function mapDungeon(d){
  if(!d||!slug(d.id)||!limit(d.name))return null;
  return {id:d.id,name:limit(d.name),zone:limit(d.zone),entrance:limit(d.entrance,190),
    min:number(d.minLevel,60),max:number(d.maxLevel,60),
    status:limit(d.status,30),pinKey:PIN_BY_DUNGEON[d.id]||''};
}
function mapItem(d){
  const id=number(d?.id,9999999);if(!id||!limit(d.name))return null;
  return {id,name:limit(d.name),slot:limit(d.slot,45),weaponType:limit(d.weaponType,40),
    armor:limit(d.armor,20),quality:limit(d.quality,25),
    level:number(d.requiredLevel,60),itemLevel:number(d.itemLevel,2000),
    classicOnly:d.classicOnly===true,verified:number(d.verified,999999)||0,
    stats:arr(d.stats).slice(0,16).map(x=>limit(x,36)).filter(Boolean),drops:[]};
}
function mapQuest(d){
  const id=number(d?.questId,9999999);if(!id||!limit(d.name))return null;
  return {id,name:limit(d.name),level:number(d.level,60),min:number(d.minLevel,60),
    giver:limit(d.giver),location:limit(d.location),zone:limit(d.zone),
    faction:limit(d.faction,15),dungeonId:slug(d.dungeon?.id)||'',
    type:limit(d.type,20),classic:d.confidence==='classic',
    classes:arr(d.classes).slice(0,12).map(x=>limit(x,25)).filter(Boolean)};
}
function mapRare(d){
  if(!slug(d?.id)||!limit(d.name))return null;
  // The API exposes coordinates but no UiMapID; never fabricate one.
  return {id:d.id,name:limit(d.name),zone:limit(d.zone),levels:limit(d.levels,20),
    coords:arr(d.coords).slice(0,8).map(x=>limit(x,40)).filter(Boolean),
    verified:number(d.verified,999999)||0};
}
function mergeLoot(items,dungeons,details){
  const byId=new Map(items.map(i=>[i.id,i]));
  for(const detail of details){
    if(!detail||!slug(detail.id))continue;
    const dungeon=dungeons.find(d=>d.id===detail.id);
    if(!dungeon)continue;
    for(const loot of arr(detail.loot)){
      const id=number(loot.itemId,9999999);if(!id)continue;
      let item=byId.get(id);
      if(!item){item=mapItem({id,name:loot.name,slot:loot.slot,quality:loot.quality});if(!item)continue;byId.set(id,item);}
      if(item.drops.length<6)item.drops.push({dungeonId:dungeon.id,boss:limit(loot.source,100)});
    }
  }
  return Array.from(byId.values()).sort((a,b)=>a.id-b.id);
}

// The provider offers 500 rows/page; page caps prevent runaway downloads.
// If data exceeds the caps, the cache reports incompleteness explicitly.
async function pages(online,name,maxPages){
  const result=[];let incomplete=false,updatedAt='';
  for(let i=0;i<maxPages;i++){
    const r=await online.get('/'+name,{limit:500,offset:i*500});
    if(!Array.isArray(r.data))throw new AppError('sync_invalid_data');
    result.push(...r.data);updatedAt=limit(r.meta?.updatedAt,50)||updatedAt;
    if(!r.page?.next)return {rows:result,incomplete,updatedAt};
    if(i===maxPages-1)incomplete=true;
  }
  return {rows:result,incomplete,updatedAt};
}
export async function downloadSnapshot(online,{clock=()=>new Date().toISOString()}={}){
  const dungeonResponse=await online.get('/dungeons');
  if(!Array.isArray(dungeonResponse.data))throw new AppError('sync_invalid_dungeons');
  const dungeons=dungeonResponse.data.map(mapDungeon).filter(x=>x&&x.status!=='announced').slice(0,30);
  if(!dungeons.length)throw new AppError('sync_empty_dungeons');
  const details=[];for(const d of dungeons){const payload=await online.get('/dungeons/'+d.id);if(payload.data&&typeof payload.data==='object')details.push(payload.data);}
  const itemRows=await pages(online,'items',6);
  const questRows=await pages(online,'quests',4);
  const rares=await online.get('/rares');
  if(!Array.isArray(rares.data))throw new AppError('sync_invalid_rares');
  const items=mergeLoot(itemRows.rows.map(mapItem).filter(Boolean),dungeons,details);
  const quests=questRows.rows.map(mapQuest).filter(Boolean);
  return {schema:1,source:SOURCE,syncedAt:clock(),updatedAt:limit(dungeonResponse.meta?.updatedAt,50),
    incomplete:itemRows.incomplete||questRows.incomplete||dungeonResponse.data.length>30,
    dungeons,items,quests,rares:rares.data.slice(0,400).map(mapRare).filter(Boolean)};
}

// Strict serialization: all data is normalized first; every byte from the
// network is encoded as an inert Lua string literal, never executable Lua.
function luaString(s){
  let out='"';for(const b of Buffer.from(String(s),'utf8')){
    if(b>=32&&b<=126&&b!==34&&b!==92)out+=String.fromCharCode(b);
    else out+='\\'+String(b).padStart(3,'0');
  }return out+'"';
}
function luaValue(x){
  if(x==null)return 'nil';
  if(typeof x==='string')return luaString(x);
  if(typeof x==='boolean')return x?'true':'false';
  if(typeof x==='number')return Number.isFinite(x)?String(x):'nil';
  if(Array.isArray(x))return '{'+x.map(luaValue).join(',')+'}';
  if(typeof x==='object')return '{'+Object.entries(x).map(([k,v])=>{
    if(!/^[A-Za-z_][A-Za-z0-9_]*$/.test(k))throw new AppError('sync_bad_key');
    return k+'='+luaValue(v);
  }).join(',')+'}';
  throw new AppError('sync_bad_value');
}
export function luaSnapshot(snapshot){
  if(!snapshot||snapshot.schema!==1)throw new AppError('sync_bad_snapshot');
  const text='-- ForeverAI: generated static data; never edit while WoW is open.\n' +
    '-- Source: '+SOURCE+' (community, not Blizzard). Re-read on login or /reload.\n' +
    'local _, FG = ...\nFG.SyncData = '+luaValue(snapshot)+'\n';
  if(Buffer.byteLength(text,'utf8')>6*1024*1024)throw new AppError('sync_too_large');
  return text;
}

export async function findInstalledAddon(preferred=''){
  const candidates=[];
  if(preferred&&typeof preferred==='string')candidates.push(preferred);
  if(process.env.FOREVERAI_GAME_DIR)candidates.push(process.env.FOREVERAI_GAME_DIR);
  if(process.platform==='win32'){
    const roots=[process.env['ProgramFiles(x86)'],process.env.ProgramFiles,'C:\\Program Files (x86)','C:\\Program Files'].filter(Boolean);
    for(const root of roots)candidates.push(path.join(root,'World of Warcraft','_forever_'));
  }
  for(const c of candidates){
    if(typeof c!=='string'||c.length>1024||!path.isAbsolute(c))continue;
    const base=path.resolve(c),possibilities=[base,path.join(base,'Interface','AddOns','ForeverAI'),path.join(base,'AddOns','ForeverAI'),path.join(base,'ForeverAI')];
    for(const addon of possibilities){
      if(path.basename(addon)!=='ForeverAI'||path.basename(path.dirname(addon))!=='AddOns'||path.basename(path.dirname(path.dirname(addon)))!=='Interface')continue;
      // WoW Forever is a distinct product, not Retail or Classic.
      if(path.basename(path.dirname(path.dirname(path.dirname(addon))))!=='_forever_')continue;
      const toc=path.join(addon,'ForeverAI.toc');
      try{const info=await fs.stat(toc);if(!info.isFile())continue;
        const content=await fs.readFile(toc,'utf8');if(!/^## Interface:\s*16001\b/m.test(content))continue;
        return addon;
      }catch{}
    }
  }
  return null;
}
export class GameDataSync{
  constructor({directory,online,now=()=>Date.now(),discover=findInstalledAddon}={}){
    this.directory=directory;this.online=online;this.now=now;this.discover=discover;
    this.file=path.join(directory,'game-sync.json');this.config={path:'',enabled:false};this.state={busy:false,lastSuccess:null,lastError:null,counts:null,addonPath:''};this.running=null;
  }
  async load(){
    try{const v=JSON.parse(await fs.readFile(this.file,'utf8'));
      if(typeof v.path==='string'&&v.path.length<1024)this.config.path=v.path;
      this.config.enabled=v.enabled===true;
      if(typeof v.lastSuccess==='number'&&v.lastSuccess>=0)this.state.lastSuccess=v.lastSuccess;
      if(v.counts&&typeof v.counts==='object')this.state.counts=v.counts;
    }catch(e){if(e.code!=='ENOENT')throw new AppError('sync_settings_invalid');}
    const found=await this.discover(this.config.path);if(found)this.state.addonPath=found;
  }
  status(){return {...this.state,enabled:this.config.enabled,configured:!!this.config.path,gamePath:this.config.path||'',source:SOURCE};}
  async configure({path:folder,enabled}={}){
    if(typeof folder!=='string'||folder.length<1||folder.length>1024||typeof enabled!=='boolean')throw new AppError('sync_bad_settings');
    const addon=await this.discover(folder);
    if(!addon)throw new AppError('sync_game_not_found','Bitte den WoW-Forever-Ordner mit Interface/AddOns/ForeverAI auswählen (Interface 16001).');
    this.config={path:folder,enabled};this.state.addonPath=addon;
    await atomicWrite(this.file,JSON.stringify({...this.config,lastSuccess:this.state.lastSuccess,counts:this.state.counts}));
    return this.status();
  }
  async refresh({force=false}={}){
    if(this.running)return this.running;
    if(!this.config.enabled)return this.status();
    if(!force&&this.state.lastSuccess!=null&&this.now()-this.state.lastSuccess<SYNC_MIN_INTERVAL_MS){
      // The user may have upgraded/replaced ForeverAI's folder since the last
      // sync. A fresh bundled placeholder must never suppress restoration.
      const addon=await this.discover(this.config.path);
      if(addon){
        const current=await fs.readFile(path.join(addon,'SyncData.lua'),'utf8').catch(()=>null);
        if(current&&current.startsWith('-- ForeverAI: generated static data;'))return this.status();
      }
    }
    this.running=(async()=>{
      this.state.busy=true;this.state.lastError=null;
      try{
        const addon=await this.discover(this.config.path);
        if(!addon)throw new AppError('sync_game_not_found','ForeverAI nicht im WoW-Forever-Addonordner gefunden.');
        const data=await downloadSnapshot(this.online);
        // Never replace an existing data file until all downloads and
        // normalization completed. The previous good cache survives errors.
        await atomicWrite(path.join(addon,'SyncData.lua'),luaSnapshot(data));
        this.state.addonPath=addon;this.state.lastSuccess=this.now();
        this.state.counts={dungeons:data.dungeons.length,items:data.items.length,quests:data.quests.length,rares:data.rares.length,incomplete:data.incomplete,updatedAt:data.updatedAt};
        await atomicWrite(this.file,JSON.stringify({...this.config,lastSuccess:this.state.lastSuccess,counts:this.state.counts}));
      }catch(e){this.state.lastError=e instanceof AppError?e.code:'sync_failed';throw e;}
      finally{this.state.busy=false;}
      return this.status();
    })();
    try{return await this.running;}finally{this.running=null;}
  }
}
