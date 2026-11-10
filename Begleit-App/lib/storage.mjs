import { promises as fs, existsSync } from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { AppError, token } from './common.mjs';
export function dataDirectory() {
  // Avoid losing existing DPAPI-protected logins on an upgrade from ForeverGuide.
  const override=process.env.FOREVERAI_DATA_DIR || process.env.FG_DATA_DIR;
  if(override)return override;
  const parent=process.platform==='win32'?(process.env.LOCALAPPDATA || os.homedir()):path.join(os.homedir(),'.config');
  const fresh=path.join(parent,'ForeverAI'), previous=path.join(parent,'ForeverGuide');
  return existsSync(fresh)?fresh:(existsSync(previous)?previous:fresh);
}
export async function atomicWrite(filename, content) {
  await fs.mkdir(path.dirname(filename), {recursive:true, mode:0o700});
  const temporary=filename+'.'+token(8)+'.tmp';
  try { await fs.writeFile(temporary, content, {mode:0o600, flag:'wx'}); await fs.rename(temporary,filename); }
  finally { await fs.unlink(temporary).catch(()=>{}); }
}
export function dpapi(data, decrypt=false) {
  if (process.platform!=='win32') return Promise.reject(new AppError('secure_storage_unavailable'));
  const method=decrypt?'Unprotect':'Protect';
  // Fixed command. Secret bytes are transferred on stdin, never argv, shell interpolation, or a temp file.
  const code=`$ErrorActionPreference='Stop'; Add-Type -AssemblyName System.Security; $b=[Convert]::FromBase64String([Console]::In.ReadToEnd()); $r=[System.Security.Cryptography.ProtectedData]::${method}($b,$null,[System.Security.Cryptography.DataProtectionScope]::CurrentUser); [Console]::Out.Write([Convert]::ToBase64String($r))`;
  const executable=path.join(process.env.SystemRoot || 'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
  return new Promise((resolve,reject)=>{
    const p=spawn(executable,['-NoLogo','-NoProfile','-NonInteractive','-Command',code],{windowsHide:true,stdio:['pipe','pipe','pipe']});
    let out='',failed=false;
    const timer=setTimeout(()=>{failed=true;p.kill();reject(new AppError('secure_storage_timeout'));},15000);
    p.stdout.on('data',b=>{out+=b.toString(); if(out.length>2*1024*1024){failed=true;p.kill();}});
    p.stderr.resume();
    p.on('error',()=>{clearTimeout(timer);reject(new AppError('secure_storage_failed','Windows credential protection failed. No plaintext fallback is used.'));});
    p.on('close',exit=>{clearTimeout(timer); if(failed||exit!==0)reject(new AppError('secure_storage_failed','Windows credential protection failed. No plaintext fallback is used.')); else resolve(Buffer.from(out.trim(),'base64'));});
    p.stdin.on('error',()=>{}); p.stdin.end(Buffer.from(data).toString('base64'));
  });
}
export class Vault {
  constructor(directory, {persistent=process.platform==='win32', protector=dpapi}={}) {this.dir=directory;this.persistent=persistent;this.protector=protector;this.value={accounts:{},keys:{},activeAccount:null};this.queue=Promise.resolve();}
  async load(){
    if(!this.persistent)return;
    try{const data=await fs.readFile(path.join(this.dir,'credentials.dpapi')); const value=JSON.parse((await this.protector(data,true)).toString('utf8'));
      if(!value.accounts||!value.keys)throw new Error(); this.value=value;
    }catch(e){if(e.code!=='ENOENT')throw new AppError('vault_locked','Stored credentials could not be decrypted. Use the same Windows account; no unencrypted fallback is used.');}
  }
  get(){return structuredClone(this.value);}
  async update(mutator){
    const operation=this.queue.then(async()=>{const next=this.get();await mutator(next);if(this.persistent)await atomicWrite(path.join(this.dir,'credentials.dpapi'),await this.protector(Buffer.from(JSON.stringify(next)),false));this.value=next;return this.get();});
    this.queue=operation.catch(()=>{});return operation;
  }
}
export class Settings {
  constructor(directory){this.file=path.join(directory,'settings.json');this.value={hostID:'urn:uuid:'+randomUUID(),language:'de',provider:'openrouter',model:'',effort:'default',maxTokens:4096,customBase:'',freeOnly:true,freeTierConfirmed:{},planConfirmed:false};this.queue=Promise.resolve();}
  async load(){try{const j=JSON.parse(await fs.readFile(this.file,'utf8'));for(const k of Object.keys(this.value)){if(Object.hasOwn(j,k))this.value[k]=j[k];}}catch(e){if(e.code!=='ENOENT')throw new AppError('settings_invalid');} if(!/^urn:uuid:[0-9a-f-]{36}$/.test(this.value.hostID))this.value.hostID='urn:uuid:'+randomUUID(); await this.save({});}
  async save(patch){const task=this.queue.then(async()=>{const next={...this.value,...patch};await atomicWrite(this.file,JSON.stringify(next,null,2));this.value=next;return {...next};});this.queue=task.catch(()=>{});return task;}
}
export async function acquireLock(directory){
  await fs.mkdir(directory,{recursive:true,mode:0o700});const file=path.join(directory,'running.lock');
  for(let attempt=0;attempt<2;attempt++){
    try{await fs.writeFile(file,String(process.pid),{flag:'wx',mode:0o600});return ()=>fs.unlink(file).catch(()=>{});}
    catch(e){if(e.code!=='EEXIST')throw e;const pid=Number(await fs.readFile(file,'utf8').catch(()=>''));let active=pid>0;
      if(active){try{process.kill(pid,0);}catch(err){active=err.code!=='ESRCH';}}
      if(active)throw new AppError('already_running','ForeverAI is already running. Close its existing console before starting it again.');
      await fs.unlink(file).catch(()=>{});
    }
  }throw new AppError('already_running');
}
