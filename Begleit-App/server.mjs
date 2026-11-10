import http from 'node:http';
import path from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {promises as fs} from 'node:fs';
import {spawn} from 'node:child_process';
import {AppError,VERSION,PROVIDERS,EFFORTS,token,equal,publicError,assertProvider,validateBaseURL,validString,modelID} from './lib/common.mjs';
import {Vault,Settings,dataDirectory,acquireLock} from './lib/storage.mjs';
import {Auth} from './lib/auth.mjs';
import {Providers,PROVIDER_INFO} from './lib/providers.mjs';
import {replyPacket,catalogPacket,extractRoute} from './lib/bridge.mjs';
import {OnlineGuide} from './lib/online.mjs';
import {GameDataSync} from './lib/game-sync.mjs';
import {LiveBridge} from './lib/live-bridge.mjs';
const root=path.dirname(fileURLToPath(import.meta.url));
export function validateSettings(input){
  const p={};if(!input||typeof input!=='object')throw new AppError('bad_settings');
  for(const [k,v] of Object.entries(input)){
    if(k==='language'&&['de','en'].includes(v))p[k]=v;
    else if(k==='provider'&&PROVIDERS.includes(v))p[k]=v;
    else if(k==='model'&&(v===''||modelID(v)))p[k]=v;
    else if(k==='effort'&&EFFORTS.includes(v))p[k]=v;
    else if(k==='maxTokens'&&Number.isInteger(v)&&v>=256&&v<=16384)p[k]=v;
    else if(k==='customBase')p[k]=v===''?'':validateBaseURL(v);
    else if(['freeOnly','planConfirmed'].includes(k)&&typeof v==='boolean')p[k]=v;
    else if(k==='freeTierConfirmed'&&v&&typeof v==='object')p[k]=Object.fromEntries(['gemini','groq','mistral'].map(id=>[id,v[id]===true]));
    else throw new AppError('bad_settings','Unzulässige Einstellung / Invalid setting: '+String(k).slice(0,40));
  }return p;
}
const safeHeaders={
  'Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Referrer-Policy':'no-referrer','X-Frame-Options':'DENY',
  'Content-Security-Policy':"default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'"
};
function send(res,status,data,extra={}){res.writeHead(status,{'Content-Type':'application/json; charset=utf-8',...safeHeaders,...extra});res.end(JSON.stringify(data));}
async function body(req){
  if(!(req.headers['content-type']||'').startsWith('application/json'))throw new AppError('json_required');
  let n=0,chunks=[];for await(const c of req){n+=c.length;if(n>180000)throw new AppError('body_too_large');chunks.push(c);}
  try{return JSON.parse(Buffer.concat(chunks).toString('utf8'));}catch{throw new AppError('invalid_json');}
}
export async function createApp({directory=dataDirectory(),fetcher=fetch,port=0,persistent,protector}={}){
  const settings=new Settings(directory),vault=new Vault(directory,{...(persistent!==undefined?{persistent}:{}),...(protector?{protector}:{})});
  await settings.load();validateSettings(Object.fromEntries(Object.entries(settings.value).filter(([k])=>k!=='hostID')));await vault.load();
  const auth=new Auth(vault,settings,{fetcher}),providers=new Providers(vault,auth,{fetcher}),online=new OnlineGuide({fetcher});
  const sync=new GameDataSync({directory,online});await sync.load();
  const live=new LiveBridge({directory,providers,settings});await live.load();
  const launch=token(),session=token(),csrf=token();let origin='',busy=false,activeController=null,redeemed=false;
  function authenticated(req){return (req.headers.cookie||'').split(/;\s*/).some(x=>x.startsWith('fg_session=')&&equal(x.slice(11),session));}
  function state(){const v=vault.get();const s={...settings.value};delete s.hostID;
    return {version:VERSION,settings:s,providers:PROVIDER_INFO,persistent:vault.persistent,csrf,activeAccount:v.activeAccount,
      accounts:Object.entries(v.accounts).map(([id,a])=>({id,name:a.name||a.email||'ChatGPT',email:a.email||'',connected:!!a.access_token,permission:(a.scopes||[]).includes('chatgpt.tokens.use.direct')})),
      keys:Object.fromEntries(PROVIDERS.map(p=>[p,!!v.keys[p]?.value])),busy,sync:sync.status(),live:live.status()};
  }
  const server=http.createServer(async(req,res)=>{
    try{
      if(req.headers.host!==new URL(origin).host){send(res,403,{code:'invalid_host'});return;}
      const u=new URL(req.url,origin),pathname=u.pathname;
      if(req.headers.origin&&req.headers.origin!==origin){send(res,403,{code:'invalid_origin'});return;}
      if(req.method==='OPTIONS'){send(res,403,{code:'cors_not_allowed'});return;}
      if(req.method==='GET'&&['/','/app.js','/style.css'].includes(pathname)){
        const name=pathname==='/'?'index.html':pathname.slice(1);const data=await fs.readFile(path.join(root,'public',name));
        res.writeHead(200,{...safeHeaders,'Content-Type':name.endsWith('.html')?'text/html; charset=utf-8':name.endsWith('.js')?'application/javascript; charset=utf-8':'text/css; charset=utf-8'});res.end(data);return;
      }
      if(req.method==='GET'&&['/auth/callback','/auth/openrouter/callback'].includes(pathname)){
        let message;
        try{const result=await auth.finish(pathname==='/auth/callback'?'chatgpt':'openrouter',u.searchParams);providers.clear();if(pathname==='/auth/callback')await settings.save({planConfirmed:false});message=result.permission===false?'Anmeldung bestätigt, aber ChatGPT-Kontingent NICHT freigegeben. / Signed in, but no plan permission.':'Anmeldung abgeschlossen. Zur Begleit-App wechseln und Modelle laden. / Sign-in complete. Return to the companion and load models.';}
        catch(e){message='Anmeldung fehlgeschlagen / Sign-in failed: '+publicError(e).code;}
        res.writeHead(200,{...safeHeaders,'Content-Type':'text/html; charset=utf-8'});res.end('<!doctype html><meta charset="utf-8"><title>ForeverAI</title><h1>ForeverAI</h1><p>'+message+'</p><p><a href="/">Zur Begleit-App / Return to companion</a></p>');return;
      }
      if(pathname==='/api/session'&&req.method==='POST'){
        if(req.headers.origin!==origin)throw new AppError('invalid_origin');
        const b=await body(req);if(redeemed||!equal(b.launch,launch))throw new AppError('invalid_launch','Start the companion again from Start-Windows.cmd.');
        redeemed=true;send(res,200,{ok:true},{'Set-Cookie':`fg_session=${session}; Path=/; HttpOnly; SameSite=Strict`});return;
      }
      if(!pathname.startsWith('/api/')){send(res,404,{code:'not_found'});return;}
      if(!authenticated(req)){send(res,401,{code:'session_required'});return;}
      if(req.method==='GET'&&pathname==='/api/state'){send(res,200,state());return;}
      if(req.method==='GET'&&pathname==='/api/sync/state'){send(res,200,sync.status());return;}
      if(req.method==='GET'&&pathname==='/api/live/state'){send(res,200,live.status());return;}
      if(req.method!=='POST'){send(res,405,{code:'method_not_allowed'});return;}
      if(req.headers.origin!==origin||!equal(req.headers['x-fg-csrf'],csrf)){send(res,403,{code:'csrf_failed'});return;}
      const b=await body(req);
      if(pathname==='/api/settings'){
        const p=validateSettings(b);if(p.customBase!==undefined&&p.customBase!==settings.value.customBase){await vault.update(v=>delete v.keys.custom);providers.clear();}
        await settings.save(p);send(res,200,state());return;
      }
      if(pathname==='/api/key'){
        assertProvider(b.provider);if(['chatgpt','ollama'].includes(b.provider)||typeof b.key!=='string'||!b.key.trim()||b.key.length>8192||/[\s\x00-\x1f\x7f]/.test(b.key))throw new AppError('invalid_key');
        const record={value:b.key};if(b.provider==='custom')record.base=validateBaseURL(settings.value.customBase);
        await vault.update(v=>{v.keys[b.provider]=record;});if(['gemini','groq','mistral'].includes(b.provider))await settings.save({freeTierConfirmed:{...settings.value.freeTierConfirmed,[b.provider]:false}});providers.clear();send(res,200,{saved:true,persistent:vault.persistent});return;
      }
      if(pathname==='/api/login'){send(res,200,{url:auth.begin(b.provider,origin,typeof b.accountID==='string'?b.accountID:'')});return;}
      if(pathname==='/api/logout'){assertProvider(b.provider);activeController?.abort();const result=await auth.logout(b.provider);if(b.provider==='chatgpt')await settings.save({planConfirmed:false});if(['gemini','groq','mistral'].includes(b.provider))await settings.save({freeTierConfirmed:{...settings.value.freeTierConfirmed,[b.provider]:false}});providers.clear();send(res,200,result);return;}
      if(pathname==='/api/models'||pathname==='/api/catalog'){
        const provider=assertProvider(b.provider);let list=await providers.models(provider,settings.value,{fresh:true});
        if(settings.value.freeOnly&&provider==='openrouter')list=list.filter(m=>m.free);
        if(pathname==='/api/catalog')send(res,200,catalogPacket(provider,list));else send(res,200,{models:list});return;
      }
      if(pathname==='/api/live/config'){send(res,200,await live.configure(b));return;}
      if(pathname==='/api/sync/config'){const result=await sync.configure(b);
        if(result.enabled)void sync.refresh({force:true}).catch(()=>{});send(res,200,sync.status());return;}
      if(pathname==='/api/sync/run'){if(!sync.config.enabled)throw new AppError('sync_not_enabled');
        void sync.refresh({force:true}).catch(()=>{});send(res,200,sync.status());return;}
      if(pathname==='/api/online/search'){send(res,200,await online.search(b));return;}
      if(pathname==='/api/packet'){send(res,200,{...replyPacket(b.text,'web','manual'),route:extractRoute(b.text)});return;}
      if(pathname==='/api/cancel'){activeController?.abort();send(res,200,{ok:true});return;}
      if(pathname==='/api/chat'){
        if(busy)throw new AppError('busy','Eine Anfrage läuft bereits. / A request is already running.');
        const provider=assertProvider(b.provider);busy=true;const controller=new AbortController();activeController=controller;
        const end=()=>controller.abort();res.on('close',end);
        res.writeHead(200,{...safeHeaders,'Content-Type':'application/x-ndjson; charset=utf-8'});
        const emit=x=>{if(!res.destroyed)res.write(JSON.stringify(x)+'\n');};
        try{
          const result=await providers.chat(provider,b,{...settings.value},{signal:controller.signal,onDelta:text=>emit({type:'delta',text})});
          emit({type:'done',...result,...replyPacket(result.text,provider,result.model),route:extractRoute(result.text)});
        }catch(e){emit({type:'error',...publicError(e)});}finally{busy=false;activeController=null;res.off('close',end);res.end();}return;
      }
      send(res,404,{code:'not_found'});
    }catch(e){if(!res.headersSent)send(res,e instanceof AppError?e.status:500,publicError(e));else res.end();}
  });
  server.requestTimeout=200000;server.headersTimeout=10000;
  await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(port,'127.0.0.1',resolve);});
  origin='http://127.0.0.1:'+server.address().port;
  if(sync.config.enabled)void sync.refresh().catch(()=>{});
  const syncTimer=setInterval(()=>{if(sync.config.enabled)void sync.refresh().catch(()=>{});},60*60*1000);syncTimer.unref?.();
  return {server,origin,launch,auth,vault,settings,providers,online,sync,live,close:async()=>{clearInterval(syncTimer);activeController?.abort();await live.close();await new Promise(r=>server.close(r));}};
}
function openBrowser(url){
  if(process.platform==='win32'){
    const executable=path.join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
    const p=spawn(executable,['-NoLogo','-NoProfile','-NonInteractive','-Command','Start-Process -FilePath $env:FG_LAUNCH_URL'],{env:{...process.env,FG_LAUNCH_URL:url},windowsHide:true,stdio:'ignore'});p.on('error',()=>console.error('Browserstart fehlgeschlagen. / Could not open browser.'));p.unref();
  }else{const p=spawn(process.platform==='darwin'?'open':'xdg-open',[url],{stdio:'ignore'});p.on('error',()=>{});p.unref();}
}
if(process.argv[1]&&import.meta.url===pathToFileURL(path.resolve(process.argv[1])).href){
  let unlock;
  try{
    const directory=dataDirectory();unlock=await acquireLock(directory);const app=await createApp({directory});
    console.log('ForeverAI '+VERSION+' | Lokale Begleit-App / local companion');
    console.log('Dieses Fenster offen lassen. Schliessen beendet die App. / Keep this console open.');
    console.log(app.vault.persistent?'Anmeldedaten: Windows DPAPI. / Credentials: Windows DPAPI.':'Nur Sitzungsspeicher: ausserhalb Windows keine dauerhafte Tokenablage. / Session-only credentials on this OS.');
    openBrowser(app.origin+'/#launch='+app.launch);
    const stop=async()=>{await app.close();await unlock();process.exit(0);};process.once('SIGINT',stop);process.once('SIGTERM',stop);
    process.once('exit',()=>{ /* Atomic lock is removed by the normal stop handler; stale PID handled on next launch. */ });
  }catch(e){console.error(publicError(e).message);if(unlock)await unlock();process.exitCode=1;}
}
