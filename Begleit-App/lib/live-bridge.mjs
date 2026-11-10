// Opt-in Windows live bridge for WoW Forever. External program reads ONLY
// a fixed client-window pixel strip. Never reads or writes game memory,
// presses keys, clicks the client, or calls protected WoW actions.
import {promises as fs} from 'node:fs';
import path from 'node:path';
import {spawn,execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
import {AppError,PROVIDERS} from './common.mjs';
import {atomicWrite} from './storage.mjs';
import {findInstalledAddon} from './game-sync.mjs';
import {parseLiveRequest,slotSource,slotName,signalName,silentWav,SLOTS} from './live-protocol.mjs';
import {catalogPacket} from './bridge.mjs';
const folder=path.dirname(fileURLToPath(import.meta.url));
const psScript=path.join(folder,'capture-foreverai.ps1');
const emptyReply='-- Prepared ForeverAI data slot; filled by local companion after player sends a question.\n';
const toc=(n)=>`## Interface: 16001\n## Title: ForeverAI reply ${n}\n## Notes: Data-only reply slot for the ForeverAI companion\n## LoadOnDemand: 1\n## DefaultState: enabled\nInbox.lua\n`;
const wait=t=>new Promise(r=>setTimeout(r,t));
export async function installLiveSlots(addonPath){
 const root=path.dirname(addonPath),signal=path.join(addonPath,'LiveSignals');
 await fs.mkdir(signal,{recursive:true});
 for(let n=1;n<=SLOTS;n++){
  const addon=path.join(root,slotName(n));await fs.mkdir(addon,{recursive:true});
  const tp=path.join(addon,slotName(n)+'.toc');
  await atomicWrite(tp,toc(n));
  const inbox=path.join(addon,'Inbox.lua');
  if(!await fs.stat(inbox).catch(()=>null))await atomicWrite(inbox,emptyReply);
  const flag=path.join(signal,signalName(n));
  if(!await fs.stat(flag).catch(()=>null))await fs.writeFile(flag,Buffer.alloc(0),{flag:'wx'});
 }
 return {slots:SLOTS,addonPath};
}
export async function writeLiveResult(addonPath,reply){
 const content=slotSource(reply),root=path.dirname(addonPath);
 // Write all slots: WoW can load each previously-known slot exactly once per UI session.
 for(let n=1;n<=SLOTS;n++){
  const filename=path.join(root,slotName(n),'Inbox.lua');
  if(!await fs.stat(filename).catch(()=>null))throw new AppError('live_slots_missing');
  await atomicWrite(filename,content);
 }
 const signal=path.join(addonPath,'LiveSignals',signalName(reply.id));
 if(!await fs.stat(signal).catch(()=>null))throw new AppError('live_signal_missing');
 await atomicWrite(signal,silentWav());
}
export class LiveBridge{
 constructor({directory,providers,settings,discover=findInstalledAddon,clock=()=>Date.now(),write=writeLiveResult,captureFactory=null}={}){
  this.directory=directory;this.providers=providers;this.settings=settings;this.discover=discover;this.clock=clock;this.write=write;this.captureFactory=captureFactory;
  this.file=path.join(directory,'live-bridge.json');this.config={gamePath:'',enabled:false};this.process=null;this.buffer='';this.requests=new Map();this.histories=new Map();this.times=[];this.working=false;this.lastError=null;this.count=0;this.lastReply=null;this.captureStarted=false;this.addonPath='';this.stopping=false;
 }
 async load(){
  let fresh=false;
  try{const x=JSON.parse(await fs.readFile(this.file,'utf8'));
   if(typeof x.gamePath==='string'&&x.gamePath.length<=1024)this.config.gamePath=x.gamePath;
   this.config.enabled=x.enabled===true;
  }catch(e){if(e.code!=='ENOENT')throw new AppError('live_settings_invalid');fresh=true;}
  const addon=await this.discover(this.config.gamePath);if(addon)this.addonPath=addon;
  if(fresh && process.env.FOREVERAI_GAME_DIR && this.addonPath && process.platform==='win32'){
   const root=path.dirname(this.addonPath);
   const ready=await fs.stat(path.join(root,slotName(SLOTS),slotName(SLOTS)+'.toc')).then(()=>true,()=>false);
   let running=true;
   try{const out=execFileSync('tasklist.exe',['/FI','IMAGENAME eq Wow.exe','/NH'],{encoding:'utf8',windowsHide:true});running=/\bWow\.exe\b/i.test(out);}catch{}
   if(ready || !running){
    if(!ready)await installLiveSlots(this.addonPath);
    this.config={gamePath:process.env.FOREVERAI_GAME_DIR,enabled:true};
    await atomicWrite(this.file,JSON.stringify(this.config));
   }else this.lastError='live_setup_close_wow';
  }
  // Explicitly do NOT auto-enable before user has configured it.
  if(this.config.enabled && this.addonPath){await this.start().catch(e=>this.lastError=e?.code||'live_launch_failed');}
 }
 status(){return {enabled:this.config.enabled,configured:!!this.addonPath,addonPath:this.addonPath,captureRunning:this.captureStarted,
  working:this.working,lastError:this.lastError,count:this.count,lastReply:this.lastReply,slots:SLOTS,processName:'Wow,WowB'};}
 async configure({gamePath,enabled}={}){
  if(typeof gamePath!=='string'||gamePath.length>1024||!gamePath||typeof enabled!=='boolean')throw new AppError('live_bad_settings');
  const addon=await this.discover(gamePath);
  if(!addon)throw new AppError('live_game_not_found','WoW _forever_ / Interface / AddOns / ForeverAI mit Interface 16001 wählen.');
  await this.stop();this.config={gamePath,enabled};this.addonPath=addon;
  await installLiveSlots(addon);
  await atomicWrite(this.file,JSON.stringify(this.config));
  this.lastError=null;if(enabled)await this.start().catch(e=>{this.lastError=e?.code||'live_capture_failed';});
  return {...this.status(),restartRequired:true};
 }
 async start(){
  if(!this.config.enabled||this.process)return;
  if(!this.addonPath)throw new AppError('live_game_not_found');
  if(this.captureFactory){this.process=await this.captureFactory(line=>this.acceptLine(line));this.captureStarted=true;return;}
  if(process.platform!=='win32'){this.lastError='live_windows_only';return;}
  const exe=path.join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
  const child=spawn(exe,['-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',psScript,
   '-ProcessName','Wow,WowB','-ClientFolder',path.dirname(path.dirname(path.dirname(this.addonPath)))],
   {windowsHide:true,stdio:['ignore','pipe','pipe']});
  this.process=child;this.captureStarted=true;
  child.stdout.setEncoding('utf8');child.stdout.on('data',part=>{
   this.buffer+=part;if(this.buffer.length>40000)this.buffer='';
   for(let idx;(idx=this.buffer.indexOf('\n'))>=0;){const line=this.buffer.slice(0,idx).trim();this.buffer=this.buffer.slice(idx+1);if(line)this.acceptLine(line);}
  });
  child.stderr.setEncoding('utf8');child.stderr.on('data',()=>{ /* never persist raw Windows/process details or secrets */ });
  child.on('error',()=>{if(!child.intentionalStop)this.lastError='live_capture_start_failed';if(this.process===child){this.captureStarted=false;this.process=null;}});
  child.on('exit',()=>{if(!child.intentionalStop)this.lastError='live_capture_stopped';if(this.process===child){this.captureStarted=false;this.process=null;}});
 }
 async stop(){
  this.stopping=true;
  if(this.process){try{this.process.intentionalStop=true;this.process.kill();}catch{}this.process=null;}
  this.captureStarted=false;this.buffer='';this.stopping=false;
 }
 async close(){await this.stop();}
 acceptLine(line){
  if(line.length>16000)return;
  let data;try{data=JSON.parse(line);}catch{return;}
  if(!data||typeof data.text!=='string'||!Number.isInteger(data.id))return;
  let req;try{req=parseLiveRequest(data.text);}catch{return;}
  if(req.id!==data.id)return;
  void this.handleRequest(req).catch(e=>{this.lastError=e?.code||'live_request_failed';});
 }
 async handleRequest(req){
  if(!this.config.enabled||!this.addonPath)return;
  const key=req.session+':'+req.id;if(this.requests.has(key))return;
  const stamp=this.clock();this.times=this.times.filter(x=>x>stamp-60000);
  if(this.times.length>=4){this.requests.set(key,'rate_limited');return this.publish(req,{status:'error',text:'Rate limit: maximum 4 in-game requests per minute.'});}
  this.times.push(stamp);this.requests.set(key,'working');
  if(this.requests.size>200){for(const [k,v] of this.requests){if(v!=='working'){this.requests.delete(k);if(this.requests.size<120)break;}}}
  if(this.working){this.requests.set(key,'busy');return this.publish(req,{status:'error',text:'Another AI request is running. Please retry.'});}
  this.working=true;
  try{
   // The companion's current provider is authoritative. A previously saved
   // in-game catalog must never silently switch back to a remote provider.
   const setting=this.settings.value,provider=setting.provider;
   const staleProvider=req.requestedProvider!=='auto'&&req.requestedProvider!==provider;
   if(!PROVIDERS.includes(provider))throw new AppError('unknown_provider');
   // The game may request a model, but only the provider's advertised catalog
   // and the existing free-only guard authorize it. No silent paid fallback.
   if(req.question==='__foreverai_catalog__'){
    let list=await this.providers.models(provider,setting,{fresh:true});
    if(setting.freeOnly&&provider==='openrouter')list=list.filter(m=>m.free&&m.id.endsWith(':free'));
    const packet=catalogPacket(provider,list.slice(0,50));
    await this.publish(req,{status:'done',text:`${packet.count} models available`,catalog:packet.packet,provider,model:'catalog'});
    return;
   }
   let wanted=staleProvider||req.model==='auto'||req.model===''?setting.model:req.model;
   if(!wanted){
    let models=await this.providers.models(provider,setting,{fresh:true});
    if(setting.freeOnly&&provider==='openrouter')models=models.filter(m=>m.free&&m.id.endsWith(':free'));
    const preferred=provider==='openrouter'&&setting.freeOnly
     ?models.find(m=>m.id==='nvidia/nemotron-3.5-super-vl:free'):null;
    wanted=(preferred||models[0])?.id;
    if(!wanted)throw new AppError('no_available_model','No permitted model is available.');
   }
   if(setting.freeOnly&&provider==='openrouter'&&!wanted.endsWith(':free'))throw new AppError('free_model_required','Select an OpenRouter :free model.');
   const effort=staleProvider||req.effort==='default'?setting.effort||'default':req.effort;
   const historyKey=req.session+':'+provider;
   const history=this.histories.get(historyKey)||[];
   const result=await this.providers.chat(provider,{question:req.question,context:req.context,
    language:req.language,model:wanted,effort,history},setting,{});
   this.histories.clear();
   this.histories.set(historyKey,[...history,{role:'user',content:req.question},{role:'assistant',content:result.text.slice(0,3000)}].slice(-12));
   await this.publish(req,{status:'done',text:result.text,provider,model:result.model});
  }catch(e){this.lastError=e?.code||'provider_failed';await this.publish(req,{status:'error',text:e instanceof AppError?e.code:'provider_failed',provider:req.requestedProvider,model:req.model});}
  finally{this.working=false;this.requests.set(key,'done');}
 }
 async publish(req,data){
  const reply={session:req.session,id:req.id,status:data.status,provider:data.provider||'ForeverAI',model:data.model||'',text:data.text||'',catalog:data.catalog};
  try{await this.write(this.addonPath,reply);this.count++;this.lastReply=new Date(this.clock()).toISOString();}
  catch(e){this.lastError=e?.code||'live_write_failed';throw e;}
 }
}
