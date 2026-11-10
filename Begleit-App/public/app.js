'use strict';
const $=id=>document.getElementById(id);
const EN={heading:'Your game guide. Your choice of AI.',boundary:'Experimental automatic AI bridge: after one-time setup, ask questions in ForeverAI and receive replies in game. Windows in windowed/borderless mode, companion running. No character control or browser cookies.',providerHeading:'1 · AI access',provider:'Provider',freeOnly:'Free mode: no paid API fallback models',tierConfirmed:'Verified at the provider: free tier with no paid billing enabled. The app cannot verify this itself.',planConfirmed:'I use my authorized ChatGPT allowance and have checked extra credits / app limits. This is not unlimited free access.',endpoint:'API base URL (HTTPS or a local server)',saveEndpoint:'Save address',account:'ChatGPT account',apiKey:'API key (never your password)',saveKey:'Save key securely',accountPage:'Open provider account',logout:'Remove access',modelHeading:'2 · Model and reasoning',loadModels:'Load available models',model:'Model from provider catalog',effort:'Reasoning level',effortNote:'Levels from catalog metadata or documented model families. Unknown models use their default. Providers do not all support the same levels.',maxTokens:'Maximum output tokens',copyCatalog:'Copy model list for addon',catalogHint:'For live AI use /fai modelle in game to load available models. Manual import remains an optional fallback.',chatHeading:'3 · Ask about the game',context:'Context from addon (optional; review before sending)',adopt:'Apply model preference from addon',clearChat:'Clear conversation and context',question:'Your question · German or English',send:'Send question to selected provider',cancel:'Cancel',privacy:'Your question, pasted context and session history are sent only to your selected AI service. Free tiers may have different privacy terms. No automatic provider rotation.',copyAnswer:'Copy answer for addon',copyRoute:'Copy unverified route suggestion',routeWarning:'Imported AI answers remain unverified. A route suggestion is not proof of a walkable path. Check the data before starting navigation.',webHeading:'Webchat without your own API integration',webExplanation:'For your open AI websites: copy the prompt, paste it in your browser chat, and paste the answer below. The app does not read tabs or browser tokens. Each service controls its free limits and available models.',copyPrompt:'Copy prompt',openWebsite:'Open webchat',manualAnswer:'Answer from webchat',copyManual:'Copy web answer for addon',benchHeading:'Compare models on your computer',benchExplanation:'Compares three synthetic DE/EN tasks for data fidelity, time to first visible text, and total time. Not a test of WoW knowledge. Consumes requests / quota. Starts only when you click.',addCandidate:'Add current setting to comparison',clearCandidates:'Clear selection',runBenchmark:'Start comparison',downloadBenchmark:'Save measurements',clipboardFallback:'Copy field when clipboard access is blocked',copyFallbackHint:'Select text and press Ctrl+C. Nothing is pasted into WoW automatically.',footer:'ForeverAI 1.0.0-alpha · Open-source local companion · Not published by Blizzard or an AI provider · Live operation on your account not yet tested.'};
Object.assign(EN,{onlineHeading:'6 · Optional online lookup',onlineInfo:'Look up current community data for WoW Forever. No AI sign-in or key. Only your search phrase and optional level are sent to Forever Companion, not your character profile. Import the results into WoW.',onlineQuestion:'Dungeon, quest, item, rare or question',onlineCategory:'Category',onlineLevel:'Level (optional)',onlineSearch:'Search online now (free)',onlineCopy:'Copy results for WoW addon',onlineDisclaimer:'Source and data age are shown. Community matches are not verified walking routes. In WoW: Import → Check → Apply → choose a result.'});
Object.assign(EN,{liveHeading:'4 · Live AI in WoW (experimental)',liveInfo:'One-time setup: the companion captures ONLY the pixel strip at the top-left of the WoW client window, queries your chosen provider and delivers replies through preinstalled data-only addons. No character controls, game memory access or Chrome cookies. Fully restart WoW after setup, then type /fai live on.',livePath:'WoW Forever game folder (_forever_)',liveEnabled:'Enable live AI bridge (sends your in-game question and minimal character context to the selected AI provider)',liveConfigure:'Configure live AI bridge',liveWarning:'Windows: use windowed or borderless mode; exclusive fullscreen often prevents capture. A complete WoW restart is necessary after first setup. Requests consume provider allowance; free-mode restrictions still apply.'});
Object.assign(EN,{syncHeading:'5 · Automatic in-game data (no import)',syncInfo:'Set your WoW Forever folder once. The desktop companion updates public dungeon, item, quest and rare data every six hours while it runs. WoW reads the file on next login or /reload; configure the experimental live bridge separately.',syncPath:'Path to your WoW Forever installation',syncEnabled:'Check for updates on start and every six hours while companion runs',syncConfig:'Configure and download initial data',syncNow:'Update now',syncLimit:'Only public data requests are sent to Forever Companion. No character names or credentials. /reload is required for new data while WoW is running. Old data survives failures.'});
const DE=Object.fromEntries([...document.querySelectorAll('[data-i18n]')].map(e=>[e.dataset.i18n,e.textContent]));
let lang='de',csrf='',state=null,models=[],history=[],lastResult=null,onlineLast=null,shortlist=[],report=[],benchStop=false,inBenchmark=false;
const tr=(de,en)=>lang==='de'?de:en;
const effortNames={default:['Modellstandard','Model default'],none:['Ohne','None'],minimal:['Minimal','Minimal'],low:['Niedrig','Low'],medium:['Mittel','Medium'],high:['Hoch','High'],xhigh:['Sehr hoch','Very high'],max:['Maximum','Maximum']};
function status(text,error=false){$('status').textContent=text;$('status').classList.toggle('error',error);}
function failure(e){status((e.message||String(e)),true);}
async function api(endpoint,data){
  const options=data===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json','X-FG-CSRF':csrf},body:JSON.stringify(data)};
  const r=await fetch('/api/'+endpoint,options);const j=await r.json();
  if(!r.ok)throw new Error((j.code||r.status)+(j.message?' · '+j.message:''));return j;
}
function renderLive(v){
 if(!v)return;
 $('connectionStatus').textContent=v.lastError ? tr('KI-Brücke: ','AI bridge: ')+v.lastError : (v.captureRunning?tr('KI-Brücke läuft. Fragen und Einstellungen im Spiel öffnen.','AI bridge running. Open questions and settings in game.'):tr('KI-Brücke ist nicht aktiv. Begleit-App nach der Einrichtung neu starten.','AI bridge is inactive. Restart the companion after setup.'));
 if(!$('liveGamePath').value && v.addonPath)$('liveGamePath').value=v.addonPath.replace(/[\\/]Interface[\\/]AddOns[\\/]ForeverAI$/i,'');
 if(!$('liveGamePath').value && state?.sync?.gamePath)$('liveGamePath').value=state.sync.gamePath;
 $('liveEnabled').checked=v.enabled;
 $('liveStatus').textContent=(v.enabled?tr('Aktiviert','Enabled'):tr('Deaktiviert','Disabled'))+' · '+(v.captureRunning?tr('Bildschirmbrücke läuft','Capture bridge running'):tr('Bildschirmbrücke nicht aktiv','Capture bridge inactive'))+' · '+(v.addonPath||tr('WoW-Ordner noch nicht eingerichtet','WoW path not configured'))+' · '+(v.count||0)+' '+tr('fertige Antworten','completed replies')+(v.lastError?' · '+tr('Fehler: ','Error: ')+v.lastError:'');
}
function renderSync(v){
  if(!v)return;
  if(!$('syncGamePath').value && v.gamePath)$('syncGamePath').value=v.gamePath;
  $('syncEnabled').checked=v.configured?v.enabled:true;
  const c=v.counts;
  const details=c?`${c.dungeons} ${tr('Dungeons','dungeons')}, ${c.items} Items, ${c.quests} Quests, ${c.rares} Rares${c.incomplete?tr(' (Teilauswahl)',' (partial cache)'):''}`:tr('Noch keine Daten synchronisiert.','No synchronized data yet.');
  const last=v.lastSuccess?new Date(v.lastSuccess).toLocaleString(lang==='de'?'de-DE':'en-GB'):tr('noch nie','never');
  $('syncStatus').textContent=(v.busy?tr('Lade öffentliche Daten … ','Downloading public data … '):'')+details+' · '+tr('Letzter Erfolg: ','Last success: ')+last+' · '+(v.addonPath||tr('Bitte WoW-Forever-Pfad angeben.','Enter WoW Forever folder.'))+(v.lastError?' · '+tr('Fehler: ','Error: ')+v.lastError:'');
  $('syncNow').disabled=!v.enabled||v.busy;
}
function setLanguage(v){lang=v;document.documentElement.lang=v;$('language').value=v;for(const e of document.querySelectorAll('[data-i18n]'))e.textContent=(v==='en'?EN:DE)[e.dataset.i18n]||DE[e.dataset.i18n];if(state?.sync)renderSync(state.sync);if(state?.live)renderLive(state.live);$('context').placeholder=tr('WoW: KI-Export → Alles markieren → Strg+C → hier Strg+V','WoW: AI export → Select all → Ctrl+C → paste here with Ctrl+V');$('question').placeholder=tr('Welche Dungeons kommen für meinen Krieger auf Level 22 infrage?','Which dungeons are suitable for my level 22 warrior?');renderProvider();renderEfforts();}
function selected(){return {provider:$('provider').value,model:$('model').value,effort:$('effort').value||'default'};}
async function save(patch){state=await api('settings',patch);csrf=state.csrf;return state;}
function option(select,value,label){const o=document.createElement('option');o.value=value;o.textContent=label;select.append(o);}
function renderProvider(){
  if(!state)return;const id=$('provider').value,p=state.providers[id];if(!p)return;
  $('freeOnly').checked=state.settings.freeOnly;
  $('tierRow').hidden=!['gemini','groq','mistral'].includes(id);$('tierConfirmed').checked=!!state.settings.freeTierConfirmed[id];
  $('planRow').hidden=id!=='chatgpt';$('planConfirmed').checked=state.settings.planConfirmed;
  $('customRow').hidden=id!=='custom';$('customBase').value=state.settings.customBase;
  $('oauthRow').hidden=!['chatgpt','openrouter'].includes(id);$('account').hidden=id!=='chatgpt';document.querySelector('label[for=account]').hidden=id!=='chatgpt';
  $('keyRow').hidden=['chatgpt','ollama'].includes(id);$('logout').hidden=id==='ollama';
  $('login').textContent=id==='openrouter'?tr('Bei OpenRouter anmelden','Sign in to OpenRouter'):'Continue with ChatGPT';
  $('login').toggleAttribute('data-oai-siwc-button',id==='chatgpt');
  $('providerHelp').href=p.help||'#';$('providerHelp').hidden=!p.help;
  const notes={catalog:tr('Es werden nur live mit Nullpreis gelistete Modelle zugelassen. Verfügbarkeit und Gratis-Limits liegen bei OpenRouter.','Only models currently listed at zero price are allowed. OpenRouter controls availability and free limits.'),conditional:tr('Kostenlos nur im passenden Free Tier. Ein Schlüssel aus einem kostenpflichtigen Projekt kann Gebühren auslösen. Keine automatische Prüfung deiner Abrechnung.','Free only in the relevant free tier. A key from a paid project may incur charges. Billing is not automatically verified.'),local:tr('Nur bereits installierte lokale Ollama-Modelle. Cloud-Einträge werden ausgeschlossen. Dein Rechner benötigt Leistung und Strom.','Already-installed local Ollama models only. Cloud entries are excluded. Your computer uses hardware resources and electricity.'),paid:tr('Separat abgerechnete API. Ein kostenloser Webchat ist keine kostenlose API. Im Gratis-Modus gesperrt.','Separately billed API. A free webchat does not make the API free. Blocked in free mode.'),plan:tr('Offizieller ChatGPT-Login. Verwendet die freigegebenen Limits deines Tarifs; keine Browser-Tokens und kein extra API-Key.','Official ChatGPT sign-in. Uses your authorized plan allowance, not browser tokens or a separate API key.'),unknown:tr('Kosten und Fähigkeiten unbekannt. Nur OpenAI-kompatible Chat-Completions; im Gratis-Modus gesperrt.','Unknown pricing and capabilities. OpenAI-compatible Chat Completions only; blocked in free mode.')};
  $('costNote').textContent=notes[p.cost];
  const a=state.accounts.find(x=>x.id===state.activeAccount);
  $('credentialState').textContent=id==='ollama'?tr('Kein Schlüssel erforderlich. Ollama muss lokal laufen.','No key needed. Ollama must be running locally.'):id==='chatgpt'?(a?.connected?(a.permission?tr('Angemeldet: ','Signed in: '):tr('Angemeldet, aber ohne Kontingentfreigabe: ','Signed in without plan permission: '))+(a?.name||''):tr('Noch nicht angemeldet.','Not signed in yet.')):state.keys[id]?tr('Zugang gespeichert. Modell im Spiel auswählen.','Access saved. Select a model in game.'):tr('Noch kein Schlüssel gespeichert.','No key saved yet.');
  $('storageState').textContent=state.persistent?tr('Zugangsdaten: mit Windows DPAPI für dein Benutzerkonto geschützt. Nicht im Addon gespeichert.','Credentials: protected with Windows DPAPI for your user account. Not stored in the addon.'):tr('Auf diesem Betriebssystem nur für diese Sitzung gespeichert; keine Klartextablage.','On this operating system, credentials are kept in memory for this session only; no plaintext storage.');
  const old=$('account').value;$('account').replaceChildren();option($('account'),'','Neues Konto / New account');for(const a of state.accounts)option($('account'),a.id,a.name);$('account').value=state.accounts.some(a=>a.id===old)?old:state.activeAccount||'';
}
function renderEfforts(){const wanted=$('effort').value||state?.settings.effort||'default';const m=models.find(x=>x.id===$('model').value);$('effort').replaceChildren();for(const e of m?.efforts||['default'])option($('effort'),e,(effortNames[e]||[e,e])[lang==='de'?0:1]);$('effort').value=(m?.efforts||['default']).includes(wanted)?wanted:'default';}
async function loadModels(){
  status(tr('Modellkatalog wird geladen …','Loading model catalog …'));const id=$('provider').value;
  const j=await api('models',{provider:id});if($('provider').value!==id)return;
  models=j.models;const preferred=state.settings.model;$('model').replaceChildren();for(const m of models)option($('model'),m.id,m.name+(m.free?' · free':''));
  if(models.some(m=>m.id===preferred))$('model').value=preferred;renderEfforts();
  if(models.length)await save(selected());status(tr(`${models.length} Modelle geladen. Auswahl prüfen.`,`${models.length} models loaded. Review your selection.`));
}
function click(id,fn){$(id).addEventListener('click',()=>Promise.resolve().then(fn).catch(failure));}
async function copy(text){$('copyFallback').value=text;try{await navigator.clipboard.writeText(text);status(tr('Kopiert. In WoW: Import → Prüfen → Übernehmen.','Copied. In WoW: Import → Check → Apply.'));}catch{$('copyFallback').parentElement.open=true;$('copyFallback').focus();$('copyFallback').select();status(tr('Zwischenablage gesperrt: Text im Kopierfeld mit Strg+C kopieren.','Clipboard blocked: press Ctrl+C in the copy field.'));}}
function bubble(who,text,user=false,error=false){const div=document.createElement('div');div.className='bubble'+(user?' user':'')+(error?' error':'');const name=document.createElement('div');name.className='who';name.textContent=who;const body=document.createElement('div');body.textContent=text;div.append(name,body);$('conversation').append(div);$('conversation').scrollTop=$('conversation').scrollHeight;return body;}
function questionValue(){let q=$('question').value.trim();if(!q){const m=$('context').value.match(/^(?:Meine Frage|My question):\s*(.+)$/mi);if(m)q=m[1];}if(!q)throw new Error(tr('Bitte eine Frage eingeben.','Enter a question.'));return q;}
async function streamChat(payload,onDelta){
  const r=await fetch('/api/chat',{method:'POST',headers:{'Content-Type':'application/json','X-FG-CSRF':csrf},body:JSON.stringify(payload)});
  if(!r.ok){const e=await r.json();throw new Error(e.code+' · '+(e.message||''));}
  let buffer='',result=null;const reader=r.body.getReader(),decoder=new TextDecoder();
  while(true){const {value,done}=await reader.read();if(done)break;buffer+=decoder.decode(value,{stream:true});let i;
    while((i=buffer.indexOf('\n'))>=0){const line=buffer.slice(0,i);buffer=buffer.slice(i+1);if(!line)continue;const j=JSON.parse(line);if(j.type==='delta')onDelta(j.text);if(j.type==='done')result=j;if(j.type==='error')throw new Error(j.code+' · '+j.message);}
  }if(!result)throw new Error(tr('Verbindung ohne vollständige Antwort beendet.','Connection ended without a complete answer.'));return result;
}
function makePayload(config=selected(),question=questionValue(),context=$('context').value,chatHistory=history){return {...config,question,context,history:chatHistory,language:lang};}
async function sendChat(){
  if(inBenchmark)throw new Error(tr('Vergleich läuft.','Comparison in progress.'));const x=makePayload();if(!x.model)throw new Error(tr('Zuerst Modelle laden und auswählen.','Load models and select one first.'));
  $('send').disabled=true;$('copyAnswer').disabled=true;$('copyRoute').disabled=true;lastResult=null;bubble(tr('Du','You'),x.question,true);const text=bubble(x.provider+' / '+x.model,'');
  const wallStart=performance.now();status(tr('Anfrage läuft …','Request in progress …'));
  try{lastResult=await streamChat(x,d=>{text.textContent+=d;$('conversation').scrollTop=$('conversation').scrollHeight;});
    history.push({role:'user',content:x.question},{role:'assistant',content:lastResult.text.slice(0,10000)});history=history.slice(-12);
    $('metrics').textContent=`${lastResult.provider} · ${lastResult.model} · ${lastResult.effort} | ${tr('Erster Text','First text')}: ${lastResult.firstMs} ms | ${tr('Server inkl. Vorprüfung','Server including checks')}: ${lastResult.totalMs} ms | ${tr('Gesamt inkl. Vorprüfung','Total including checks')}: ${Math.round(performance.now()-wallStart)} ms`;
    $('copyAnswer').disabled=false;$('copyRoute').disabled=!lastResult.route;status(tr('Antwort vollständig. KI-Inhalt bitte prüfen.','Answer complete. Verify the AI content.'));
  }catch(e){text.textContent+='\n\n'+tr('[UNVOLLSTÄNDIG – nicht als geprüfte Antwort importieren]','[INCOMPLETE – do not import as a verified answer]');throw e;}finally{$('send').disabled=false;}
}
click('send',sendChat);$('question').addEventListener('keydown',e=>{if(e.ctrlKey&&e.key==='Enter'){e.preventDefault();sendChat().catch(failure);}});
click('cancel',()=>api('cancel',{}));
click('loadModels',loadModels);
click('login',async()=>{const provider=$('provider').value;const win=window.open('about:blank','_blank');try{const j=await api('login',{provider,accountID:provider==='chatgpt'?$('account').value:''});if(win){win.opener=null;win.location=j.url;}else throw new Error(tr('Browser-Popup gesperrt. Popups für diese lokale App erlauben und erneut anmelden.','Popup blocked. Allow popups for this local app and sign in again.'));status(tr('Anmeldung im Browser abschließen; danach Modelle laden.','Complete sign-in in the browser, then load models.'));}catch(e){win?.close();throw e;}});
click('saveKey',async()=>{const key=$('apiKey').value.trim();$('apiKey').value='';await api('key',{provider:$('provider').value,key});state=await api('state');renderProvider();status(tr('Schlüssel gespeichert. Modell im Spiel auswählen.','Key saved. Select a model in game.'));});
click('saveEndpoint',async()=>{await save({customBase:$('customBase').value.trim()});renderProvider();status(tr('Adresse gespeichert. Vorheriger Custom-Schlüssel wurde bei Änderung entfernt.','Address saved. Any previous custom key was removed if the endpoint changed.'));});
click('logout',async()=>{await api('cancel',{});const result=await api('logout',{provider:$('provider').value});state=await api('state');models=[];$('model').replaceChildren();renderProvider();renderEfforts();status(result.remoteRevoked?tr('Erneuerbare Sitzung widerrufen und lokal entfernt.','Renewable session revoked and removed locally.'):tr('Zugang lokal entfernt. Remote-Widerruf nicht bestätigt; beim Anbieter gegebenenfalls zusätzlich trennen.','Access removed locally. Remote revocation not confirmed; disconnect at the provider if needed.'));});
$('provider').addEventListener('change',async()=>{try{await save({provider:$('provider').value,model:'',effort:'default'});models=[];$('model').replaceChildren();$('apiKey').value='';renderProvider();renderEfforts();}catch(e){failure(e);}});
$('language').addEventListener('change',async()=>{try{await save({language:$('language').value});setLanguage($('language').value);}catch(e){failure(e);}});
$('freeOnly').addEventListener('change',async()=>{try{if(!$('freeOnly').checked&&!confirm(tr('Gratis-Schutz ausschalten? API-Anfragen können dann Kosten verursachen.','Disable free mode? API requests may then incur charges.'))){$('freeOnly').checked=true;return;}await save({freeOnly:$('freeOnly').checked});models=[];$('model').replaceChildren();renderProvider();renderEfforts();}catch(e){failure(e);}});
$('tierConfirmed').addEventListener('change',()=>save({freeTierConfirmed:{...state.settings.freeTierConfirmed,[$('provider').value]:$('tierConfirmed').checked}}).then(renderProvider).catch(failure));
$('planConfirmed').addEventListener('change',()=>save({planConfirmed:$('planConfirmed').checked}).then(renderProvider).catch(failure));
$('model').addEventListener('change',()=>{renderEfforts();save(selected()).catch(failure);});
$('effort').addEventListener('change',()=>save(selected()).catch(failure));
$('maxTokens').addEventListener('change',()=>save({maxTokens:Number($('maxTokens').value)}).catch(failure));
click('copyCatalog',async()=>{const j=await api('catalog',{provider:$('provider').value});await copy(j.packet);status(tr(`${j.count} von ${j.total} Modellen kopiert. In WoW importieren.`,`${j.count} of ${j.total} models copied. Import into WoW.`));});
click('adoptPreferences',async()=>{
  const m=$('context').value.match(/^FGP1;([a-z]+);([^;\r\n]+);([a-z]+)\s*$/m);if(!m||!state.providers[m[1]])throw new Error(tr('Kein gültiger Modellwunsch im Kontext.','No valid model preference in context.'));
  if(m[1]!==$('provider').value && !confirm(tr(`Zum Anbieter ${m[1]} wechseln? Der Gratis-Schutz bleibt unverändert.`,`Switch to ${m[1]}? Free mode remains unchanged.`)))return;
  $('provider').value=m[1];await save({provider:m[1],model:m[2]==='auto'?'':m[2],effort:'default'});renderProvider();await loadModels();
  if(m[2]!=='auto'&&!models.some(x=>x.id===m[2]))throw new Error(tr('Gewünschtes Modell ist nicht verfügbar. Keine Anfrage wurde gesendet.','Requested model is unavailable. No inference request was sent.'));
  if(m[2]!=='auto')$('model').value=m[2];renderEfforts();const model=models.find(x=>x.id===$('model').value);if(!model?.efforts.includes(m[3]))throw new Error(tr('Reasoning-Stufe nicht unterstützt. Bitte neu wählen.','Reasoning level unsupported. Select a different one.'));
  $('effort').value=m[3];await save(selected());status(tr('Modellwunsch übernommen. Noch keine Frage gesendet.','Model preference applied. No question sent yet.'));
});

