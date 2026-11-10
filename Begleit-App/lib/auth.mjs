/** Official public-client OAuth only. Never reads Chrome cookies or game memory. */
import {createHash, createPublicKey, verify} from 'node:crypto';
import {AppError, token, equal} from './common.mjs';
import {jsonRequest, request} from './network.mjs';
const ISSUER='https://auth.openai.com';
const RESOURCE='https://api.openai.com/v1';
const SCOPE='openid profile email offline_access resource.invoke chatgpt.tokens.use.direct';
const form = (data) => ({method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams(data).toString()});
export function verifyIdentity(jwt, keys, {clientID,nonce,subject,now=Date.now()/1000}={}) {
  try {
    if(typeof jwt!=='string'||jwt.length>32768)throw Error();
    const parts=jwt.split('.'); if(parts.length!==3 || parts.some(p=>!/^[-_A-Za-z0-9]+$/.test(p)))throw Error();
    const header=JSON.parse(Buffer.from(parts[0],'base64url')), payload=JSON.parse(Buffer.from(parts[1],'base64url'));
    if(!['RS256','ES256'].includes(header.alg)||typeof header.kid!=='string'||header.crit)throw Error();
    const jwk=keys.find(k=>k.kid===header.kid && (!k.alg||k.alg===header.alg) && (!k.use||k.use==='sig') && (!k.key_ops||k.key_ops.includes('verify')));
    if(!jwk||jwk.d||(header.alg==='RS256'&&jwk.kty!=='RSA')||(header.alg==='ES256'&&(jwk.kty!=='EC'||jwk.crv!=='P-256')))throw Error();
    const key=createPublicKey({key:jwk,format:'jwk'});
    if(header.alg==='RS256' && key.asymmetricKeyDetails?.modulusLength<2048)throw Error();
    if(!verify('sha256',Buffer.from(parts[0]+'.'+parts[1]),{key,dsaEncoding:'ieee-p1363'},Buffer.from(parts[2],'base64url')))throw Error();
    const aud=Array.isArray(payload.aud)?payload.aud:[payload.aud];
    if(payload.iss!==ISSUER || !aud.includes(clientID) || (aud.length>1&&payload.azp!==clientID) || (payload.azp&&payload.azp!==clientID))throw Error();
    if(!Number.isFinite(payload.exp)||payload.exp<=now-5||!Number.isFinite(payload.iat)||payload.iat>now+5||(payload.nbf!=null&&(!Number.isFinite(payload.nbf)||payload.nbf>now+5)))throw Error();
    if(typeof payload.sub!=='string'||!payload.sub||payload.sub.length>500)throw Error();
    if(nonce!=null && !equal(payload.nonce,nonce))throw Error();
    if(subject!=null && payload.sub!==subject)throw Error();
    return {subject:payload.sub,email:typeof payload.email==='string'?payload.email.slice(0,320):'',name:typeof payload.name==='string'?payload.name.slice(0,150):''};
  } catch {throw new AppError('identity_validation_failed','Identity signature or account validation failed. No credentials were saved.');}
}
function credential(t,previous={}) {
  if(typeof t.access_token!=='string'||t.access_token.length>32768||!t.access_token||!/^bearer$/i.test(t.token_type||'')||!Number.isFinite(t.expires_in)||t.expires_in<=0)throw new AppError('invalid_token_response');
  if(t.refresh_token!=null && (typeof t.refresh_token!=='string'||t.refresh_token.length>32768))throw new AppError('invalid_token_response');
  const scopes=typeof t.scope==='string'?t.scope.split(/\s+/).filter(Boolean):previous.scopes||[];
  return {...previous,access_token:t.access_token,refresh_token:t.refresh_token||previous.refresh_token||'',id_token:t.id_token||previous.id_token||'',scopes,expiresAt:Date.now()+t.expires_in*1000};
}
export class Auth {
  constructor(vault,settings,{fetcher=fetch}={}){this.vault=vault;this.settings=settings;this.fetcher=fetcher;this.pending=new Map();this.refreshing=new Map();this.epoch=0;}
  async discovery(){
    const d=await jsonRequest(ISSUER+'/.well-known/openid-configuration',{},this.fetcher);
    if(d.issuer!==ISSUER)throw new AppError('invalid_discovery');
    for(const k of ['jwks_uri','token_endpoint','authorization_endpoint','revocation_endpoint']){
      if(!d[k])continue;const u=new URL(d[k]);if(u.origin!==ISSUER||u.username||u.password||u.hash)throw new AppError('invalid_discovery');
    } return d;
  }
  async identity(jwt,expected){const d=await this.discovery();const jwks=await jsonRequest(d.jwks_uri,{},this.fetcher);if(!Array.isArray(jwks.keys))throw new AppError('invalid_jwks');return verifyIdentity(jwt,jwks.keys,expected);}
  begin(provider,origin,accountID='') {
    if(!['chatgpt','openrouter'].includes(provider))throw new AppError('oauth_not_supported');
    for(const [key,p] of this.pending)if(p.provider===provider||p.expires<Date.now())this.pending.delete(key);
    const state=token(),verifier=token(48),nonce=token(),challenge=createHash('sha256').update(verifier).digest('base64url');
    const p={provider,state,verifier,nonce,expires:Date.now()+600000,epoch:this.epoch};let u;
    if(provider==='chatgpt'){
      const account=accountID?this.vault.get().accounts[accountID]:null;
      if(accountID&&!account)throw new AppError('unknown_account');
      p.accountID=accountID;p.previous=account;p.clientID=account?.client_id||'dynamic_agent_client';p.redirect=origin+'/auth/callback';
      u=new URL(ISSUER+'/api/accounts/authorize');
      const params={client_id:p.clientID,ext_agent_host_id:this.settings.value.hostID,response_type:'code',redirect_uri:p.redirect,scope:SCOPE,resource:RESOURCE,state,nonce,code_challenge_method:'S256',code_challenge:challenge};
      if(account){if(account.id_token)params.id_token_hint=account.id_token;if(account.email)params.login_hint=account.email;}else params.agent_name_hint='ForeverAI';
      Object.entries(params).forEach(([k,v])=>u.searchParams.set(k,v));
    }else{
      p.redirect=origin+'/auth/openrouter/callback';u=new URL('https://openrouter.ai/auth');
      Object.entries({callback_url:p.redirect,state,code_challenge:challenge,code_challenge_method:'S256',key_label:'ForeverAI'}).forEach(([k,v])=>u.searchParams.set(k,v));
    }
    this.pending.set(state,p);return u.href;
  }
  async finish(provider,query){
    const state=query.get('state')||'',p=this.pending.get(state);
    if(!p||p.provider!==provider||p.expires<Date.now())throw new AppError('invalid_oauth_state','Login expired or state did not match. Start a new sign-in.');
    this.pending.delete(state); // One-time consumption, even on denial or token failure.
    if(query.get('error'))throw new AppError('oauth_denied','Login was not approved. Existing credentials were not changed.');
    const code=query.get('code');if(!code||code.length>8192)throw new AppError('invalid_oauth_code');
    if(provider==='openrouter'){
      const t=await jsonRequest('https://openrouter.ai/api/v1/auth/keys',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({code,code_verifier:p.verifier,code_challenge_method:'S256'})},this.fetcher);
      if(typeof t.key!=='string'||!t.key||t.key.length>8192)throw new AppError('invalid_key_response');
      if(p.epoch!==this.epoch)throw new AppError('login_cancelled');
      await this.vault.update(v=>{v.keys.openrouter={value:t.key};});return {provider};
    }
    let clientID=query.get('client_id');
    if(p.clientID==='dynamic_agent_client'){
      if(!clientID||clientID==='dynamic_agent_client'||!/^[-_A-Za-z0-9]{3,250}$/.test(clientID))throw new AppError('registration_incomplete');
    }else{if(clientID&&clientID!==p.clientID)throw new AppError('client_mismatch');clientID=p.clientID;}
    const t=await jsonRequest(ISSUER+'/api/accounts/oauth/token',form({grant_type:'authorization_code',client_id:clientID,code,code_verifier:p.verifier,redirect_uri:p.redirect,resource:RESOURCE}),this.fetcher);
    const identity=await this.identity(t.id_token,{clientID,nonce:p.nonce,subject:p.previous?.subject});
    const cred={...credential(t),...identity,client_id:clientID};
    const id=clientID; if(p.epoch!==this.epoch)throw new AppError('login_cancelled');
    await this.vault.update(v=>{if(v.accounts[id]&&v.accounts[id].subject!==identity.subject)throw new AppError('account_mismatch');v.accounts[id]=cred;v.activeAccount=id;});
    return {provider,permission:cred.scopes.includes('chatgpt.tokens.use.direct')};
  }
  async access(){
    const v=this.vault.get(),id=v.activeAccount,a=v.accounts[id];
    if(!a?.access_token)throw new AppError('login_required','Sign in with ChatGPT first.');
    if(!a.scopes.includes('chatgpt.tokens.use.direct'))throw new AppError('plan_permission_missing','ChatGPT plan use was not granted. Reauthorize or choose a different provider.');
    if(a.expiresAt>Date.now()+90000)return a.access_token;
    if(!this.refreshing.has(id)){
      const task=this.refresh(id,a).finally(()=>this.refreshing.delete(id));this.refreshing.set(id,task);
    }return (await this.refreshing.get(id)).access_token;
  }
  async refresh(id,a){
    if(!a.refresh_token)throw new AppError('reauth_required');const epoch=this.epoch;
    const t=await jsonRequest(ISSUER+'/api/accounts/oauth/token',form({grant_type:'refresh_token',client_id:a.client_id,refresh_token:a.refresh_token,resource:RESOURCE}),this.fetcher);
    if(t.id_token)await this.identity(t.id_token,{clientID:a.client_id,subject:a.subject});
    const c=credential(t,a);if(epoch!==this.epoch)throw new AppError('session_ended');
    await this.vault.update(v=>{if(v.accounts[id]?.refresh_token!==a.refresh_token)throw new AppError('session_changed');v.accounts[id]=c;});
    if(!c.scopes.includes('chatgpt.tokens.use.direct'))throw new AppError('plan_permission_missing');return c;
  }
  async logout(provider){
    this.epoch++;this.pending.clear();
    if(provider!=='chatgpt'){await this.vault.update(v=>delete v.keys[provider]);return {remoteRevoked:false,localOnly:true};}
    const v=this.vault.get(),id=v.activeAccount,a=v.accounts[id];let revoked=false;
    if(a?.refresh_token){try{const d=await this.discovery();if(d.revocation_endpoint){await request(d.revocation_endpoint,form({token:a.refresh_token,token_type_hint:'refresh_token',client_id:a.client_id}),this.fetcher,15000);revoked=true;}}catch{}}
    await this.vault.update(x=>{if(a)x.accounts[id]={client_id:a.client_id,subject:a.subject,email:a.email,name:a.name,scopes:[]};x.activeAccount=null;});
    return {remoteRevoked:revoked,localOnly:!revoked};
  }
}
