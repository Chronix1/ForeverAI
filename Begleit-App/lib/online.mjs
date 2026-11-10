// Public, read-only WoW Forever data. All upstream requests are opt-in and host-pinned.
import {AppError} from './common.mjs';
import {limitedJSON} from './network.mjs';
import {searchPacket} from './bridge.mjs';

export const SOURCE=Object.freeze({name:'Forever Companion',url:'https://forevercompanion.io',docs:'https://forevercompanion.io/developers'});
const ROOT='https://forevercompanion.io/api/v1';
const KINDS=new Set(['auto','dungeon','item','quest','rare']);
const ALIASES=[
  {names:['todesminen','deadmines'],en:'deadmines'},
  {names:['burg schattenfang','schattenfang','shadowfang keep','sfk'],en:'shadowfang keep'},
  {names:['höhlen des wehklagens','hoehlen des wehklagens','wailing caverns'],en:'wailing caverns'},
  {names:['gnomeregan'],en:'gnomeregan'},
  {names:['verlies','stockades','stockade'],en:'stockade'},
  {names:['flammenschlund','ragefire chasm'],en:'ragefire chasm'},
  {names:['halle der thanen','hall of thanes'],en:'hall of thanes'}
];
function norm(s){return String(s||'').normalize('NFKD').toLowerCase().replace(/ß/g,'ss').replace(/[\u0300-\u036f]/g,'').replace(/[^a-z0-9 ]/g,' ').replace(/\s+/g,' ').trim();}
const STOP=new Set('wo ist sind finde finden ich wir du was wie gehen machen empfehlen kann koennen konnen darf spiele spielen bekomme bekommen welche welcher welchen fuer fur mein meine meinen einer einem der die das den dem ein eine und oder von in im am zum zur nach aus bei mit mir kann bitte zeig zeige suchen suche find where what which is are do does i we can get me please show location of the for from to at in my best better weapon gear item items gegenstand gegenstande gegenstaende waffen waffe dungeon dungeons dungen instanz instanzen level stufe krieger warrior drop drops'.split(' '));
const GEAR=/(waffe|weapon|schwert|sword|säbel|sabel|sabre|klinge|blade|beute|loot|drop|items?|gegenst|ausrüst|ausrust|equip|gear|armor|rüst|rust|shield|schild)/i;
function terms(s){return norm(s).split(' ').filter(w=>w.length>2&&!STOP.has(w)&&!/^\d+$/.test(w));}
function levelFrom(s){const m=norm(s).match(/(?:level|lvl|stufe)\s*(\d{1,2})/);return m?Number(m[1]):undefined;}
function safe(s,n=150){return [...String(s||'').replace(/[|\x00-\x1f\x7f]/g,' ')].slice(0,n).join('');}
function slug(s){return /^[a-z0-9][a-z0-9_-]{0,79}$/.test(String(s))?String(s):'';}
function arr(v){return Array.isArray(v)?v:[];}
function int(v,min=0,max=100000000){return Number.isInteger(v)&&v>=min&&v<=max?v:null;}
function aliasFor(question){const q=norm(question);return ALIASES.find(a=>a.names.some(t=>q.includes(norm(t))));}
function category(question){const q=norm(question);if(aliasFor(question)||/\b(dungeon|dungeons|dungen|instanz|instanzen|raid|verlies)\b/.test(q))return 'dungeon';if(/\b(rare|rares|selten|elite|spawn)\b/.test(q))return 'rare';if(/\b(quest|quests|aufgabe|aufgaben|questgeber)\b/.test(q))return 'quest';if(GEAR.test(question))return 'item';return 'auto';}
function searchTerm(question,kind){const q=norm(question);if(kind==='item'){
  if(/\b(schwert|sword|schwerter)\b/.test(q))return 'sword';
  if(/\b(schild|shield)\b/.test(q))return 'shield';
  if(/\b(axt|axe|axes)\b/.test(q))return 'axe';
  if(/\b(stab|staff)\b/.test(q))return 'staff';
}return terms(question).slice(0,4).join(' ');}
function row(kind,id,name,detail,target=''){
  if(typeof name!=='string'||!name.trim())return null;
  return {kind,id:safe(id,80),name:safe(name,125),detail:safe(detail,210),target:slug(target)};
}
function distinct(rows,max=24){const results=[],seen=new Set();for(const r of rows){if(!r)continue;const key=[r.kind,r.id,r.target].join(':');if(seen.has(key))continue;seen.add(key);results.push(r);if(results.length>=max)break;}return results;}
function stamp(payload){const date=payload?.meta?.updatedAt;return typeof date==='string'&&Number.isFinite(Date.parse(date))?date:null;}
function matchesDungeon(d,question){const alias=aliasFor(question);if(alias)return norm(d.name).includes(alias.en)||norm(d.id).includes(alias.en.replaceAll(' ',' '));const t=terms(question);return !t.length||t.some(s=>norm(d.name).includes(s));}
function gearPriority(d){return /sword|blade|axe|mace|weapon|shield|one.hand|two.hand|main.hand/i.test(String(d.slot)+' '+String(d.name))?2:/mail|plate|chest|legs|head|hands|feet|shoulder/i.test(String(d.slot))?1:0;}

