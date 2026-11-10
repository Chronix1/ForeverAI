// Local UI test server. All provider calls are synthetic. Never uses real keys.
import {mkdtemp,rm} from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
import {createApp} from '../server.mjs';
const dir=await mkdtemp(path.join(os.tmpdir(),'fg-ui-'));
const app=await createApp({directory:dir,persistent:false,fetcher:async(url,opts={})=>{
 if(url.endsWith('/models'))return new Response(JSON.stringify({data:[{id:'fixture/fast:free',name:'Fixture Fast (simuliert)',pricing:{prompt:'0',completion:'0'},supported_parameters:['reasoning']},{id:'fixture/simple:free',name:'Fixture Simple (simuliert)',pricing:{prompt:'0',completion:'0'},supported_parameters:[]}]}));
 if(url.endsWith('/chat/completions')){
  const b=JSON.parse(opts.body),content=b.messages.at(-1).content;
  const text=content.includes('CLARIFY_DM')?'{"answer":"CLARIFY_DM"}':content.includes('NO_VERIFIED_COORDINATES')?'{"answer":"NO_VERIFIED_COORDINATES"}':content.includes('T42')?'{"answer":"T42"}':'Simulierte Testantwort. Für verlässliche Dungeon- und Questdaten benötige ich versionsgeprüfte Informationen. Keine Koordinaten wurden erfunden.';
  return new Response('data: '+JSON.stringify({choices:[{delta:{content:text}}]})+'\n\ndata: '+JSON.stringify({choices:[{delta:{},finish_reason:'stop'}]})+'\n\ndata: [DONE]\n\n');
 }throw Error('No real network in UI fixture');
}});
await app.vault.update(v=>{v.keys.openrouter={value:'UI-TEST-ONLY-NOT-A-KEY'};});
console.log(JSON.stringify({url:app.origin+'/#launch='+app.launch,origin:app.origin}));
process.on('SIGTERM',async()=>{await app.close();await rm(dir,{recursive:true,force:true});process.exit(0);});
