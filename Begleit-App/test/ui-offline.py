"""Offline DOM tests only: browser network never used. Backend has separate HTTP tests."""
from pathlib import Path
import os
import subprocess,json,re
from playwright.sync_api import sync_playwright
b=Path(__file__).resolve().parent.parent
out=Path(os.environ.get('FG_UI_OUTPUT',str(b/'test-output')));out.mkdir(parents=True,exist_ok=True)
providers=json.loads(subprocess.check_output(['node','--input-type=module','-e',f"import {{PROVIDER_INFO}} from '{b}/lib/providers.mjs'; console.log(JSON.stringify(PROVIDER_INFO));"],text=True))
state={'settings':{'language':'de','provider':'openrouter','model':'','effort':'default','maxTokens':4096,'customBase':'','freeOnly':True,'freeTierConfirmed':{},'planConfirmed':False},'csrf':'MOCK-CSRF','providers':providers,'persistent':False,'accounts':[],'keys':{'openrouter':True},'activeAccount':None,'busy':False,'sync':{'enabled':False,'configured':False,'gamePath':'','lastSuccess':None,'lastError':None,'counts':None,'addonPath':'','busy':False},'live':{'enabled':False,'configured':False,'captureRunning':False,'addonPath':'','lastError':None,'count':0,'slots':120}}
mock="""
window.mockState=STATE;window.mockClip='';window.mockCalls=[];
Object.defineProperty(navigator,'clipboard',{value:{writeText:async t=>{window.mockClip=t;},readText:async()=>window.mockClip}});
window.fetch=async(url,options={})=>{
 window.mockCalls.push(url);const body=JSON.parse(options.body||'{}');const endpoint=url.split('/').pop();
 const models=[{id:'fixture/fast:free',name:'Fixture Fast (simuliert)',efforts:['default','low','medium','high'],free:true},{id:'fixture/simple:free',name:'Fixture Simple (simuliert)',efforts:['default'],free:true}];
 let result;
 if(endpoint==='state')result=window.mockState;
 else if(endpoint==='settings'){Object.assign(window.mockState.settings,body);result=window.mockState;}
 else if(url==='/api/live/config'){window.mockState.live={enabled:body.enabled,configured:true,addonPath:body.gamePath+'/Interface/AddOns/ForeverAI',captureRunning:body.enabled,lastError:null,count:0,slots:120,restartRequired:true};result=window.mockState.live;}
 else if(endpoint==='config'){window.mockState.sync={enabled:body.enabled,configured:true,gamePath:body.path,lastSuccess:Date.parse('2026-11-10T12:00:00Z'),lastError:null,busy:false,addonPath:body.path+'/Interface/AddOns/ForeverAI',counts:{dungeons:7,items:84,quests:21,rares:3}};result=window.mockState.sync;}
 else if(endpoint==='run'){result=window.mockState.sync;}
 else if(endpoint==='models')result={models};
 else if(endpoint==='catalog')result={packet:'FGC1;openrouter\\nM;fixture/fast:free;Fixture;default,low,medium,high\\nEND',count:1,total:2};
 else if(endpoint==='packet')result={packet:'FGA1;web;manual\\nT;'+encodeURIComponent(body.text)+'\\nEND'};
 else if(endpoint==='search')result={source:{name:'Forever Companion',url:'https://forevercompanion.io'},query:body.query,kind:'dungeon',updatedAt:'2026-11-09T06:00:00Z',note:'Approximate approach only',results:[{kind:'dungeon',name:'Shadowfang Keep',id:'shadowfang-keep',target:'shadowfang-keep',detail:'Lvl 18-30'}],packet:'FGS1;forevercompanion;2026-11-09T06:00:00Z;Schattenfang\\nR;D;shadowfang-keep;shadowfang-keep;Shadowfang%20Keep;Lvl%2018-30\\nEND'};
 else if(endpoint==='chat'){
 const text=body.question.includes('CLARIFY_DM')?'{"answer":"CLARIFY_DM"}':body.question.includes('NO_VERIFIED_COORDINATES')?'{"answer":"NO_VERIFIED_COORDINATES"}':body.context.includes('T42')?'{"answer":"T42"}':'Simulierte Testantwort. Keine echte KI-Anfrage.';
 return new Response(JSON.stringify({type:'delta',text})+'\\n'+JSON.stringify({type:'done',text,packet:'FGA1;openrouter;'+body.model+'\\nT;'+encodeURIComponent(text)+'\\nEND',provider:body.provider,model:body.model,effort:body.effort,firstMs:5,totalMs:20})+'\\n');
 }else throw Error('Unexpected mock endpoint '+endpoint);
 return new Response(JSON.stringify(result),{headers:{'Content-Type':'application/json'}});
};
""".replace('STATE',json.dumps(state))
checks=[]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path=os.environ.get('FG_CHROMIUM','/usr/bin/chromium'),headless=True,args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':1440,'height':1050});errors=[];page.on('pageerror',lambda e:errors.append(str(e)))
 html=(b/'public/index.html').read_text();html=re.sub(r'<link[^>]*>|<script[^>]*></script>','',html)
 page.set_content(html);page.add_style_tag(content=(b/'public/style.css').read_text());page.add_script_tag(content=mock);page.add_script_tag(content=(b/'public/app.js').read_text())
 page.wait_for_function("document.getElementById('status').textContent.startsWith('Bereit')")
 assert page.locator('#freeOnly').is_checked();checks.append('Default free mode checked')
 page.locator('#liveGamePath').fill('C:\\World of Warcraft\\_forever_')
 page.locator('#liveEnabled').check();page.locator('#liveConfigure').click()
 page.wait_for_function("document.getElementById('liveStatus').textContent.includes('Bildschirmbrücke läuft')")
 assert 'ForeverAI' in page.locator('#liveStatus').inner_text();checks.append('Opt-in live AI bridge configured through local UI without clipboard')
 assert page.evaluate("window.mockCalls.includes('/api/live/config')");checks.append('Live setup calls protected local API only')
 page.locator('#syncGamePath').fill('C:\\World of Warcraft\\_forever_')
 page.locator('#syncConfig').click();page.wait_for_function("document.getElementById('syncStatus').textContent.includes('84 Items')")
 assert 'ForeverAI' in page.locator('#syncStatus').inner_text();checks.append('Automatic game data sync configured without clipboard')
 page.locator('#syncNow').click();page.wait_for_function("!document.getElementById('syncNow').disabled");checks.append('Manual refresh is a separate optional control')
 page.locator('#loadModels').click();page.wait_for_function("document.getElementById('model').options.length===2")
 assert page.locator('#effort option').count()==4;checks.append('Mock catalog and reasoning selections render')
 page.locator('#question').fill('Welche Dungeons kann ich mit Level 22 machen?');page.locator('#send').click();page.wait_for_function("!document.getElementById('copyAnswer').disabled")
 assert 'Simulierte Testantwort' in page.locator('#conversation').inner_text();checks.append('Mock streamed answer renders as text')
 page.locator('#copyAnswer').click();assert page.evaluate('window.mockClip').startswith('FGA1;openrouter;');checks.append('Answer export invokes clipboard with data packet')
 page.locator('#copyCatalog').click();page.wait_for_function("window.mockClip.startsWith('FGC1;')");assert page.evaluate('window.mockClip').startswith('FGC1;');checks.append('Catalog export invokes clipboard with data packet')
 page.locator('#manualAnswer').fill('Manuell kopierte Webantwort.');page.locator('#copyManual').click();page.wait_for_function("window.mockClip.startsWith('FGA1;web;manual')");assert page.evaluate('window.mockClip').startswith('FGA1;web;manual');checks.append('Manual reply conversion handler')
 page.locator('#onlineQuery').fill('Schattenfang');page.locator('#onlineKind').select_option('dungeon');page.locator('#onlineSearch').click();page.wait_for_function("!document.getElementById('onlineCopy').disabled")
 assert 'Shadowfang Keep' in page.locator('#onlineResults').inner_text();assert 'Forever Companion' in page.locator('#onlineMeta').inner_text();checks.append('Offline online-source lookup renders named hits and attribution')
 page.locator('#onlineCopy').click();page.wait_for_function("window.mockClip.startsWith('FGS1;forevercompanion;')");checks.append('Lookup result packet reaches clipboard without executing external content')
 page.locator('#addCandidate').click();page.on('dialog',lambda d:d.accept());page.locator('#runBenchmark').click();page.wait_for_function("!document.getElementById('downloadBenchmark').disabled")
 assert page.locator('#benchmark').inner_text().count('PASS')==3;checks.append('Three-case benchmark renders mock results (not performance evidence)')
 page.screenshot(path=str(out/'ui-de.png'),full_page=True)
 page.locator('#language').select_option('en');page.wait_for_function("document.documentElement.lang==='en'")
 assert 'Capture bridge running' in page.locator('#liveStatus').inner_text();checks.append('English live bridge labels update in place')
 assert page.locator('h1').inner_text()=='Your game guide. Your choice of AI.';checks.append('Language switches to English')
 page.locator('#provider').select_option('anthropic');page.wait_for_function("document.getElementById('costNote').textContent.includes('Blocked in free mode')")
 assert not page.locator('#keyRow').is_hidden();assert page.locator('#oauthRow').is_hidden();checks.append('Paid Anthropic API distinct from free webchat')
 page.locator('#provider').select_option('chatgpt');page.wait_for_function("document.getElementById('login').textContent==='Continue with ChatGPT'")
 assert page.locator('#keyRow').is_hidden();checks.append('ChatGPT prompts sign-in rather than pasting browser token')
 page.screenshot(path=str(out/'ui-en.png'),full_page=True)
 page.set_viewport_size({'width':650,'height':1000});page.screenshot(path=str(out/'ui-narrow.png'),full_page=True)
 assert page.evaluate('document.documentElement.scrollWidth <= window.innerWidth');checks.append('Narrow viewport no horizontal overflow')
 assert not errors,errors;checks.append('No uncaught frontend JavaScript errors in this offline fixture')
 browser.close()
log='OFFLINE DOM ONLY. Browser network, clipboard and provider replies replaced by mocks.\n'+'\n'.join('PASS '+x for x in checks)+f'\n{len(checks)} offline UI checks passed. No real API performance measured.\n'
(out/'ui-tests.log').write_text(log);print(log)