function onlineRender(data){
  const target=$('onlineResults');target.replaceChildren();
  if(!data.results.length){target.textContent=tr('Keine passenden Einträge in dieser Quelle. Versuche einen genaueren Namen oder wähle eine Kategorie.','No matches in this source. Try a more specific name or select a category.');return;}
  for(const result of data.results){
    const box=document.createElement('div');box.className='online-result';
    const title=document.createElement('strong');title.textContent=result.name;
    const sub=document.createElement('small');sub.textContent=`${result.kind} · ${result.detail}`;
    box.append(title,sub);target.append(box);
  }
}
click('onlineSearch',async()=>{
  const q=$('onlineQuery').value.trim()||$('question').value.trim()||(function(){const m=$('context').value.match(/^(?:Meine Frage|My question):\s*(.+)$/mi);return m?.[1]||'';})();
  if(!q)throw new Error(tr('Suchbegriff angeben oder Frage aus dem KI-Export einfügen.','Enter a search term or paste your exported question.'));
  const level=$('onlineLevel').value.trim();
  onlineLast=null;$('onlineCopy').disabled=true;$('onlineResults').textContent='';$('onlineMeta').textContent='';
  $('onlineSearch').disabled=true;status(tr('Kostenlose Datenquelle wird abgefragt …','Querying free data source …'));
  try{
    const result=await api('online/search',{query:q,kind:$('onlineKind').value,...(level?{level:Number(level)}:{})});
    onlineLast=result;onlineRender(result);$('onlineCopy').disabled=!result.packet;
    const date=result.updatedAt?new Date(result.updatedAt).toLocaleString(lang==='de'?'de-DE':'en-GB'):tr('kein Zeitstempel','no timestamp');
    $('onlineMeta').textContent=`${result.source.name} · ${tr('Datenstand','Data updated')}: ${date} · ${result.results.length} ${tr('Treffer','results')}. ${result.note}`;
    status(tr('Online-Suche abgeschlossen. Treffer prüfen und fürs Addon kopieren.','Online search finished. Verify results and copy them to the addon.'));
  }finally{$('onlineSearch').disabled=false;}
});
click('liveConfigure',async()=>{
 const gamePath=$('liveGamePath').value.trim()||$('syncGamePath').value.trim();
 if(!gamePath)throw new Error(tr('Spielordner angeben.','Enter the game folder.'));
 const result=await api('live/config',{gamePath,enabled:$('liveEnabled').checked});
 state.live=result;renderLive(result);
 status(tr('KI-Brücke eingerichtet. WoW vollständig beenden und neu starten; danach /fai live an.','AI bridge configured. Fully quit and restart WoW; then use /fai live on.'));
});
click('syncConfig',async()=>{
  const path=$('syncGamePath').value.trim();
  if(!path)throw new Error(tr('Bitte den WoW-Forever-Ordner eintragen.','Enter the WoW Forever installation folder.'));
  const result=await api('sync/config',{path,enabled:$('syncEnabled').checked});
  state.sync=result;renderSync(result);status(tr('Einrichtung gespeichert. Neue Daten stehen im Spiel nach Login oder /reload bereit.','Configuration saved. New data will be available after login or /reload.'));
});
click('syncNow',async()=>{const result=await api('sync/run',{});state.sync=result;renderSync(result);status(tr('Aktualisierung angefordert. Nach Abschluss WoW neu laden.','Update requested. Reload WoW once finished.'));});
click('onlineCopy',async()=>{if(!onlineLast?.packet)throw new Error(tr('Zuerst online suchen.','Search online first.'));await copy(onlineLast.packet);});
click('copyAnswer',async()=>{if(lastResult){await copy(lastResult.packet);if(lastResult.truncated)status(tr('Die Importkopie wird auf 6500 UTF-8-Bytes gekürzt; die vollständige Antwort bleibt hier.','Import copy is limited to 6500 UTF-8 bytes; the full answer stays here.'));}});
click('copyRoute',()=>{if(lastResult?.route&&confirm(tr('Ungeprüfte Koordinaten: vor Nutzung im Addon verifizieren. Kopieren?','Unverified coordinates: verify before using in the addon. Copy?')))return copy(lastResult.route);});
click('clearChat',()=>{history=[];lastResult=null;$('conversation').replaceChildren();$('context').value='';$('question').value='';$('manualAnswer').value='';$('copyFallback').value='';$('copyAnswer').disabled=true;$('copyRoute').disabled=true;$('metrics').textContent='';status(tr('Sitzungsverlauf und Eingaben gelöscht.','Session history and inputs cleared.'));});
$('website').addEventListener('change',()=>{$('websiteCustom').hidden=$('website').value!=='custom';});
click('openWebsite',()=>{const u=new URL($('website').value==='custom'?$('websiteCustom').value:$('website').value);if(u.protocol!=='https:'||u.username||u.password)throw new Error(tr('Nur HTTPS-Websites ohne Zugangsdaten in der Adresse.','Only HTTPS websites with no credentials in the address.'));window.open(u.href,'_blank','noopener,noreferrer');});
click('copyPrompt',async()=>{await copy(`ForeverAI: ${tr('Antworte auf Deutsch.','Answer in English.')} Understand German and English WoW terms. Official WoW Forever, interface 16001. Do not invent map IDs or coordinates. Clearly distinguish verified current facts from uncertainty. No direct game access. Do not claim to place markers or move the character.\n\n${$('context').value}\n\n${questionValue()}`);status(tr('Prompt im Kopierfeld bereit. In deinen gewählten Webchat einfügen.','Prompt ready in the copy field. Paste into your chosen webchat.'));});
click('copyManual',async()=>{const j=await api('packet',{text:$('manualAnswer').value});await copy(j.packet);if(j.truncated)status(tr('Importkopie auf 6500 UTF-8-Bytes gekürzt.','Import copy truncated to 6500 UTF-8 bytes.'));});
function showCandidates(){$('candidates').textContent=shortlist.map((c,i)=>`${i+1}. ${c.provider} / ${c.model} / ${c.effort}`).join(' · ');}
click('addCandidate',()=>{const c=selected();if(!c.model)throw new Error(tr('Zuerst Modell auswählen.','Select a model first.'));if(shortlist.length>=4)throw new Error(tr('Höchstens vier Einstellungen pro Vergleich.','Maximum four configurations per comparison.'));if(!shortlist.some(x=>JSON.stringify(x)===JSON.stringify(c)))shortlist.push(c);showCandidates();});
click('clearCandidates',()=>{shortlist=[];showCandidates();});
const CASES=[
 {name:'DE · ID-Zuordnung',language:'de',context:'SYNTHETISCHE TESTDATEN, keine echten WoW-NPCs: T42 = Kriegerlehrer in Sturmwind. T17 = Magierlehrer in Sturmwind.',question:'Gib ausschließlich JSON mit dem Schlüssel answer zurück. Welcher Eintrag ist der Warrior Trainer in Stormwind? Antworte mit der ID.',expected:'T42'},
 {name:'EN · missing coordinates',language:'en',context:'Synthetic test fixture, not game data. No map IDs, coordinates or verified routes are provided.',question:'Give only JSON with the key answer. I want a waypoint to the dungeon entrance. If the data does not contain exact coordinates, answer must be NO_VERIFIED_COORDINATES. Never invent coordinates.',expected:'NO_VERIFIED_COORDINATES'},
 {name:'DE/EN · Mehrdeutigkeit',language:'de',context:'Synthetische Begriffszuordnung: DM kann in diesen Testdaten entweder Deadmines / Todesminen oder Dire Maul / Düsterbruch bedeuten. Keine weitere Auswahl ist gegeben.',question:'Gib nur JSON mit dem Schlüssel answer zurück. Nutzer: Bring mich zu DM. Ist eine eindeutige Zuordnung möglich? Falls nicht, answer = CLARIFY_DM.',expected:'CLARIFY_DM'}
];
function checkAnswer(text,expected){try{const x=JSON.parse(text.trim().replace(/^```(?:json)?\s*/,'').replace(/\s*```$/,''));return x.answer===expected&&Object.keys(x).length===1;}catch{return false;}}
function drawReport(){
  const area=$('benchmark');area.replaceChildren();const table=document.createElement('table');const header=document.createElement('tr');for(const t of [tr('Einstellung','Configuration'),tr('Datentreue','Fidelity'),tr('Erster Text','First text'),tr('Gesamt','Total')]){const th=document.createElement('th');th.textContent=t;header.append(th);}table.append(header);
  for(const r of report){const row=document.createElement('tr');for(const v of [`${r.provider} / ${r.model} / ${r.effort}\n${r.case}`,r.error?r.error:r.pass?'PASS':'FAIL',r.firstMs==null?'—':r.firstMs+' ms',r.totalMs==null?'—':r.totalMs+' ms']){const td=document.createElement('td');td.textContent=v;row.append(td);}table.append(row);}area.append(table);
  const groups=shortlist.map(c=>{const rows=report.filter(r=>r.provider===c.provider&&r.model===c.model&&r.effort===c.effort);return {...c,rows,mean:rows.reduce((a,r)=>a+(r.totalMs||0),0)/(rows.length||1)};}).filter(g=>g.rows.length===CASES.length&&g.rows.every(r=>r.pass&&!r.error)).sort((a,b)=>a.mean-b.mean);
  if(groups.length){const p=document.createElement('p');const g=groups[0];p.textContent=tr('Schnellste bestandene Einstellung in dieser kleinen Stichprobe: ','Fastest passing configuration in this small sample: ')+`${g.provider} / ${g.model} / ${g.effort} (${Math.round(g.mean)} ms). `+tr('Keine allgemeine Qualitätsempfehlung; wiederholen und Antworten fachlich prüfen.','Not a general quality recommendation; repeat and verify the content.');area.append(p);}
}
click('runBenchmark',async()=>{
  if(inBenchmark||!shortlist.length)throw new Error(tr('Zuerst Einstellungen hinzufügen; nur ein Vergleich gleichzeitig.','Add configurations first; one comparison at a time.'));
  if(!confirm(tr(`${shortlist.length*CASES.length} echte KI-Anfragen ausführen? Verbraucht Kontingent. Bei deaktiviertem Gratis-Modus können Kosten entstehen.`, `Run ${shortlist.length*CASES.length} real AI requests? Consumes quota. May incur charges if free mode is disabled.`)))return;
  inBenchmark=true;benchStop=false;report=[];$('runBenchmark').disabled=true;$('send').disabled=true;
  const tasks=shortlist.flatMap(c=>CASES.map(t=>({c,t})));
  for(let i=tasks.length-1;i>0;i--){const n=crypto.getRandomValues(new Uint32Array(1))[0]%(i+1);[tasks[i],tasks[n]]=[tasks[n],tasks[i]];}
  try{for(const {c,t} of tasks){if(benchStop)break;status(tr('Vergleich: ','Comparison: ')+c.model+' / '+t.name);const row={...c,case:t.name,date:new Date().toISOString()};
      try{const r=await streamChat({...c,question:t.question,context:t.context,history:[],language:t.language},()=>{});Object.assign(row,{firstMs:r.firstMs,totalMs:r.totalMs,text:r.text,pass:checkAnswer(r.text,t.expected)});}catch(e){row.error=e.message;row.pass=false;}
      report.push(row);drawReport();if(row.error){benchStop=true;status(tr('Vergleich beim ersten Anbieterfehler gestoppt. Keine automatische Ausweichanfrage.','Comparison stopped at the first provider error. No automatic fallback request.'),true);break;}
    }}finally{inBenchmark=false;$('runBenchmark').disabled=false;$('send').disabled=false;$('downloadBenchmark').disabled=!report.length;if(!benchStop)status(tr('Vergleich beendet. Nur diese Stichprobe ist gemessen.','Comparison complete. Only this sample was measured.'));}
});
click('stopBenchmark',async()=>{benchStop=true;await api('cancel',{});});
click('downloadBenchmark',()=>{const blob=new Blob([JSON.stringify({app:'ForeverAI 1.0.0-alpha',limitations:'Synthetic DE/EN data-fidelity sample, not WoW knowledge validation. No general optimality claim.',report},null,2)],{type:'application/json'});const u=URL.createObjectURL(blob),a=document.createElement('a');a.href=u;a.download='ForeverAI-KI-Vergleich.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);});
(async()=>{try{const launch=new URLSearchParams(location.hash.slice(1)).get('launch');if(launch){window.history.replaceState(null,'',location.pathname);await api('session',{launch});}state=await api('state');csrf=state.csrf;renderSync(state.sync);renderLive(state.live);for(const [id,p] of Object.entries(state.providers))option($('provider'),id,p.name);$('provider').value=state.settings.provider;$('maxTokens').value=String(state.settings.maxTokens);setLanguage(state.settings.language);status(tr('Bereit. KI-Zugang auswählen und anmelden oder einen Webchat manuell verwenden.','Ready. Choose AI access and sign in, or use a webchat manually.'));setInterval(async()=>{try{const s=await api('state');if(s.sync){state.sync=s.sync;renderSync(s.sync);}if(s.live){state.live=s.live;renderLive(s.live);}const changed=JSON.stringify(s.keys)!==JSON.stringify(state.keys)||JSON.stringify(s.accounts)!==JSON.stringify(state.accounts);if(changed){state=s;renderProvider();}}catch{}},5000);}catch(e){failure(new Error(tr('App über Start-Windows.cmd neu öffnen. ','Reopen the app using Start-Windows.cmd. ')+e.message));}})();
