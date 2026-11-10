import test from 'node:test';
import assert from 'node:assert/strict';
import {mkdtemp,mkdir,readFile,writeFile,rm,stat} from 'node:fs/promises';
import os from 'node:os';import path from 'node:path';
import {parseLiveRequest,encodeCells,decodeCells,slotSource,slotName,signalName,silentWav,SLOTS} from '../lib/live-protocol.mjs';

test('live bridge selects a free model and keeps conversation only within a session',async()=>{
 const calls=[], replies=[];
 const providers={models:async()=>[{id:'paid',free:false},{id:'safe:free',free:true}],chat:async(_p,input)=>{calls.push(input);return {text:'answer',model:input.model};}};
 const bridge=new LiveBridge({directory:'unused',providers,settings:{value:{provider:'openrouter',model:'',freeOnly:true}},write:async(_p,result)=>replies.push(result)});
 bridge.addonPath='fixture';bridge.config.enabled=true;
 const req={session:'abcdef123456',id:1,requestedProvider:'auto',model:'auto',effort:'default',language:'de',question:'Hallo',context:''};
 await bridge.handleRequest(req);
 await bridge.handleRequest({...req,id:2,question:'Und weiter?'});
 await bridge.handleRequest({...req,id:3,session:'abcdef123457'});
 assert.equal(calls[0].model,'safe:free');assert.equal(calls[0].history.length,0);
 assert.equal(calls[1].history.length,2);assert.equal(calls[2].history.length,0);
 assert.equal(replies.length,3);
});
test('stale remote provider and model cannot override the selected local provider',async()=>{
 const calls=[],published=[];
 const providers={models:async provider=>{assert.equal(provider,'ollama');return [{id:'gemma3:12b',local:true,free:true}];},
  chat:async(provider,input)=>{calls.push({provider,...input});return {text:'ok',model:input.model};}};
 const bridge=new LiveBridge({directory:'unused',providers,settings:{value:{provider:'ollama',model:'',effort:'default',freeOnly:true}},write:async(_p,result)=>published.push(result)});
 bridge.addonPath='fixture';bridge.config.enabled=true;
 await bridge.handleRequest({session:'abcdef123456',id:1,requestedProvider:'chatgpt',model:'gpt-6.1-terra',effort:'low',language:'de',question:'Hallo',context:''});
 assert.equal(calls.length,1);assert.equal(calls[0].provider,'ollama');assert.equal(calls[0].model,'gemma3:12b');assert.equal(calls[0].effort,'default');assert.equal(published[0].status,'done');
});
test('OpenRouter live mode accepts only verified free variants and ignores an old ChatGPT selection',async()=>{
 const calls=[],published=[];
 const providers={models:async()=>[{id:'some-paid',free:false},{id:'zero-funded',free:true},{id:'example/model:free',name:'Free',free:true,efforts:['default']}],
  chat:async(provider,input)=>{calls.push({provider,...input});return {text:'ok',model:input.model};}};
 const bridge=new LiveBridge({directory:'unused',providers,settings:{value:{provider:'openrouter',model:'',effort:'default',freeOnly:true}},write:async(_p,result)=>published.push(result)});
 bridge.addonPath='fixture';bridge.config.enabled=true;
 const base={session:'abcdef123456',requestedProvider:'chatgpt',model:'gpt-6.1-terra',effort:'low',language:'de',context:''};
 await bridge.handleRequest({...base,id:1,question:'Hallo'});
 assert.equal(calls[0].provider,'openrouter');assert.equal(calls[0].model,'example/model:free');assert.equal(calls[0].effort,'default');
 await bridge.handleRequest({...base,id:2,question:'__foreverai_catalog__'});
 assert(published[1].catalog.includes('example/model:free'));assert(!published[1].catalog.includes('zero-funded'));
 await bridge.handleRequest({...base,id:3,requestedProvider:'openrouter',model:'some-paid',question:'Test'});
 assert.equal(published[2].status,'error');assert.equal(published[2].text,'free_model_required');assert.equal(calls.length,1);
});
test('OpenRouter prefers the tested free model when available',async()=>{
 let selected;const providers={models:async()=>[{id:'other:free',free:true},{id:'nvidia/nemotron-3.5-super-vl:free',free:true}],chat:async(_p,input)=>{selected=input.model;return {text:'ok',model:input.model};}};
 const bridge=new LiveBridge({directory:'unused',providers,settings:{value:{provider:'openrouter',model:'',freeOnly:true}},write:async()=>{}});
 bridge.addonPath='fixture';bridge.config.enabled=true;
 await bridge.handleRequest({session:'abcdef123456',id:1,requestedProvider:'chatgpt',model:'old',effort:'default',language:'de',question:'Hallo',context:''});
 assert.equal(selected,'nvidia/nemotron-3.5-super-vl:free');
});
import {installLiveSlots,writeLiveResult,LiveBridge} from '../lib/live-bridge.mjs';
const sample=(question='Welche Schwerter gibt es für meinen Krieger, Level 25?')=>'FAI1;65b2c04200abcdef;12;auto;auto;default;de;'+encodeURIComponent(question)+';'+encodeURIComponent('class=Krieger;level=25');
const req=parseLiveRequest(sample());
test('visible pixel packet: DE/EN UTF-8 with checksum, lengths and request id',()=>{
 assert.deepEqual(parseLiveRequest(sample()),{session:'65b2c04200abcdef',id:12,requestedProvider:'auto',model:'auto',effort:'default',language:'de',question:'Welche Schwerter gibt es für meinen Krieger, Level 25?',context:'class=Krieger;level=25'});
 const cells=encodeCells(sample());assert(cells.length>100);assert(cells.length<200*48);
 assert.deepEqual(decodeCells(cells),req);
 const en=sample('Where is the entrance to Shadowfang Keep?');assert.equal(decodeCells(encodeCells(en)).question,'Where is the entrance to Shadowfang Keep?');
 assert.throws(()=>decodeCells(cells.map((v,i)=>i===70?v^1:v)),/live_checksum|live_magic/);
 assert.throws(()=>parseLiveRequest(sample().replace('FAI1;','FAI2;')),/live_invalid_packet/);
 assert.throws(()=>parseLiveRequest(sample('hi').replace('12;auto','12;https://evil.example')),/live_invalid_packet/);
 assert.throws(()=>parseLiveRequest(sample('hi').replace('hi;class','%GG;class')),/live_bad_encoding/);
});
test('data-only Lua slot escapes code, control bytes, and Unicode',()=>{
 const file=slotSource({session:req.session,id:req.id,status:'done',provider:'openrouter',model:'safe/free',text:'Klinge \"\n'});
 assert(file.startsWith('-- ForeverAI'));assert(file.includes('\\034'));assert(file.includes('\\010'));assert(!file.includes('"\n"'));
 const hostile='"}; C_AddOns.LoadAddOn("evil"); --';
 const out=slotSource({session:req.session,id:req.id,status:'done',provider:'free',model:'model',text:hostile,catalog:'FGC1;openrouter\nEND'});
 assert(!out.includes('text=""}; C_AddOns'));
 assert(out.includes('catalog="'));
 assert.throws(()=>slotSource({session:'invalid',id:12,status:'done',provider:'x',model:'y',text:'hi'}),/live_reply_invalid/);
});
test('silent readiness signal is valid PCM and filenames are bounded',()=>{
 const wav=silentWav();assert.equal(wav.toString('ascii',0,4),'RIFF');assert.equal(wav.toString('ascii',8,12),'WAVE');assert.equal(wav.length,204);
 assert.equal(signalName(1),'r001.wav');assert.equal(signalName(120),'r120.wav');assert.equal(signalName(121),'r001.wav');
 assert.equal(slotName(1),'ForeverAI_R001');assert.equal(slotName(SLOTS),'ForeverAI_R120');assert.throws(()=>slotName(121));
});
test('preinstalled slots are load-on-demand; result replicates without code execution',async t=>{
 const tmp=await mkdtemp(path.join(os.tmpdir(),'fai-slots-'));t.after(()=>rm(tmp,{recursive:true,force:true}));
 const root=path.join(tmp,'_forever_','Interface','AddOns'),addon=path.join(root,'ForeverAI');
 await mkdir(addon,{recursive:true});await writeFile(path.join(addon,'ForeverAI.toc'),'## Interface: 16001\n');
 const install=await installLiveSlots(addon);assert.equal(install.slots,SLOTS);
 const toc=await readFile(path.join(root,slotName(1),slotName(1)+'.toc'),'utf8');assert(toc.includes('## LoadOnDemand: 1'));
 assert.equal((await stat(path.join(addon,'LiveSignals','r012.wav'))).size,0);
 await writeLiveResult(addon,{...req,status:'done',provider:'openrouter',model:'fixture/free',text:'Antwort auf Burg Schattenfang'});
 const a=await readFile(path.join(root,'ForeverAI_R001','Inbox.lua'),'utf8');const b=await readFile(path.join(root,'ForeverAI_R120','Inbox.lua'),'utf8');assert.equal(a,b);assert(a.includes('ForeverAI_LiveSlot='));assert(!a.includes('loadstring('));
 assert((await stat(path.join(addon,'LiveSignals','r012.wav'))).size>44);
});
test('live bridge: deduplicated in-game event -> selected provider -> data-only response',async t=>{
 const directory=await mkdtemp(path.join(os.tmpdir(),'fai-live-'));t.after(()=>rm(directory,{recursive:true,force:true}));
 const gamePath=path.join(directory,'_forever_'),addon=path.join(gamePath,'Interface','AddOns','ForeverAI');await mkdir(addon,{recursive:true});await writeFile(path.join(addon,'ForeverAI.toc'),'## Interface: 16001\n');
 let captureHandler,callCount=0;const published=[];
 const providers={chat:async(id,input,settings)=>{callCount++;assert.equal(id,'openrouter');assert.equal(input.model,'fixture/free:free');assert.equal(settings.freeOnly,true);return {text:'Die Testklinge ist für deinen Krieger eine mögliche Wahl.',model:input.model};},models:async()=>[{id:'fixture/free:free',name:'Fixture Free',efforts:['default','low'],free:true},{id:'fixture/paid',name:'Paid',efforts:['default'],free:false}]};
 const app=new LiveBridge({directory,providers,settings:{value:{provider:'openrouter',model:'fixture/free:free',effort:'default',freeOnly:true}},
  discover:async()=>addon,captureFactory:async(fn)=>{captureHandler=fn;return {kill(){}};},write:async(_path,r)=>{published.push(r);}});
 t.after(()=>app.close());await app.configure({gamePath,enabled:true});assert.equal(app.status().captureRunning,true);
 const packet=sample();captureHandler(JSON.stringify({id:12,text:packet}));captureHandler(JSON.stringify({id:12,text:packet}));
 for(let tries=0;tries<50&&published.length===0;tries++)await new Promise(r=>setTimeout(r,5));
 assert.equal(published.length,1);assert.equal(callCount,1);assert.equal(published[0].text,'Die Testklinge ist für deinen Krieger eine mögliche Wahl.');
 captureHandler(JSON.stringify({id:12,text:packet}));await new Promise(r=>setTimeout(r,10));assert.equal(callCount,1);
 const catalog=sample('__foreverai_catalog__').replace(';12;', ';13;');captureHandler(JSON.stringify({id:13,text:catalog}));
 for(let tries=0;tries<50&&published.length<2;tries++)await new Promise(r=>setTimeout(r,5));
 assert.equal(published.length,2);assert(published[1].catalog.includes('fixture/free:free'));assert(!published[1].catalog.includes('fixture/paid'));
 assert.equal(callCount,1);
});
test('live bridge rate-limit avoids unintended repeated paid requests',async t=>{
 const directory=await mkdtemp(path.join(os.tmpdir(),'fai-rate-'));t.after(()=>rm(directory,{recursive:true,force:true}));
 const addon=path.join(directory,'_forever_','Interface','AddOns','ForeverAI');await mkdir(addon,{recursive:true});await writeFile(path.join(addon,'ForeverAI.toc'),'## Interface: 16001\n');
 let count=0;const seen=[];
 const bridge=new LiveBridge({directory,discover:async()=>addon,providers:{chat:async()=>{count++;return {text:'ok',model:'fixture/free:free'};}},settings:{value:{provider:'openrouter',model:'fixture/free:free',effort:'default',freeOnly:true}},captureFactory:async()=>({kill(){}}),write:async(_p,x)=>seen.push(x)});
 t.after(()=>bridge.close());await bridge.configure({gamePath:directory,enabled:true});
 for(let id=1;id<=5;id++)await bridge.handleRequest({...req,id});
 assert.equal(count,4);assert.equal(seen.length,5);assert.equal(seen[4].status,'error');assert(seen[4].text.includes('maximum 4'));
});
