import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,writeFile,readFile,rm} from 'node:fs/promises';
import os from 'node:os';import path from 'node:path';
import {downloadSnapshot,luaSnapshot,findInstalledAddon,GameDataSync,SYNC_MIN_INTERVAL_MS} from '../lib/game-sync.mjs';
const date='2026-11-09T06:03:32Z';
function source({fail=false}={}){
  const calls=[];
  return {calls,async get(route,params={}){
    calls.push([route,params]);if(fail&&route==='/items')throw new Error('offline');
    const meta={updatedAt:date};
    if(route==='/dungeons')return {data:[{id:'shadowfang-keep',name:'Shadowfang Keep',status:'launch',zone:'Silverpine Forest',minLevel:18,maxLevel:30},
      {id:'unreleased',name:'Unknown',status:'announced',minLevel:50,maxLevel:60}],meta};
    if(route==='/dungeons/shadowfang-keep')return {data:{id:'shadowfang-keep',loot:[{itemId:987,name:'Wicked Blade',slot:'One-Hand',source:'Test Boss'},{itemId:124,name:'Rare Shield',slot:'Shield',source:'Boss'}]},meta};
    if(route==='/items')return {data:[{id:987,name:'Wicked Blade',weaponType:'Sword',slot:'One-Hand',requiredLevel:22,itemLevel:30,stats:['strength'],verified:4},
      {id:321,name:'\"}; _G.pwned=true; --',weaponType:'Axe',slot:'Two-Hand',requiredLevel:22,itemLevel:28}],page:{next:null},meta};
    if(route==='/quests')return {data:[{questId:555,name:'A Quest',level:23,giver:'Test NPC',dungeon:{id:'shadowfang-keep'}}],page:{next:null},meta};
    if(route==='/rares')return {data:[{id:'rare-1',name:'Scary Rare',coords:['54.2, 11.6'],zone:'Westfall',verified:2}],meta};
    throw Error('unexpected route '+route);
  }};
}
async function world(){const base=await mkdtemp(path.join(os.tmpdir(),'foreverai-sync-'));
 const addon=path.join(base,'_forever_','Interface','AddOns','ForeverAI');await mkdir(addon,{recursive:true});
 await writeFile(path.join(addon,'ForeverAI.toc'),'## Interface: 16001\n## Title: ForeverAI\n');
 return {base,addon,game:path.join(base,'_forever_'),close:()=>rm(base,{recursive:true,force:true})};}
test('download public complete dataset and join loot sources by item ID',async()=>{
 const online=source(),data=await downloadSnapshot(online,{clock:()=>date});
 assert.equal(data.dungeons.length,1);assert.equal(data.items.length,3);assert.equal(data.quests.length,1);assert.equal(data.rares.length,1);
 assert.deepEqual(data.items.find(x=>x.id===987).drops,[{dungeonId:'shadowfang-keep',boss:'Test Boss'}]);
 assert.equal(data.dungeons[0].pinKey,'shadowfang');assert.equal(data.source,'https://forevercompanion.io/developers');
 assert(online.calls.every(([route])=>route.startsWith('/')));
});
test('Lua snapshot cannot evaluate untrusted text as executable Lua',async()=>{
 const data=await downloadSnapshot(source());const script=luaSnapshot(data);
 assert(script.includes('FG.SyncData = {'));assert(script.includes('source='));
 assert(!script.includes('"}; _G.pwned=true; --'));assert(script.includes('\\034')); // quote encoded as data
 assert(!script.includes('os.execute('));
 assert(script.length<6*1024*1024);
});
test('only exact installed Forever addon folder accepted',async t=>{
 const w=await world();t.after(w.close);
 assert.equal(await findInstalledAddon(w.game),w.addon);
 assert.equal(await findInstalledAddon(w.addon),w.addon);
 assert.equal(await findInstalledAddon(path.join(w.base,'_retail_')),null);
 assert.equal(await findInstalledAddon(path.join(w.base,'missing')),null);
});
test('sync is opt-in, atomic and retains last success across process restarts',async t=>{
 const w=await world();t.after(w.close);const online=source();let now=1_000_000;
 const sync=new GameDataSync({directory:w.base,online,now:()=>now});await sync.load();
 await sync.refresh();assert.equal(online.calls.length,0);
 await sync.configure({path:w.game,enabled:true});let state=await sync.refresh();
 assert.equal(state.counts.items,3);assert.equal(state.counts.dungeons,1);
 const first=await readFile(path.join(w.addon,'SyncData.lua'),'utf8');assert(first.includes('Wicked Blade'));
 assert.equal(online.calls.length,5);await sync.refresh();assert.equal(online.calls.length,5);
 now+=SYNC_MIN_INTERVAL_MS+1000;await sync.refresh();assert.equal(online.calls.length,10);
 const next=new GameDataSync({directory:w.base,online,now:()=>now});await next.load();
 assert.equal(next.status().enabled,true);assert.equal(next.status().counts.items,3);assert.equal(next.status().addonPath,w.addon);
});
test('download failure never overwrites previously valid SyncData.lua',async t=>{
 const w=await world();t.after(w.close);const sync=new GameDataSync({directory:w.base,online:source({fail:true})});
 await sync.load();await sync.configure({path:w.game,enabled:true});
 const filepath=path.join(w.addon,'SyncData.lua');await writeFile(filepath,'OLD VALID CACHE');
 await assert.rejects(sync.refresh({force:true}));
 assert.equal(await readFile(filepath,'utf8'),'OLD VALID CACHE');assert.equal(sync.status().lastError,'sync_failed');
});
test('sync does not execute if disabled after configuration',async t=>{
 const w=await world();t.after(w.close);const s=source();const sync=new GameDataSync({directory:w.base,online:s});await sync.load();
 await sync.configure({path:w.game,enabled:false});await sync.refresh({force:true});assert.equal(s.calls.length,0);
});
test('malformed configuration paths cannot write arbitrary files',async t=>{
 const w=await world();t.after(w.close);const sync=new GameDataSync({directory:w.base,online:source()});await sync.load();
 await assert.rejects(sync.configure({path:path.join(w.base,'elsewhere'),enabled:true}),e=>e.code==='sync_game_not_found');
 await assert.rejects(sync.configure({path:w.game,enabled:'yes'}),e=>e.code==='sync_bad_settings');
});