export class OnlineGuide{
  constructor({fetcher=fetch,now=()=>Date.now(),ttl=15*60*1000}={}){
    this.fetcher=fetcher;this.now=now;this.ttl=ttl;this.cache=new Map();this.pending=new Map();this.requestTimes=[];
  }
  async get(path,params={}){
    if(!/^\/(?:dungeons(?:\/[a-z0-9-]+)?|quests(?:\/[0-9]+)?|items(?:\/[0-9]+)?|rares)$/.test(path))throw new AppError('online_bad_path');
    const url=new URL(ROOT+path);
    for(const [k,v] of Object.entries(params))if(v!==undefined&&v!==null&&v!=='')url.searchParams.set(k,String(v));
    const key=url.href,cached=this.cache.get(key);
    if(cached&&this.now()-cached.at<this.ttl)return cached.payload;
    if(this.pending.has(key))return this.pending.get(key);
    const work=(async()=>{
      const now=this.now();this.requestTimes=this.requestTimes.filter(t=>now-t<60000);
      // Conservative limit below the provider's documented 120 calls/min/IP.
      if(this.requestTimes.length>=45)throw new AppError('online_rate_limit_local','Zu viele Online-Abfragen / Too many online requests.');
      this.requestTimes.push(now);
      const c=new AbortController(),timer=setTimeout(()=>c.abort(),12000);
      try{
        let response;
        try{response=await this.fetcher(key,{method:'GET',headers:{Accept:'application/json'},redirect:'error',credentials:'omit',signal:c.signal});}
        catch{throw new AppError('online_unreachable','Online-Datenquelle nicht erreichbar / Online data source unreachable.');}
        if(!response.ok){
          if(response.status===429)throw new AppError('online_upstream_rate_limit','Online-Datenquelle begrenzt Anfragen / Online source rate-limited.');
          throw new AppError('online_http_'+response.status,'Online-Datenquelle: HTTP '+response.status);
        }
        const payload=await limitedJSON(response,3*1024*1024);
        if(!payload||typeof payload!=='object'||!('data' in payload)||!payload.meta||typeof payload.meta!=='object')throw new AppError('online_invalid_response');
        this.cache.set(key,{payload,at:this.now()});if(this.cache.size>100)this.cache.delete(this.cache.keys().next().value);
        return payload;
      }finally{clearTimeout(timer);}
    })();
    this.pending.set(key,work);
    try{return await work;}finally{this.pending.delete(key);}
  }
  async search(input){
    if(!input||typeof input!=='object'||typeof input.query!=='string')throw new AppError('online_invalid_query');
    const query=input.query.trim(),chosen=input.kind??'auto';
    if(query.length<2||query.length>180||/[\x00-\x1f\x7f]/.test(query)||!KINDS.has(chosen))throw new AppError('online_invalid_query');
    const level=input.level===undefined||input.level===''?levelFrom(query):Number(input.level);
    if(level!==undefined&&(!Number.isInteger(level)||level<1||level>60))throw new AppError('online_invalid_level');
    const kind=chosen==='auto'?category(query):chosen;
    let found;
    if(kind==='dungeon')found=await this.dungeons(query,level);
    else if(kind==='item')found=await this.items(query,level);
    else if(kind==='quest')found=await this.quests(query,level);
    else if(kind==='rare')found=await this.rares(query);
    else{
      found=await this.dungeons(query,level);
      if(!found.rows.length)found=await this.quests(query,level);
      if(!found.rows.length)found=await this.items(query,level);
    }
    const results=distinct(found.rows),updatedAt=stamp(found.meta),fetchedAt=new Date(this.now()).toISOString();
    return {source:SOURCE,query,kind,level:level??null,updatedAt,fetchedAt,results,
      note:safe(found.note,350),packet:results.length?searchPacket({query,updatedAt,results}):''};
  }
  async dungeons(query,level){
    const response=await this.get('/dungeons');
    const list=arr(response.data).filter(d=>d&&typeof d.name==='string'&&slug(d.id)&&d.status!=='announced'&&matchesDungeon(d,query));
    const hits=level!==undefined&&!aliasFor(query)?list.filter(d=>(int(d.minLevel,0,60)??0)<=level&&(int(d.maxLevel,0,60)??60)>=level):list;
    const results=hits.slice(0,8).map(d=>row('dungeon',d.id,d.name,['Dungeon',d.minLevel!=null&&d.maxLevel!=null?`Lvl ${d.minLevel}-${d.maxLevel}`:'',safe(d.zone,55),safe(d.entrance,75)].filter(Boolean).join(' · '),d.id));
    if(hits.length===1&&GEAR.test(query)){
      const d=hits[0],details=await this.get('/dungeons/'+d.id);
      const loot=arr(details.data?.loot).filter(item=>item&&typeof item.name==='string');
      loot.sort((a,b)=>gearPriority(b)-gearPriority(a));
      for(const item of loot.slice(0,22)){
        const itemID=int(item.itemId,1),detail=['Beute',safe(item.slot,50),safe(item.quality,22),item.source?'Boss: '+safe(item.source,65):''].filter(Boolean).join(' · ');
        results.push(row('item',itemID??'loot',item.name,detail,d.id));
      }
      return {rows:results,meta:details,note:'Boss-/Dropdaten sind Community-Angaben, keine garantierte Aufwertung. / Community loot is not a guaranteed upgrade.'};
    }
    return {rows:results,meta:response,note:'Nur bekannte Addon-Annäherungspunkte sind navigierbar, keine berechneten Fußwege. / Only previously mapped approach points can guide you.'};
  }
  async items(question,level){
    const q=searchTerm(question,'item');
    if(!q)return {rows:[],note:'Bitte Itemname oder Waffentyp angeben, z. B. „Schwert“. / Specify item name or type.'};
    // The public API's "q" filters item NAMES, not weapon types. A type
    // query such as "Schwert" must include e.g. "Haunting Blade" when its
    // weaponType says Sword. Scan a bounded number of level-filtered pages.
    const typeQuery=['sword','shield','axe','staff'].includes(q);
    const params={limit:typeQuery?500:100};if(level!==undefined)params.maxLevel=level;
    if(!typeQuery)params.q=q;
    const data=await this.get('/items',params);
    const collected=arr(data.data).slice();
    if(typeQuery){
      let page=data.page;
      for(let index=1;index<3&&page?.next&&Number(page.total)>collected.length;index++){
        const offset=index*500;
        const follow=await this.get('/items',{...params,offset});
        collected.push(...arr(follow.data));page=follow.page;
      }
    }
    let items=collected.filter(i=>i&&int(i.id,1)!==null&&typeof i.name==='string');
    if(level!==undefined)items=items.filter(i=>i.requiredLevel==null||i.requiredLevel<=level);
    const pattern={sword:/sword|blade|sabre/i,shield:/shield/i,axe:/axe/i,staff:/staff/i}[q];
    if(pattern)items=items.filter(i=>pattern.test(String(i.weaponType||'')+' '+String(i.slot||'')+' '+i.name));
    items.sort((a,b)=>((Number(b.verified)>0?1:0)-(Number(a.verified)>0?1:0))||((Number(b.itemLevel)||0)-(Number(a.itemLevel)||0)));
    const results=[];
    for(const item of items.slice(0,8)){
      let details=null;
      try{details=await this.get('/items/'+item.id);}catch(e){if(e.code!=='online_http_404')throw e;}
      const drop=arr(details?.data?.dropsFrom).find(d=>slug(d?.dungeon?.id));
      const reward=arr(details?.data?.rewardFrom)[0];
      const desc=[safe(item.weaponType||item.slot,45),item.requiredLevel!=null?'Ab Lvl '+item.requiredLevel:'',item.itemLevel!=null?'iLvl '+item.itemLevel:'',drop?'Fundort: '+safe(drop.dungeon.name,55)+(drop.source?' / '+safe(drop.source,45):''):reward?'Quest: '+safe(reward.name,55):'',item.classicOnly?'Classic-Werte ungeprüft':''].filter(Boolean).join(' · ');
      results.push(row('item',item.id,item.name,desc,drop?.dungeon?.id||''));
    }
    return {rows:results,meta:data,note:'Auswahl, keine vollständige BiS-Liste und kein DPS-Vergleich deiner Ausrüstung. / Candidate items, not a full BiS or verified upgrade ranking.'};
  }
  async quests(question,level){
    const q=searchTerm(question,'quest'),params={limit:40};if(q)params.q=q;
    if(level!==undefined){params.minLevel=Math.max(1,level-5);params.maxLevel=Math.min(60,level+3);}
    const response=await this.get('/quests',params);
    const results=arr(response.data).filter(q=>q&&int(q.questId,1)!==null&&typeof q.name==='string').slice(0,18).map(q=>row('quest',q.questId,q.name,[q.level?'Lvl '+q.level:'',safe(q.location||q.zone,60),safe(q.giver,50),q.confidence==='classic'?'Classic ungeprüft':''].filter(Boolean).join(' · ')));
    return {rows:results,meta:response,note:'Questnavigation nur bei gültigem Questziel aus deinem aktuellen WoW-Questlog. / Quest guidance only when the live quest log exposes a waypoint.'};
  }
  async rares(question){
    const q=searchTerm(question,'rare'),response=await this.get('/rares',q?{q}:{});
    const results=arr(response.data).filter(r=>r&&typeof r.name==='string').slice(0,18).map(r=>row('rare',slug(r.id)||'rare',r.name,[safe(r.zone,65),safe(r.levels,20),arr(r.coords).slice(0,2).join(' / ')].filter(Boolean).join(' · ')));
    return {rows:results,meta:response,note:'Rar-Koordinaten ohne bestätigte uiMapID sind nur Hinweise, keine Marker. / Rare coordinates without a confirmed map ID are informational only.'};
  }
}