test('local browser API config triggers in-game cache write with no manual import',async t=>{
  const {createApp}=await import('../server.mjs');
  const w=await world();t.after(w.close);let outbound=0;
  const reply=data=>new Response(JSON.stringify({data,meta:{updatedAt:date},page:{next:null}}),{headers:{'Content-Type':'application/json'}});
  const app=await createApp({directory:w.base,persistent:false,fetcher:async(u,options)=>{
    outbound++;assert(u.startsWith('https://forevercompanion.io/api/v1/'));
    assert.equal(options.credentials,'omit');assert(!options.headers.Authorization);
    const pathname=new URL(u).pathname;
    if(pathname==='/api/v1/dungeons')return reply([{id:'shadowfang-keep',name:'Shadowfang Keep',status:'launch',zone:'Silverpine Forest',minLevel:18,maxLevel:30}]);
    if(pathname==='/api/v1/dungeons/shadowfang-keep')return reply({id:'shadowfang-keep',loot:[{itemId:12345,name:'Bright Sword',source:'Boss'}]});
    if(pathname==='/api/v1/items')return reply([{id:12345,name:'Bright Sword',weaponType:'Sword',slot:'One-Hand',requiredLevel:23}]);
    if(pathname==='/api/v1/quests')return reply([]);
    if(pathname==='/api/v1/rares')return reply([]);
    throw Error('unexpected network '+pathname);
  }});t.after(()=>app.close());
  const post=(url,data,cookie='',csrf='')=>fetch(app.origin+'/api/'+url,{method:'POST',headers:{Origin:app.origin,Cookie:cookie,'X-FG-CSRF':csrf,'Content-Type':'application/json'},body:JSON.stringify(data)});
  assert.equal(outbound,0);
  const auth=await post('session',{launch:app.launch});const cookie=auth.headers.get('set-cookie').split(';')[0];
  const state=await(await fetch(app.origin+'/api/state',{headers:{Cookie:cookie}})).json();const csrf=state.csrf;
  assert.equal(state.sync.enabled,false);assert.equal(outbound,0);
  let res=await post('sync/config',{path:w.game,enabled:true},cookie,csrf);assert.equal(res.status,200);
  if(app.sync.running)await app.sync.running;
  const content=await readFile(path.join(w.addon,'SyncData.lua'),'utf8');assert(content.includes('Bright Sword'));
  assert.equal(outbound,5);
  res=await post('sync/run',{},cookie,'bad-csrf');assert.equal(res.status,403);
  assert.equal(outbound,5);
  const status=await(await fetch(app.origin+'/api/sync/state',{headers:{Cookie:cookie}})).json();assert.equal(status.counts.items,1);
});

test('upgrading addon with a blank data placeholder restores cache immediately',async t=>{
 const w=await world();t.after(w.close);const s=source(),sync=new GameDataSync({directory:w.base,online:s,now:()=>1000000});
 await sync.load();await sync.configure({path:w.game,enabled:true});await sync.refresh();assert.equal(s.calls.length,5);
 await writeFile(path.join(w.addon,'SyncData.lua'),'-- Placeholder after addon update');
 await sync.refresh();assert.equal(s.calls.length,10);
 assert((await readFile(path.join(w.addon,'SyncData.lua'),'utf8')).startsWith('-- ForeverAI: generated static data;'));
});
