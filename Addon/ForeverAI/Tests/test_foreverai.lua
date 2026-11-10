-- Standalone unit/integration tests with simulated WoW APIs; NOT an in-game test.
local root = arg[1] or "../ForeverAI"
local total=0
local function test(name,fn)
    -- Tests should not mistake the normal 120-message chat ring buffer for missing replies.
    local fg=_G.FOREVERAI_TEST_FG
    if fg and fg.messages and #fg.messages>85 then fg:ClearChat() end
    local ok,err=pcall(fn)
    if not ok then io.stderr:write("FAIL "..name..": "..tostring(err).."\n"); os.exit(1) end
    total=total+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.0001,tostring(a).." !~= "..tostring(b)) end

local frames={}
local methods={}
local function widget(name)
    local o=setmetatable({scripts={},shown=true,text="",height=20,width=20,offset=0,enabled=true},{__index=methods})
    if name then _G[name]=o end
    return o
end
for _,n in ipairs({"SetPoint","SetAllPoints","SetAlpha","SetFrameStrata","SetClampedToScreen","EnableMouse","SetMovable","RegisterForDrag","StartMoving","StopMovingOrSizing","SetBackdrop","SetBackdropColor","SetBackdropBorderColor","SetJustifyH","SetJustifyV","SetFontObject","SetFading","SetMaxLines","SetSpacing","EnableMouseWheel","ScrollUp","ScrollDown","SetAutoFocus","SetMaxLetters","ClearFocus","SetMultiLine","SetTextInsets","SetCursorPosition","SetFocus","HighlightText","SetThickness","SetColorTexture","SetScale","RegisterForClicks","SetParent","ScrollToBottom"}) do
    methods[n]=function() end
end
function methods:SetPoint(...)
    self.point={...}
    local a,b,c,x,y=...
    if type(b)=="number" then self.px=b; self.py=c else self.px=x or 0; self.py=y or 0 end
end
function methods:ClearAllPoints() self.point=nil end
function methods:GetCenter() return self.px or 500,self.py or 400 end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:StartMoving() self.moving=true end
function methods:StopMovingOrSizing() self.moving=false end
function methods:Clear() self.lastMessage=nil; self.rendered={} end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetHeight() return self.height end
function methods:GetWidth() return self.width end
function methods:SetScript(k,fn) self.scripts[k]=fn end
function methods:RegisterEvent(e) self.events=self.events or {}; self.events[e]=true end
function methods:CreateFontString(...) return widget() end
function methods:GetFontString() self.font=self.font or widget();return self.font end
function methods:SetWordWrap(value) self.wordWrap=value end
function methods:CreateLine(...) return widget() end
function methods:CreateTexture(...) return widget() end
function methods:SetText(t) self.text=tostring(t or ""); if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self,false) end end
function methods:GetText() return self.text end
function methods:Show() local changed=not self.shown; self.shown=true; if changed and self.scripts.OnShow then self.scripts.OnShow(self) end end
function methods:Hide() local changed=self.shown; self.shown=false; if changed and self.scripts.OnHide then self.scripts.OnHide(self) end end
function methods:IsShown() return self.shown end
function methods:Enable() self.enabled=true end
function methods:Disable() self.enabled=false end
function methods:AddMessage(t) self.lastMessage=t; self.rendered=self.rendered or {}; self.rendered[#self.rendered+1]=t end
function methods:SetScrollChild(o) self.child=o end
function methods:GetVerticalScroll() return self.offset end
function methods:SetVerticalScroll(v) self.offset=v end
function methods:SetStartPoint(anchor,parent,x,y) assert(type(parent)=="table"); assert(type(x)=="number"); self.start={x,y} end
function methods:SetEndPoint(anchor,parent,x,y) assert(type(parent)=="table"); assert(type(x)=="number"); self.finish={x,y} end
function CreateFrame(_,name,...) local o=widget(name); frames[#frames+1]=o; return o end
UIParent=widget(); UIParent:SetSize(1000,800); BackdropTemplateMixin={}; ChatFontNormal={}; GameFontHighlight={}
UISpecialFrames={}; SlashCmdList={}; DEFAULT_CHAT_FRAME=widget()
local function event(name,...)
    for _,f in ipairs(frames) do if f.events and f.events[name] and f.scripts.OnEvent then f.scripts.OnEvent(f,name,...) end end
end
local state={locale="deDE",mapID=1,x=.5,y=.5,facing=0,combat=false,instance=false,taxi=false,pin=nil,rejectPin=false}
function CreateVector2D(x,y) return {x=x,y=y,GetXY=function(self) return self.x,self.y end} end
function issecretvalue(v) return type(v)=="table" and v.secret==true end
function GetLocale() return state.locale end
function GetBuildInfo() return "1.60.1","70862","Nov 10 2026",16001 end
function GetPlayerFacing() return state.facing end
function InCombatLockdown() return state.combat end
function IsInInstance() return state.instance end
function UnitOnTaxi() return state.taxi end
function UnitClass() return "Krieger","WARRIOR" end
function UnitLevel() return 25 end
function UnitFactionGroup() return "Alliance" end
C_Map={}
function C_Map.GetMapInfo(id) if (id>=1 and id<=3) or ({[1429]=true,[1436]=true,[1421]=true,[1413]=true,[1426]=true,[1453]=true,[1454]=true,[1455]=true})[id] then return {mapID=id,name="Testkarte "..id} end end
function C_Map.GetBestMapForUnit() return state.mapID end
function C_Map.GetPlayerMapPosition(id) if id==state.mapID then return CreateVector2D(state.x,state.y) end end
function C_Map.GetMapWorldSize(id) return 1000,800 end
function C_Map.GetWorldPosFromMapPos(id,p)
    if not C_Map.GetMapInfo(id) then return end
    local offset=id==2 and 1000 or 0
    return id==3 and 2 or 0,CreateVector2D(10000-p.y*800,20000-offset-p.x*1000)
end
function C_Map.CanSetUserWaypointOnMap() return not state.rejectPin end
function C_Map.GetUserWaypoint() return state.pin end
function C_Map.SetUserWaypoint(p)
    if state.rejectPin then return false end
    state.pin={uiMapID=p.uiMapID,position={x=p.position.x,y=p.position.y}}
    event("USER_WAYPOINT_UPDATED")
    return true
end
function C_Map.ClearUserWaypoint() state.pin=nil; event("USER_WAYPOINT_UPDATED") end
function C_Map.OpenWorldMap(id) state.openMap=id end
C_QuestLog={}
function C_QuestLog.GetNumQuestLogEntries() return 3,2 end
function C_QuestLog.GetInfo(i)
    if i==1 then return {isHeader=true,title="Gebiet"} end
    if i==2 then return {isHeader=false,title="Eine Testquest",questID=100} end
    if i==3 then return {isHeader=false,title="Andere Aufgabe",questID=101} end
end
function C_QuestLog.AddQuestWatch(id) state.watched=id end
function C_QuestLog.GetNextWaypoint(id) if id==100 then return 1,.6,.5 end end
C_SuperTrack={SetSuperTrackedQuestID=function(id) state.quest=id end}

local FG={}
for _,file in ipairs({"Locale.lua","Logic.lua","Preferences.lua","Chat.lua","LiveBridge.lua","Terms.lua","Navigation.lua","Guidance.lua","Bridge.lua","UI.lua","Loot.lua","Equipment.lua","Locations.lua","QuestieEvidence.lua","Knowledge.lua","SyncData.lua","OfflineSync.lua","Guide.lua","Main.lua"}) do
    local fn,err=loadfile(root.."/"..file); assert(fn,err); fn("ForeverAI",FG)
end

_G.FOREVERAI_TEST_FG=FG
ForeverGuideDB={places={ ["alte route"]={mapID=1,x=.2,y=.4,label="Alte Route"} },ui={launcher={x=.67,y=.44}},language="auto"}
test("addon initialization and legacy saved data migration",function()
    event("ADDON_LOADED","ForeverAI"); event("PLAYER_LOGIN")
    assert(FG.db); assert(FG.window); assert(not FG.lastError)
    assert(FG.db.places["alte route"] and FG.db.places["alte route"].x==.2)
    assert(ForeverAIDB==FG.db and ForeverGuideDB==nil)
end)
test("only ForeverAI slash commands registered",function()
    eq(SLASH_FOREVERAI1,"/fai"); eq(SLASH_FOREVERAI2,"/foreverai")
    assert(SlashCmdList.FOREVERAI)
    assert(SLASH_FOREVERGUIDE1==nil and SLASH_FOREVERGUIDE2==nil and SlashCmdList.FOREVERGUIDE==nil)
end)
test("German normalization",function() eq(FG.Normalize("  Wo ist der KRIEGERLEHRER? ÄÖÜ ß "),"wo ist der kriegerlehrer aeoeue ss") end)
test("safe finite numbers",function() assert(not FG.IsNumber(0/0)); assert(not FG.IsNumber(math.huge)); assert(not FG.IsNumber({secret=true})); assert(FG.IsNumber(0)) end)
test("percentage point with decimal commas",function() local p=assert(FG.ParsePoint("1 50,5 20,25 Heimat")); near(p.x,.505); near(p.y,.2025) end)
test("zero and full map coordinates allowed",function() local p=assert(FG.ParsePoint("1 0 100 Rand")); eq(p.x,0); eq(p.y,1) end)
test("invalid map ID rejected",function() assert(not FG.ValidatePoint({mapID=1.5,x=.5,y=.5})) end)
test("oversized coordinates rejected",function() assert(not FG.ParsePoint("1 120 50 Fehler")); assert(not FG.ParsePoint("1 -1 50 Fehler")) end)
test("non-numeric coordinates rejected",function() assert(not FG.ParsePoint("1 NaN 50 Fehler")); assert(not FG.ParsePoint("1 1e999 20 Fehler")) end)
test("UTF-8 truncation stays intact",function() eq(FG.Clean("ÄÖÜ",3),"Ä") end)
test("plain text import",function() local r=assert(FG.ParseImport("FG1;Weg\nP;1;50;60;Punkt\nEND")); eq(#r.points,1); near(r.points[1].y,.6) end)
test("fenced CRLF import",function() assert(FG.ParseImport("```text\r\nFG1;Weg\r\nP;1;50;60;Punkt\r\nEND\r\n```")) end)
test("Lua injection rejected as data",function() assert(not FG.ParseImport("FG1;Weg\n/run print('bad')\nEND")); assert(not FG.ParseImport("return {mapID=1}")) end)
test("post-END content rejected",function() assert(not FG.ParseImport("FG1;Weg\nP;1;50;60;Punkt\nEND\nP;1;50;70;Noch")) end)
test("incomplete and empty imports rejected",function() assert(not FG.ParseImport("FG1;Weg\nEND")); assert(not FG.ParseImport("FG1;Weg\nP;1;50;60;Punkt")) end)
test("import size bound",function() assert(not FG.ParseImport(string.rep("x",FG.MAX_IMPORT+1))) end)
test("import point-count bound",function() local s={"FG1;Weg"}; for i=1,101 do s[#s+1]="P;1;50;60;Punkt" end; s[#s+1]="END"; assert(not FG.ParseImport(table.concat(s,"\n"))) end)
test("route serialization round-trip",function() local a={name="Prüfung",points={{mapID=1,x=.123456,y=.765432,label="Nord"}}}; local b=assert(FG.ParseImport(FG.SerializeRoute(a))); near(a.points[1].x,b.points[1].x); eq(b.name,a.name) end)
test("unknown map ID rejected before starting",function() assert(not FG:StartNavigation({name="falsch",points={{mapID=999,x=.5,y=.5}}})) end)
test("direction north while facing north",function() local x,y=FG.RelativeVector(0,10,0); near(x,0); near(y,1) end)
test("direction east while facing north",function() local x,y=FG.RelativeVector(10,0,0); near(x,1); near(y,0) end)
test("direction north while facing west",function() local x,y=FG.RelativeVector(0,10,math.pi/2); near(x,1); near(y,0) end)
test("direction west while facing west",function() local x,y=FG.RelativeVector(-10,0,math.pi/2); near(x,0); near(y,1) end)
test("same map world geometry",function() local g=assert(FG:Geometry({mapID=1,x=.6,y=.4})); near(g.east,100); near(g.north,80); near(g.distance,math.sqrt(16400)) end)
test("cross-zone geometry on same continent",function() local g=assert(FG:Geometry({mapID=2,x=.1,y=.5})); near(g.east,600); near(g.north,0) end)
test("different continent has no invented direction",function() assert(not FG:Geometry({mapID=3,x=.1,y=.5})) end)
test("same-map fallback without world conversion",function() local f=C_Map.GetWorldPosFromMapPos; C_Map.GetWorldPosFromMapPos=nil; local g=assert(FG:Geometry({mapID=1,x=.6,y=.4})); near(g.east,100); C_Map.GetWorldPosFromMapPos=f end)
test("navigation creates marker and arrow",function() assert(FG:StartNavigation({name="Test",points={{mapID=1,x=.6,y=.5,label="Ost"}}})); FG:Tick(); assert(state.pin); assert(FG.arrow:IsShown()); eq(#FG.arrow.lines,3) end)
test("final proximity automatically completes guidance",function() state.x=.6; FG:Tick(); assert(not FG.nav); assert(not state.pin); assert(not FG.arrow:IsShown()); state.x=.5 end)
test("previous user marker restored",function() state.pin={uiMapID=1,position={x=.1,y=.1}}; FG:StartNavigation({name="T",points={{mapID=1,x=.6,y=.5}}}); FG:StopNavigation(true); near(state.pin.position.x,.1); state.pin=nil end)
test("external marker not overwritten on stop",function() FG:TestNavigation(); C_Map.SetUserWaypoint({uiMapID=1,position={x=.9,y=.9}}); assert(FG.nav.pinBlocked); FG:StopNavigation(true); near(state.pin.position.x,.9); state.pin=nil end)
test("route advances one step at a time",function() FG:StartNavigation({name="R",points={{mapID=1,x=.5,y=.5,label="Hier"},{mapID=1,x=.7,y=.5,label="Dort"}}}); FG:Tick(); eq(FG.nav.index,2); near(state.pin.position.x,.7); FG:StopNavigation(true) end)
test("combat pauses progression",function() FG:TestNavigation(); state.combat=true; FG:Tick(); assert(FG.nav); eq(FG.arrow.distance.text,"Im Kampf pausiert"); assert(not FG:StartNavigation({name="R",points={{mapID=1,x=.6,y=.5}}})); state.combat=false; FG:StopNavigation(true) end)
test("deferred marker restoration after combat",function() FG:TestNavigation(); state.combat=true; FG:StopNavigation(true); assert(FG.pendingRestore); state.combat=false; FG:Tick(); assert(not state.pin); assert(not FG.pendingRestore) end)
test("instance and taxi pause",function() FG:TestNavigation(); state.instance=true; FG:Tick(); eq(FG.arrow.distance.text,"In Instanzen pausiert"); state.instance=false; state.taxi=true; FG:Tick(); eq(FG.arrow.distance.text,"Während des Fluges pausiert"); state.taxi=false; FG:StopNavigation(true) end)
test("unavailable marker does not crash arrow",function() state.rejectPin=true; FG:TestNavigation(); assert(FG.nav); FG:Tick(); assert(not state.pin); state.rejectPin=false; FG:StopNavigation(true) end)
test("saved place and German query",function() FG:SavePlace("Kriegerlehrer Sturmwind"); assert(FG:StartSaved("Wo ist der Kriegerlehrer?",false)); FG:StopNavigation(true) end)
test("duplicate saved name does not overwrite",function() state.x=.8; FG:SavePlace("Kriegerlehrer Sturmwind"); near(FG.db.places["kriegerlehrer sturmwind"].x,.5); state.x=.5 end)
test("manual route recording and playback",function() FG:BeginRecording("Testroute"); state.x=.6; FG:RecordPoint("Abzweigung"); FG:SaveRecording(); eq(#FG.db.routes.testroute.points,2); assert(FG:StartSaved("Testroute",true)); FG:StopNavigation(true); state.x=.5 end)
test("quest log excludes headers",function() eq(#FG:GetQuests(),2) end)
test("quest receives current native waypoint",function() assert(FG:FindQuest("Eine Testquest")); assert(FG.nav); eq(FG.nav.questID,100); near(FG.nav.points[1].x,.6); FG:StopNavigation(true) end)
test("quest without position produces no marker",function() assert(FG:FindQuest("101")); assert(not FG.nav); assert(not state.pin) end)
test("export contains context without authentication",function() local text=FG:BuildContext("Wo muss ich hin?"); assert(text:find("70862",1,true)); assert(text:find("16001",1,true)); assert(text:find("Meine Frage: Wo muss ich hin?",1,true)); assert(not text:find("access_token",1,true)) end)
test("import UI validates and enables Start",function() FG:ShowTransfer("import","FG1;Importtest\nP;1;60;50;Punkt\nEND"); assert(not FG.transfer.start.enabled); FG.transfer.check.scripts.OnClick(); assert(FG.transfer.start.enabled); FG.transfer.start.scripts.OnClick(); assert(FG.nav); FG:StopNavigation(true) end)
test("editing import invalidates validation",function() FG:ShowTransfer("import","FG1;I\nP;1;60;50;P\nEND"); FG.transfer.check.scripts.OnClick(); FG.transfer.edit.scripts.OnTextChanged(FG.transfer.edit,true); assert(not FG.transfer.checked); assert(not FG.transfer.start.enabled) end)
test("diagnostic window works",function() FG:Ask("diagnose"); assert(FG.transfer.edit:GetText():find("70862",1,true)); assert(not FG.lastError) end)
test("weapon question uses curated knowledge without inventing map pins",function() FG:StopNavigation(true); FG:Ask("Wo bekomme ich die beste Kriegerwaffe für Level 25?"); assert(not FG.nav); assert(FG.messages[#FG.messages]:find("examples, not calculated",1,true) or FG.messages[#FG.messages]:find("Beispiele, kein berechnetes",1,true)) end)
test("all slash actions run without hidden exception",function() for _,s in ipairs({"hilfe","wo","liste","quests","export Testfrage","import","test","karte","weiter","stopp","aufnahme Weitere Route","punkt Punkt 2","speichern","route Weitere Route","sichern Kopie","routenexport","stopp","entfernen Kopie"}) do SlashCmdList.FOREVERAI(s) end; assert(not FG.lastError,FG.lastError) end)

-- Bilingual regression tests. All positions and quests below remain simulated fixtures.
test("default locale follows the German client",function() eq(FG.locale,"deDE"); eq(FG.db.language,"auto") end)
test("English aliases find an existing German saved place",function()
    assert(FG:StartSaved("Where is the Warrior Trainer in Stormwind?",false)); eq(FG.nav.name,"Kriegerlehrer Sturmwind"); FG:StopNavigation(true)
end)
test("mixed German English query finds the same place",function()
    assert(FG:StartSaved("Wo ist der Warrior Trainer in Sturmwind?",false)); eq(FG.nav.name,"Kriegerlehrer Sturmwind"); FG:StopNavigation(true)
end)
test("German query finds an English saved place",function()
    FG:SavePlace("Alchemy Trainer Ironforge")
    assert(FG:StartSaved("Wo ist der Alchemielehrer in Eisenschmiede?",false)); eq(FG.nav.name,"Alchemy Trainer Ironforge"); FG:StopNavigation(true)
end)
test("German lowercase umlauts and transliterations match",function()
    eq(FG.Canonical("Kräuterkundelehrer"),FG.Canonical("HERBALISM TRAINER"))
    eq(FG.Canonical("KRAEUTERKUNDELEHRER"),FG.Canonical("Herbalism Trainer"))
    eq(FG.Canonical("Kürschnerei"),FG.Canonical("Skinning"))
end)
test("word boundaries prevent partial-name matches",function()
    assert(not FG.Matches("Warrior","Warriorville")); assert(not FG.Matches("Stormwind","Newstormwind"))
end)
test("numeric level constraints are not discarded",function()
    assert(not FG.Matches("Warrior Level 25","Krieger Stufe 35"))
    assert(FG.Matches("Warrior Level 25","Krieger Stufe 25"))
end)
test("unrelated item question does not navigate to a trainer",function()
    assert(not FG.Matches("best Warrior items Level 25","Kriegerlehrer Sturmwind"))
end)
test("empty and stopword-only queries never match everything",function()
    assert(not FG.Matches("","Stormwind")); assert(not FG.Matches("Where is the","Stormwind"))
end)
test("location order is preserved for mixed-language routes",function()
    assert(FG.Matches("Route von Stormwind zu den Todesminen","Sturmwind – Todesminen"))
    assert(FG.Matches("How do I get from Stormwind to the Deadmines?","Sturmwind – Todesminen"))
    assert(not FG.Matches("From the Deadmines to Stormwind","Sturmwind – Todesminen"))
end)
test("mixed route command selects saved route without new coordinates",function()
    FG.db.routes[FG.Normalize("Sturmwind – Todesminen")]={name="Sturmwind – Todesminen",points={{mapID=1,x=.6,y=.5,label="Synthetic fixture only"},{mapID=1,x=.7,y=.5,label="Not real game data"}}}
    FG:Ask("route von Stormwind zu den Todesminen")
    assert(FG.nav); eq(FG.nav.name,"Sturmwind – Todesminen"); FG:StopNavigation(true)
    FG.db.routes[FG.Normalize("Sturmwind – Todesminen")]=nil
end)
test("ambiguous DM does not silently choose a destination",function()
    assert(FG:StartSaved("DM",false)); assert(not FG.nav)
    assert(FG.messages[#FG.messages]:find("mehrdeutig",1,true))
end)
test("multiple bilingual matches are presented instead of guessed",function()
    FG:SavePlace("Warrior Trainer Ironforge")
    assert(FG:StartSaved("Wo ist der Kriegerlehrer?",false)); assert(not FG.nav)
end)
test("exact deletion does not remove a different translated label",function()
    FG:Ask("remove Warrior Trainer Stormwind"); assert(FG.db.places["kriegerlehrer sturmwind"])
end)
test("German and English term lookup are both available",function()
    FG:Ask("begriff Schmiedekunst"); assert(FG.messages[#FG.messages-1]:find("Blacksmithing",1,true))
    FG:Ask("term Stormwind"); assert(FG.messages[#FG.messages-1]:find("Sturmwind",1,true))
end)
test("unknown term produces no invented translation",function()
    FG:Ask("term Imaginarynewquest"); assert(FG.messages[#FG.messages]:find("Kein passender",1,true))
end)
test("unknown quest translation requires a title or explicit alias",function()
    assert(not FG:FindQuest("An English Test Quest",true)); assert(not FG.nav)
end)
test("quest IDs work independently of language",function()
    assert(FG:FindQuest("100")); eq(FG.nav.name,"Eine Testquest"); FG:StopNavigation(true)
end)
test("explicit English quest alias resolves by stable quest ID",function()
    FG:Ask("alias quest 100 An English Test Quest")
    assert(FG:FindQuest("An English Test Quest")); eq(FG.nav.questID,100); eq(FG.nav.name,"Eine Testquest"); FG:StopNavigation(true)
end)
test("original German quest title remains usable after alias",function()
    assert(FG:FindQuest("Eine Testquest")); FG:StopNavigation(true)
end)
test("quest alias cannot invent a quest outside the current log",function()
    assert(FG:AddQuestAlias("quest 999 Fictional Quest Alias"))
    assert(not FG:FindQuest("Fictional Quest Alias",true)); assert(not FG.nav)
end)
test("invalid alias formats are rejected",function()
    assert(not FG:AddQuestAlias("quest 0 Invalid")); assert(not FG:AddQuestAlias("item 100 Invalid")); assert(not FG:AddQuestAlias("quest 100"))
end)
test("duplicate and excessive aliases are rejected",function()
    assert(not FG:AddQuestAlias("quest 100 An English Test Quest"))
    for i=1,10 do assert(FG:AddQuestAlias("quest 998 Alias "..i)) end
    assert(not FG:AddQuestAlias("quest 998 One too many"))
end)
test("language selection persists in the character database",function()
    FG:Ask("sprache en"); eq(FG.db.language,"enUS"); eq(FG.locale,"enUS"); FG:InitLanguage(); eq(FG.locale,"enUS")
end)
test("all bound widgets update to English",function()
    for _,entry in ipairs(FG.localeWidgets) do
        if entry.key~="Navigation" and entry.key~="Import / Export" and entry.key~="DE / EN" and entry.key~="Live-KI: AUS" then
            eq(entry.widget.text,FG.Translations[entry.key] or entry.key)
        end
    end
end)
test("English error messages and help are selected",function()
    local _,err=FG.ParsePoint("bad input"); assert(err:find("Format: target",1,true))
    FG:Help(); assert(FG.messages[#FG.messages]:find("dungeon",1,true))
end)
test("English UI still accepts German queries",function()
    assert(FG:StartSaved("Wo ist der Kriegerlehrer in Sturmwind?",false)); FG:StopNavigation(true)
end)
test("English context requests English and includes bilingual terms",function()
    local text=FG:BuildContext("How do I get to the Todesminen?")
    assert(text:find("Please answer in English",1,true)); assert(text:find("Todesminen / Deadmines",1,true))
    assert(text:find("Addon language: enUS",1,true)); assert(not text:find("Bitte antworte auf Deutsch",1,true))
end)
test("English diagnostics contain locale and build information",function()
    local text=FG:Diagnostic(); assert(text:find("ForeverAI diagnostics",1,true)); assert(text:find("70862",1,true)); assert(text:find("Client language: deDE",1,true))
end)
test("English position question is not treated as an unknown query",function()
    FG:Ask("Where am I?"); assert(FG.messages[#FG.messages]:find("Map ID 1",1,true))
end)
test("all English slash actions execute without hidden exceptions",function()
    for _,cmd in ipairs({"help","where","list","quests","export Test question","import","test","map","next","stop","record English route","point Second point","save","route English route","keep English copy","routeexport","stop","remove English copy","diagnostic"}) do SlashCmdList.FOREVERAI(cmd) end
    assert(not FG.lastError,FG.lastError)
end)
test("active pin status changes language immediately",function()
    FG:TestNavigation(); FG:Tick(); assert(FG.arrow.step.text:find("Map pin placed",1,true))
    FG:SetLanguage("de"); assert(FG.arrow.step.text:find("Kartenmarker gesetzt",1,true)); FG:StopNavigation(true)
end)
test("language switch preserves an unfinished route recording",function()
    FG:BeginRecording("Nicht verlieren"); local original=FG.recording
    FG:SetLanguage("en"); eq(FG.recording,original); eq(FG.recording.name,"Nicht verlieren")
    FG.recording=nil
end)
test("language switch preserves text and invalidates import validation",function()
    local text="FG1;Keep my text\nP;1;60;50;Point\nEND"
    FG:ShowTransfer("import",text); FG.transfer.check.scripts.OnClick(); assert(FG.transfer.checked)
    FG:SetLanguage("de"); eq(FG.transfer.edit:GetText(),text); assert(not FG.transfer.checked); assert(not FG.transfer.start.enabled)
    eq(FG.transfer.title.text,"Antwort, Modellliste oder Route importieren")
    FG:SetLanguage("en"); eq(FG.transfer.title.text,"Import an answer, model list or route"); eq(FG.transfer.edit:GetText(),text)
end)
test("FG1 serialization stays language-neutral",function()
    local route={name="Nicht übersetzen",points={{mapID=1,x=.2,y=.4,label="Kriegerlehrer"}}}
    local english=FG.SerializeRoute(route); FG:SetLanguage("de"); local german=FG.SerializeRoute(route)
    eq(english,german); assert(FG.ParseImport(german))
end)
test("German context requests German after switching back",function()
    local text=FG:BuildContext("Wo ist der Warrior Trainer?")
    assert(text:find("Bitte antworte auf Deutsch",1,true)); assert(text:find("Krieger / Warrior",1,true))
end)
test("English client auto-detection",function()
    state.locale="enUS"; FG:SetLanguage("auto"); eq(FG.locale,"enUS"); eq(FG.db.language,"auto")
end)
test("British English client also uses English",function()
    state.locale="enGB"; FG:InitLanguage(); eq(FG.locale,"enUS")
end)
test("unsupported client locale safely falls back to English",function()
    state.locale="frFR"; FG:InitLanguage(); eq(FG.locale,"enUS")
end)
test("explicit German choice overrides an English client",function()
    state.locale="enUS"; FG:SetLanguage("deutsch"); eq(FG.locale,"deDE")
end)
test("missing GetLocale safely falls back to English",function()
    local old=GetLocale; GetLocale=nil; FG:SetLanguage("auto"); eq(FG.locale,"enUS"); GetLocale=old
end)
test("invalid language does not overwrite the saved choice",function()
    FG:SetLanguage("en"); assert(not FG:SetLanguage("not-a-language")); eq(FG.db.language,"enUS")
end)
test("language selector cycles auto German English auto",function()
    state.locale="deDE"; FG:SetLanguage("auto")
    FG.languageButton.scripts.OnClick(); eq(FG.db.language,"deDE")
    FG.languageButton.scripts.OnClick(); eq(FG.db.language,"enUS")
    FG.languageButton.scripts.OnClick(); eq(FG.db.language,"auto"); eq(FG.locale,"deDE")
end)
test("legacy saved places and routes retain keys and coordinates",function()
    local places,routes=FG.db.places,FG.db.routes
    local oldPlace=places["kriegerlehrer sturmwind"]
    FG.db.schema=1; FG.db.language=nil
    event("ADDON_LOADED","ForeverAI")
    eq(FG.db.schema,4); eq(FG.db.language,"auto"); eq(FG.db.places,places); eq(FG.db.routes,routes)
    near(FG.db.places["kriegerlehrer sturmwind"].x,oldPlace.x); eq(FG.db.places["kriegerlehrer sturmwind"].label,oldPlace.label)
    assert(FG.db.routes.testroute); assert(FG.db.questAliases[100])
end)
test("invalid saved quest aliases are sanitized on initialization",function()
    FG.db.questAliases.bad="bad"; FG.db.questAliases[200]={false,"Good",55,"", "Other"}
    event("ADDON_LOADED","ForeverAI")
    assert(not FG.db.questAliases.bad); eq(#FG.db.questAliases[200],2)
end)
test("invalid saved language falls back to client locale",function()
    FG.db.language="xxXX"; event("ADDON_LOADED","ForeverAI"); eq(FG.db.language,"auto"); eq(FG.locale,"deDE")
end)
test("dictionary contains no coordinates or executable payloads",function()
    for _,term in ipairs(FG.Terms) do assert(not term.mapID and not term.x and not term.y and not term.code) end
end)
test("no unexpected exception after bilingual actions",function() assert(not FG.lastError,FG.lastError) end)
-- One independent round-trip test per curated base term, plus all its explicit aliases.
for _,term in ipairs(FG.Terms) do
    test("dictionary round-trip: "..term.id,function()
        eq(FG.Canonical(term.de),FG.Canonical(term.en))
        assert(FG.Matches(term.de,term.en)); assert(FG.Matches(term.en,term.de))
        for _,alias in ipairs(term.aliases or {}) do eq(FG.Canonical(alias),FG.Canonical(term.en)) end
        for _,alias in ipairs(term.trainers or {}) do eq(FG.Canonical(alias),FG.Canonical(term.en.." Trainer")) end
    end)
end

-- 0.3: movable launcher, private chat, honest AI preferences, and opt-in guidance.
local function resetNavigation()
    state.combat=false; state.instance=false; state.taxi=false; state.mapID=1; state.x=.5; state.y=.5; state.facing=0; state.rejectPin=false
    FG:StopNavigation(true); FG:Tick(); FG.destination=nil; state.pin=nil
    FG.db.navigation.worldMarker=false; FG:SetLanguage("de"); FG:RefreshDestination()
end
local function simpleRoute()
    return {name="Test destination",points={{mapID=1,x=.7,y=.5,label="Test destination"}}}
end

test("launcher exists independently of the chat window",function() FG.window:Hide(); assert(FG.launcher:IsShown()) end)
test("launcher left click opens and closes chat",function() FG.launcher.scripts.OnClick(FG.launcher,"LeftButton"); assert(FG.window:IsShown()); FG.launcher.scripts.OnClick(FG.launcher,"LeftButton"); assert(not FG.window:IsShown()) end)
test("launcher drag stores normalized screen position",function() local b=FG.launcher; FG.db.ui.buttonLocked=false; b.scripts.OnMouseDown(b); b.scripts.OnDragStart(b); assert(b.moving); b.px=800; b.py=320; b.scripts.OnDragStop(b); near(FG.db.ui.launcher.x,.8); near(FG.db.ui.launcher.y,.4); assert(not b.moving) end)
test("ending drag does not accidentally open chat",function() FG.window:Hide(); FG.launcher.scripts.OnClick(FG.launcher,"LeftButton"); assert(not FG.window:IsShown()) end)
test("right click locks and unlocks launcher position",function() local b=FG.launcher; b.scripts.OnClick(b,"RightButton"); assert(FG.db.ui.buttonLocked); b.scripts.OnDragStart(b); assert(not b.moving); b.scripts.OnClick(b,"RightButton"); assert(not FG.db.ui.buttonLocked) end)
test("hidden launcher can be recovered by command",function() FG:LauncherCommand("hide"); assert(not FG.launcher:IsShown()); FG:Ask("button show"); assert(FG.launcher:IsShown()) end)
test("saved widget position accounts for different effective scales",function() local b=FG.launcher; b.scale=2; b.px=200; b.py=100; FG:SaveWidgetPosition(b,"launcher"); near(FG.db.ui.launcher.x,.4); b.scale=1 end)
test("invalid saved positions and credential-like preferences are discarded",function() FG.db.ui.launcher={x=math.huge,y=.5}; FG.db.ai={model="invented",effort="ultra",access_token="TEST-ONLY"}; FG:InitPreferences(); assert(not FG.db.ui.launcher); eq(FG.db.ai.model,"auto"); eq(FG.db.ai.effort,"low"); assert(not FG.db.ai.access_token) end)
test("UI reset also repositions HUD and shows launcher",function() FG.db.ui.arrow={x=.1,y=.1}; FG:LauncherCommand("hide"); FG:ResetUIPositions(); assert(FG.launcher:IsShown()); assert(not FG.db.ui.arrow); assert(not FG.db.ui.window) end)
test("chat submission records distinct user and local roles",function() FG:ClearChat(); FG:SubmitChat("wo"); eq(FG.messageRoles[1],"user"); eq(FG.messageRoles[2],"local"); assert(FG.chat.rendered[1]:find("Du:",1,true)) end)
test("chat user text removes display-link injection",function() FG:ClearChat(); FG:SubmitChat("|Hbad|hFrage|h |Tfake|t"); assert(not FG.messages[1]:find("|",1,true)); eq(FG.messages[1],"Frage") end)
test("empty chat input is ignored",function() local n=#FG.messages; assert(not FG:SubmitChat("  ")); eq(#FG.messages,n) end)
test("chat accepts commands copied with slash prefix",function() FG:ClearChat(); FG:SubmitChat("/fai wo"); eq(FG.messages[1],"wo"); assert(not FG.lastError,FG.lastError) end)
test("input history restores an unfinished draft",function() FG:ClearChat(); FG:SubmitChat("position"); FG:SubmitChat("help"); FG.input:SetText("unfinished"); FG:ChatHistory("UP"); eq(FG.input:GetText(),"help"); FG:ChatHistory("UP"); eq(FG.input:GetText(),"position"); FG:ChatHistory("DOWN"); FG:ChatHistory("DOWN"); eq(FG.input:GetText(),"unfinished") end)
test("session chat history has bounded size",function() FG:ClearChat(); for i=1,140 do FG:AddChatMessage("user","line "..i) end; eq(#FG.messages,120); eq(#FG.messageRoles,120); assert(not FG.db.messages) end)
test("clearing chat removes transcript and input history",function() FG:ClearChat(); eq(#FG.messages,0); eq(#FG.inputHistory,0) end)
test("model preferences persist and accept only known model IDs",function() assert(FG:SelectModel("gpt-6-luna",true)); assert(FG:SelectEffort("none",true)); FG:InitPreferences(); eq(FG.db.ai.model,"gpt-6-luna"); eq(FG.db.ai.effort,"none"); assert(not FG:SelectModel("not-real",true)) end)
test("changing model resets an unsupported reasoning effort",function() FG:SelectModel("gpt-6.1-sol",true); eq(FG.db.ai.effort,"low"); assert(not FG:SelectEffort("none",true)) end)
test("German reasoning aliases are recognized",function() assert(FG:SelectEffort("mittel",true)); eq(FG.db.ai.effort,"medium"); assert(FG:SelectEffort("sehr hoch",true)); eq(FG.db.ai.effort,"xhigh") end)
test("model dropdown selects a saved preference",function() FG.modelButton.scripts.OnClick(); assert(FG.optionMenu:IsShown()); FG.optionMenu.rows[2].scripts.OnClick(); eq(FG.db.ai.model,"gpt-6-luna"); assert(not FG.optionMenu:IsShown()) end)
test("reasoning dropdown uses the selected model's allowed levels",function() FG.effortButton.scripts.OnClick(); eq(#FG:FindModel(FG.db.ai.model).efforts,7); FG.optionMenu.rows[2].scripts.OnClick(); eq(FG.db.ai.effort,"none") end)
test("AI selection does not claim a live connection or control browser model",function() local s=FG:AISettingsText(); assert(s:find("nicht aktiv",1,true)); assert(s:find("kein Modell",1,true) or s:find("nicht um",1,true)) end)
test("benchmark plan reports no measured AI results",function() local s=FG:BenchmarkPlan(); assert(s:find("noch nicht durchgeführt",1,true)); assert(s:find("keine gemessenen",1,true)) end)
test("context export includes explicit inactive model preference",function() local s=FG:BuildContext("trainer"); assert(s:find("model=gpt-6-luna",1,true)); assert(s:find("nicht aktiv",1,true)) end)
test("English UI relabels chat and model controls",function() FG:SetLanguage("en"); eq(FG.sendButton.text,"Send"); assert(FG.effortButton.text:find("No reasoning",1,true)); FG:ClearChat(); FG:SubmitChat("position"); assert(FG.chat.rendered[1]:find("You:",1,true)); FG:SetLanguage("de") end)

test("natural-language trainer search starts the matching saved destination",function() resetNavigation(); FG:SubmitChat("Where is the Warrior Trainer in Stormwind?"); assert(FG.nav); eq(FG.nav.name,"Kriegerlehrer Sturmwind"); FG:StopNavigation(true) end)
test("preview uses target category and warns about straight-line direction",function() FG:OfferNavigation({name="Kriegerlehrer",kind="trainer",points={{mapID=1,x=.7,y=.5}}}); eq(FG.DestinationKind(FG.destination),"trainer"); assert(FG.destinationDetails.text:find("kein berechneter",1,true)) end)
test("clicking Start guidance activates the selected destination",function() FG.guideButton.scripts.OnClick(); assert(FG.nav); assert(not FG.destination); assert(FG.arrow:IsShown()); FG:StopNavigation(true) end)
test("closing chat leaves guidance overlay visible",function() FG:StartNavigation(simpleRoute()); FG.window:Hide(); assert(FG.arrow:IsShown()); FG:StopNavigation(true) end)
test("unknown search clears an old preview instead of reusing it",function() FG:OfferNavigation(simpleRoute()); FG:SubmitChat("A question with no local destination 999999"); assert(not FG.destination); assert(not FG.guideButton.enabled) end)
test("ambiguous local search does not silently choose a result",function() FG:SubmitChat("Wo ist der Kriegerlehrer?"); assert(not FG.destination); assert(not FG.nav) end)
test("quest preview leaves native tracking untouched",function() state.quest=88; FG:SubmitChat("quest 100"); assert(FG.destination.questID==100); assert(not FG.nav); eq(state.quest,88) end)
test("quest coordinates are refreshed when accepting the preview",function() local old=C_QuestLog.GetNextWaypoint; C_QuestLog.GetNextWaypoint=function() return 1,.75,.5 end; FG:StartDestination(); near(FG.nav.points[1].x,.75); C_QuestLog.GetNextWaypoint=old; FG:StopNavigation(true) end)
test("stale quest preview cannot activate nonexistent coordinates",function() FG:OfferNavigation({name="quest",questID=100,points={{mapID=1,x=.6,y=.5}}}); local old=C_QuestLog.GetNextWaypoint; C_QuestLog.GetNextWaypoint=function() end; assert(not FG:StartDestination()); assert(not FG.nav); assert(not FG.destination); C_QuestLog.GetNextWaypoint=old end)
test("existing map pin can be selected as a destination",function() state.pin={uiMapID=1,position={x=.8,y=.5}}; FG:Ask("navi pin"); assert(FG.destination); near(FG.destination.points[1].x,.8); FG.destination=nil; state.pin=nil end)
test("map-pin selection is harmless when no pin exists",function() FG:Ask("navi pin"); assert(not FG.destination) end)
test("target map can be opened from preview before activation",function() FG:OfferNavigation({name="another map",points={{mapID=2,x=.2,y=.4}}}); FG:OpenTargetMap(); eq(state.openMap,2); FG.destination=nil end)
test("guidance panel stores its own position",function() FG:StartNavigation(simpleRoute()); FG.arrow.px=650; FG.arrow.py=440; FG.arrow.scripts.OnDragStop(FG.arrow); near(FG.db.ui.arrow.x,.65); near(FG.db.ui.arrow.y,.55); FG:StopNavigation(true) end)
test("manual pause prevents auto-advancing a nearby waypoint",function() FG:StartNavigation({name="r",points={{mapID=1,x=.5,y=.5},{mapID=1,x=.7,y=.5}}}); FG:PauseNavigation(true); FG:Tick(); eq(FG.nav.index,1); eq(FG.arrow.distance.text,"Wegführung pausiert."); FG:PauseNavigation(false); eq(FG.nav.index,2); FG:StopNavigation(true) end)
test("arriving at the final point closes the guidance",function() FG:StartNavigation(simpleRoute()); state.x=.7; FG:Tick(); assert(not FG.nav); assert(not FG.arrow:IsShown()); state.x=.5 end)
test("transport checkpoint requires manual confirmation",function() FG:StartNavigation({name="r",points={{mapID=1,x=.5,y=.5,kind="travel"},{mapID=1,x=.7,y=.5}}}); FG:Tick(); eq(FG.nav.index,1); assert(FG.nav.nearManual); eq(FG.arrow.nextButton.text,"Bestätigen"); FG:Advance(1); eq(FG.nav.index,2); FG:StopNavigation(true) end)
test("explicit confirmation checkpoint is not auto-skipped",function() FG:StartNavigation({name="r",points={{mapID=1,x=.5,y=.5,confirm=true},{mapID=1,x=.7,y=.5}}}); FG:Tick(); eq(FG.nav.index,1); FG:StopNavigation(true) end)
test("same coordinates on another map do not imply arrival",function() local old=FG.Geometry; FG.Geometry=function() return {east=0,north=0,distance=0} end; FG:StartNavigation({name="r",points={{mapID=2,x=.5,y=.5},{mapID=1,x=.7,y=.5}}}); FG:Tick(); eq(FG.nav.index,1); FG.Geometry=old; FG:StopNavigation(true) end)
test("direction instructions are character-relative",function() eq(FG.DirectionHint(0,1),"Zielrichtung vor dir"); eq(FG.DirectionHint(1,0),"Zur Zielrichtung nach rechts drehen"); eq(FG.DirectionHint(-1,0),"Zur Zielrichtung nach links drehen"); eq(FG.DirectionHint(0,-1),"Zielrichtung hinter dir") end)
test("moving-away warning does not claim automatic rerouting",function() FG:StartNavigation(simpleRoute()); FG:Tick(); state.x=.4; FG:Tick(); assert(FG.arrow.instruction.text:find("Umweg",1,true)); state.x=.5; FG:StopNavigation(true) end)
test("unreadable facing hides all arrow lines",function() FG:StartNavigation(simpleRoute()); local old=GetPlayerFacing; GetPlayerFacing=function() return {secret=true} end; FG:Tick(); for _,line in ipairs(FG.arrow.lines) do assert(not line:IsShown()) end; GetPlayerFacing=old; FG:StopNavigation(true) end)
test("another continent shows no invented direction",function() FG:StartNavigation({name="far",points={{mapID=3,x=.2,y=.2}}}); FG:Tick(); assert(FG.arrow.distance.text:find("Anderer Kontinent",1,true)); for _,line in ipairs(FG.arrow.lines) do assert(not line:IsShown()) end; FG:StopNavigation(true) end)
test("bilingual navigation commands pause and resume",function() FG:StartNavigation(simpleRoute()); FG:Ask("wegführung pause"); assert(FG.nav.paused); FG:Ask("guide resume"); assert(not FG.nav.paused); FG:Ask("navigation stop"); assert(not FG.nav) end)
test("recorded point hint survives save and playback",function() FG:BeginRecording("Hint test"); FG:RecordPoint("Door"); FG:NotePoint("Durch das Tor / through the gate"); FG:SaveRecording(); FG:StartSaved("Hint test",true); FG:Advance(1); FG:Tick(); assert(FG.arrow.note.text:find("through the gate",1,true)); FG:StopNavigation(true) end)
test("FG2 exports hints and confirmation fields round trip",function() local r={name="rich",points={{mapID=1,x=.4,y=.5,label="Gate",kind="dungeon",note="Go through the gate",confirm=true}}}; local text=FG.SerializeRoute(r); assert(text:find("FG2;",1,true)==1); local got=assert(FG.ParseImport(text)); eq(got.points[1].kind,"dungeon"); eq(got.points[1].note,"Go through the gate"); assert(got.points[1].confirm) end)
test("FG1 still exports simple coordinate-only routes",function() assert(FG.SerializeRoute(simpleRoute()):find("FG1;",1,true)==1) end)
test("FG2 rejects malformed point types and booleans",function() assert(not FG.ParseImport("FG2;x\nP;1;50;50;X;invented;;0\nEND")); assert(not FG.ParseImport("FG2;x\nP;1;50;50;X;quest;;true\nEND")) end)
test("FG2 text is sanitized and never executed",function() local r=assert(FG.ParseImport("FG2;x\nP;1;50;50;X;waypoint;|cffff0000/run bad|r;1\nEND")); assert(not r.points[1].note:find("|",1,true)); assert(r.points[1].confirm) end)
test("unknown format version is rejected",function() assert(not FG.ParseImport("FG3;x\nP;1;50;50;X\nEND")) end)
test("FG2 route hint survives persistence validation",function() FG.db.routes.rich={name="Rich",points={{mapID=1,x=.4,y=.5,label="Gate",kind="travel",note="Board manually",confirm=true}}}; event("ADDON_LOADED","ForeverAI"); eq(FG.db.routes.rich.points[1].note,"Board manually"); assert(FG.db.routes.rich.points[1].confirm) end)
test("quest log events refresh the active client waypoint",function() FG:FindQuest("100"); local old=C_QuestLog.GetNextWaypoint; C_QuestLog.GetNextWaypoint=function() return 1,.8,.5 end; event("QUEST_LOG_UPDATE"); FG:Tick(); near(FG.nav.points[1].x,.8); near(state.pin.position.x,.8); C_QuestLog.GetNextWaypoint=old; FG:StopNavigation(true) end)
test("missing quest coordinates remove the stale marker and hide arrow",function() FG:FindQuest("100"); local old=C_QuestLog.GetNextWaypoint; C_QuestLog.GetNextWaypoint=function() end; event("QUEST_LOG_UPDATE"); FG:Tick(); assert(FG.nav.questMissing); assert(not state.pin); for _,line in ipairs(FG.arrow.lines) do assert(not line:IsShown()) end; C_QuestLog.GetNextWaypoint=old; event("QUEST_LOG_UPDATE"); FG:Tick(); assert(not FG.nav.questMissing); assert(FG.nav.pinBlocked); FG:StopNavigation(true) end)
test("quest search without coordinates leaves a different active route alone",function() FG:StartNavigation(simpleRoute()); local current=FG.nav; FG:FindQuest("101",false,true); eq(FG.nav,current); FG:StopNavigation(true) end)
test("HUD relabels on live language change",function() FG:StartNavigation(simpleRoute()); FG:SetLanguage("en"); FG:Tick(); assert(FG.arrow.mode.text:find("Target direction only",1,true)); eq(FG.arrow.pause.text,"Pause"); FG:PauseNavigation(true); eq(FG.arrow.pause.text,"Resume"); FG:SetLanguage("de"); eq(FG.arrow.pause.text,"Fortsetzen"); FG:StopNavigation(true) end)
test("missing native marker API preserves the fallback HUD",function() FG.db.navigation.worldMarker=true; FG:StartNavigation(simpleRoute()); FG:Tick(); assert(FG.arrow:IsShown()); assert(not FG.nav.nativeOwned); FG:StopNavigation(true); FG.db.navigation.worldMarker=false end)

-- Native tracking fixture. These are mocked functions, NOT a real client test.
state.track="none"
C_SuperTrack.IsSuperTrackingUserWaypoint=function() return state.track=="user" end
C_SuperTrack.IsSuperTrackingQuest=function() return state.track=="quest" end
C_SuperTrack.IsSuperTrackingAnything=function() return state.track~="none" end
C_SuperTrack.GetSuperTrackedQuestID=function() return state.quest end
C_SuperTrack.SetSuperTrackedUserWaypoint=function(on) state.track=on and "user" or "none"; event("SUPER_TRACKING_CHANGED") end
C_SuperTrack.SetSuperTrackedQuestID=function(id) state.quest=id; state.track="quest"; event("SUPER_TRACKING_CHANGED") end
local function nativeReset()
    resetNavigation(); state.track="none"; state.quest=nil; FG.db.navigation.worldMarker=true
end

test("native marker is opt-in and requested when supported",function() nativeReset(); FG:StartNavigation(simpleRoute()); assert(FG.nav.nativeOwned); eq(state.track,"user"); FG:StopNavigation(true); eq(state.track,"none") end)
test("previous quest tracking is restored on stop",function() nativeReset(); state.track="quest"; state.quest=88; FG:StartNavigation(simpleRoute()); eq(state.track,"user"); FG:StopNavigation(true); eq(state.track,"quest"); eq(state.quest,88) end)
test("previous user waypoint and tracking are restored together",function() nativeReset(); state.pin={uiMapID=1,position={x=.2,y=.3}}; state.track="user"; FG:StartNavigation(simpleRoute()); FG:StopNavigation(true); near(state.pin.position.x,.2); eq(state.track,"user") end)
test("external native tracking change takes precedence",function() nativeReset(); FG:StartNavigation(simpleRoute()); C_SuperTrack.SetSuperTrackedQuestID(99); assert(FG.nav.nativeBlocked); FG:StopNavigation(true); eq(state.track,"quest"); eq(state.quest,99) end)
test("unknown native tracking types are never overridden",function() nativeReset(); state.track="corpse"; FG:StartNavigation(simpleRoute()); assert(not FG.nav.nativeOwned); eq(state.track,"corpse"); FG:StopNavigation(true); eq(state.track,"corpse") end)
test("external pin is not overwritten during native restoration",function() nativeReset(); FG:StartNavigation(simpleRoute()); C_Map.SetUserWaypoint({uiMapID=1,position={x=.9,y=.9}}); FG:StopNavigation(true); near(state.pin.position.x,.9) end)
test("native marker can be disabled while guidance keeps running",function() nativeReset(); FG:StartNavigation(simpleRoute()); FG:ToggleWorldMarker(); assert(FG.nav); assert(not FG.db.navigation.worldMarker); eq(state.track,"none"); FG:StopNavigation(true) end)
test("disabling native marker with a prior user pin is reversible",function() nativeReset(); state.track="user"; state.pin={uiMapID=1,position={x=.2,y=.3}}; FG:StartNavigation(simpleRoute()); FG:ToggleWorldMarker(); eq(state.track,"none"); FG:StopNavigation(true); eq(state.track,"user"); near(state.pin.position.x,.2) end)
test("native restoration is deferred during combat",function() nativeReset(); state.track="quest"; state.quest=77; FG:StartNavigation(simpleRoute()); state.combat=true; FG:StopNavigation(true); eq(state.track,"user"); state.combat=false; FG:Tick(); eq(state.track,"quest"); eq(state.quest,77) end)
test("deferred restore respects an externally replaced pin",function() nativeReset(); FG:StartNavigation(simpleRoute()); state.combat=true; FG:StopNavigation(true); state.pin={uiMapID=1,position={x=.9,y=.8}}; state.track="quest"; state.quest=99; state.combat=false; FG:Tick(); eq(state.quest,99); near(state.pin.position.x,.9) end)
test("native marker preference survives initialization",function() nativeReset(); FG:InitPreferences(); assert(FG.db.navigation.worldMarker); FG.db.navigation.worldMarker=false end)
test("logout saves widget locations and stops navigation cleanly",function() resetNavigation(); FG:StartNavigation(simpleRoute()); event("PLAYER_LOGOUT"); assert(not FG.nav); assert(FG.ValidPosition(FG.db.ui.launcher)); assert(FG.ValidPosition(FG.db.ui.window)); assert(FG.ValidPosition(FG.db.ui.arrow)) end)
test("no hidden exception after chat and guidance regression suite",function() assert(not FG.lastError,FG.lastError) end)


-- 0.4 manual reply/catalog bridge. Synthetic data only, never a real game destination.
local packet="FGA1;openrouter;example/model:free\nT;Hallo%20Krieger%21%0AZweite%20Zeile%20%C3%A4%20%25\nEND"
local catalog="FGC1;openrouter\nM;example/fast:free;Schnell%20%2F%20Fast;default,low,medium\nM;example/simple:free;Einfach%20%2F%20Simple;default\nEND"
test("reply parser decodes UTF-8, newlines and percent",function() local r=assert(FG.ParseReply(packet));eq(r.provider,"openrouter");assert(r.text:find("ä %",1,true));assert(r.text:find("\n",1,true)) end)
test("reply parser strips game hyperlinks and textures",function() local r=assert(FG.ParseReply("FGA1;web;manual\nT;%7CHbad%7ChLINK%7Ch%20%7CTbad%7Ct\nEND"));eq(FG.Trim(r.text),"LINK");assert(not r.text:find("|",1,true)) end)
test("reply parser rejects broken percent escape",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%G0\nEND")) end)
test("reply parser rejects truncated percent escape",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%A\nEND")) end)
test("reply parser rejects NUL control",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%00\nEND")) end)
test("reply parser rejects invalid UTF-8 overlong sequence",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%C0%AF\nEND")) end)
test("reply parser rejects UTF-8 surrogate",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%ED%A0%80\nEND")) end)
test("reply parser rejects Unicode outside range",function() assert(not FG.ParseReply("FGA1;web;manual\nT;%F4%90%80%80\nEND")) end)
test("reply parser accepts emoji UTF-8 as text",function() assert(FG.ParseReply("FGA1;web;manual\nT;%F0%9F%98%80\nEND")) end)
test("reply parser rejects missing END",function() assert(not FG.ParseReply("FGA1;web;manual\nT;hello")) end)
test("reply parser rejects trailing executable text",function() assert(not FG.ParseReply(packet.."\n/run malicious()")) end)
test("reply parser rejects unknown provider",function() assert(not FG.ParseReply("FGA1;evil;manual\nT;hello\nEND")) end)
test("reply parser rejects oversized packet",function() assert(not FG.ParseReply(string.rep("a",FG.MAX_IMPORT+1))) end)
test("reply parser rejects oversized decoded text",function() assert(not FG.ParseReply("FGA1;web;manual\nT;"..string.rep("a",8001).."\nEND")) end)
test("reply parser accepts fenced data",function() assert(FG.ParseReply("```text\n"..packet.."\n```")) end)
test("imported answer is session-only and cannot start navigation",function() FG:StopNavigation(true);local r=assert(FG.ParseReply("FGA1;web;manual\nT;%2Ffai%20test%0A%2Frun%20malicious%28%29\nEND"));assert(FG:ApplyReply(r));assert(not FG.nav);assert(not FG.db.messages);eq(FG.messageRoles[#FG.messageRoles],"ai") end)
test("imported answer has unverified label",function() FG:SetLanguage("de");FG:ApplyReply(assert(FG.ParseReply(packet)));local line=FG:ChatLine(#FG.messages);assert(line:find("ungeprüft",1,true)) end)
test("reply UI validates before applying, without navigation",function() FG:ShowTransfer("import",packet);assert(not FG.transfer.start.enabled);FG.transfer.check.scripts.OnClick();eq(FG.transfer.start.text,"Übernehmen");FG.transfer.start.scripts.OnClick();assert(not FG.nav);eq(FG.messageRoles[#FG.messageRoles],"ai") end)
test("catalog parser accepts model IDs and known effort lists",function() local c=assert(FG.ParseCatalog(catalog));eq(#c.models,2);eq(c.models[1].efforts[2],"low") end)
test("catalog parser rejects duplicates",function() assert(not FG.ParseCatalog("FGC1;groq\nM;a;A;default\nM;a;A;default\nEND")) end)
test("catalog parser requires provider",function() assert(not FG.ParseCatalog("FGC1;evil\nM;a;A;default\nEND")) end)
test("catalog parser requires default level",function() assert(not FG.ParseCatalog("FGC1;groq\nM;a;A;high\nEND")) end)
test("catalog parser rejects unsupported effort",function() assert(not FG.ParseCatalog("FGC1;groq\nM;a;A;default,ultra\nEND")) end)
test("catalog parser rejects code-like ID",function() assert(not FG.ParseCatalog("FGC1;groq\nM;evil();A;default\nEND")) end)
test("catalog UI applies provider and real model options",function() FG:ShowTransfer("import",catalog);FG.transfer.check.scripts.OnClick();assert(FG.transfer.start.enabled);FG.transfer.start.scripts.OnClick();eq(FG.db.ai.provider,"openrouter");eq(#FG.ModelCandidates,2);eq(FG.db.ai.model,"example/fast:free") end)
test("catalog initialization preserves model choices without credentials",function() FG:SelectModel("example/simple:free",true);FG:InitPreferences();eq(FG.db.ai.model,"example/simple:free");eq(FG.db.ai.effort,"default");eq(FG.db.ai.provider,"openrouter");assert(not FG.db.ai.access_token) end)
test("model without reasoning uses default after switching",function() FG:SelectModel("example/fast:free",true);FG:SelectEffort("medium",true);FG:SelectModel("example/simple:free",true);eq(FG.db.ai.effort,"default") end)
test("context includes machine-readable preferences",function() local x=FG:BuildContext("Hello");assert(x:find("FGP1;openrouter;example/simple:free;default",1,true)) end)
test("English imported answer label is accurate",function() FG:SetLanguage("en");local r=assert(FG.ParseReply(packet));FG:ApplyReply(r);assert(FG:ChatLine(#FG.messages):find("imported, unverified",1,true));FG:SetLanguage("de") end)
test("invalid saved catalog resets safely",function() FG.db.catalog="loadstring('evil')";FG:InitPreferences();assert(not FG.db.catalog);eq(FG.db.ai.provider,"chatgpt");assert(FG:FindModel("auto")) end)
test("route import continues to require explicit start",function() FG:ShowTransfer("import","FG1;Route\nP;1;50;50;Test\nEND");FG.transfer.check.scripts.OnClick();assert(not FG.nav);eq(FG.transfer.start.text,"Navigation starten");FG.transfer.start.scripts.OnClick();assert(FG.nav);FG:StopNavigation(true) end)



-- Offline knowledge features: all outputs must be text only, no automatic marker or waypoint.
FG:ClearChat()
local function joinedFrom(index)
    local a={}
    for i=index,#FG.messages do a[#a+1]=FG.messages[i] end
    return table.concat(a,"\n")
end
test("German dungeons by explicit level 22",function()
    FG:SetLanguage("de")
    FG:StopNavigation(true)
    local n=#FG.messages+1
    FG:Ask("Welche Instanzen kann ich mit Level 22 machen?")
    local t=joinedFrom(n)
    assert(t:find("Todesminen",1,true) and t:find("Höhlen des Wehklagens",1,true),t)
    assert(not FG.nav)
end)
test("English dungeons by level 22",function()
    FG:SetLanguage("en")
    local n=#FG.messages+1
    FG:Ask("Which dungeons for level 22?")
    local t=joinedFrom(n)
    assert(t:find("Deadmines",1,true) and t:find("Wailing Caverns",1,true),t)
    assert(not FG.nav)
end)
test("named dungeon resolves German name in English UI",function()
    local n=#FG.messages+1
    FG:Ask("Where is der Eingang zu den Todesminen?")
    local t=joinedFrom(n)
    assert(t:find("Moonbrook",1,true),t)
    assert(t:find("No calculated walking route",1,true) or t:find("no calculated walking route",1,true),t)
    assert(not FG.nav)
end)
test("new Forever dungeon facts",function()
    local n=#FG.messages+1
    FG:Ask("Where is Hall of Thanes?")
    local t=joinedFrom(n)
    assert(t:find("13",1,true) and t:find("Ironforge",1,true),t)
    assert(not FG.nav)
end)
test("warrior level 25 weapons include sourced examples",function()
    local n=#FG.messages+1
    FG:Ask("Best warrior weapons level 25")
    local t=joinedFrom(n)
    assert(t:find("Cruel Barb",1,true) and t:find("Hamhock",1,true),t)
    assert(not FG.nav)
end)
test("class query explains warrior, not only export",function()
    local n=#FG.messages+1
    FG:Ask("Tell me about my class talents")
    local t=joinedFrom(n)
    assert(t:find("Warrior:",1,true),t)
end)
test("trainer query has no fabricated NPC pin",function()
    FG:StopNavigation(true)
    local n=#FG.messages+1
    FG:Ask("where is my class trainer?")
    local t=joinedFrom(n)
    assert(t:find("city guard",1,true),t)
    assert(not FG.nav)
end)
test("unknown question offers transfer instead of inventing answer",function()
    FG:StopNavigation(true)
    local n=#FG.messages+1
    FG:Ask("Welche unsichtbare Schmetterlingsfarbe steht hinter dem Baum?")
    local t=joinedFrom(n)
    assert(t:find("companion",1,true),t)
    assert(not FG.nav)
end)
test("unknown chat question stays in the chat",function()
    FG:StopNavigation(true)
    FG:SetMainView("chat")
    FG:SubmitChat("Can my character do twelve backflips in midair?")
    assert(not FG.transfer or not FG.transfer:IsShown())
    assert(FG.window.views.chat:IsShown())
    assert(not FG.nav)
end)
test("ambiguity never selects Dire Maul silently",function()
    FG:StopNavigation(true)
    local n=#FG.messages+1
    FG:Ask("Where is DM?")
    assert(joinedFrom(n):find("ambiguous",1,true))
    assert(not FG.nav)
end)


-- 0.6 regression: loot questions are answered as loot questions, even with typos.
test("user's misspelled German Shadowfang question returns real items",function()
    FG:SetLanguage("de")
    FG:StopNavigation(true)
    local n=#FG.messages+1
    assert(FG:SubmitChat("welche gegenstände für krieger gibt es im dungen schattenfang?"))
    local t=joinedFrom(n)
    assert(t:find("Schlächterbeil",1,true),t)
    assert(t:find("Gekrümmte Kriegsaxt",1,true),t)
    assert(t:find("Wappen des Kommandanten",1,true),t)
    assert(t:find("Kommandant Springvale",1,true),t)
    assert(not t:find("Krieger: Waffen (Arms)",1,true),t)
    assert(not FG.nav)
end)
test("dungeon name typo also resolves without an invented location",function()
    local n=#FG.messages+1
    FG:Ask("Welche Krieger-Items droppen in Schatenfang?")
    local t=joinedFrom(n)
    assert(t:find("Schlächterbeil",1,true),t)
    assert(not FG.nav)
end)
test("English Shadowfang loot gives named bosses and items",function()
    FG:SetLanguage("en")
    local n=#FG.messages+1
    FG:Ask("Which warrior items drop in Shadowfang Keep?")
    local t=joinedFrom(n)
    assert(t:find("Butcher's Cleaver",1,true),t)
    assert(t:find("Arced War Axe",1,true),t)
    assert(t:find("Commander Springvale",1,true),t)
    assert(not FG.nav)
end)
test("mixed-language Shadowfang shields do not mention weapons",function()
    FG:SetLanguage("de")
    local n=#FG.messages+1
    FG:Ask("Welche Schilde für Warrior droppt in sfk?")
    local t=joinedFrom(n)
    assert(t:find("Wappen des Kommandanten",1,true),t)
    assert(not t:find("Gekrümmte Kriegsaxt",1,true),t)
end)
test("Fury weapons in Shadowfang do not list armor",function()
    local n=#FG.messages+1
    FG:Ask("Fury warrior waffen in Shadowfang Keep")
    local t=joinedFrom(n)
    assert(t:find("Schlächterbeil",1,true),t)
    assert(not t:find("Phantom-Rüstung",1,true),t)
end)
test("named item source lookup works without explicitly naming dungeon",function()
    local n=#FG.messages+1
    FG:Ask("Wo bekomme ich die Spukklinge?")
    local t=joinedFrom(n)
    assert(t:find("Todeshöriger Captain",1,true),t)
    assert(t:find("Schattenfang",1,true),t)
end)
test("lower-level warriors see an equip requirement warning",function()
    local old=UnitLevel
    UnitLevel=function() return 19 end
    local n=#FG.messages+1
    FG:Ask("welche krieger gegenstände in schattenfang?")
    local t=joinedFrom(n)
    assert(t:find("noch nicht anlegen",1,true),t)
    UnitLevel=old
end)
test("specific mage request does not invent warrior recommendations",function()
    local n=#FG.messages+1
    FG:Ask("Magier items in shadowfang keep")
    local t=joinedFrom(n)
    assert(t:find("nur eine kuratierte Krieger-Auswahl",1,true),t)
    assert(not t:find("Schlächterbeil",1,true),t)
end)
test("loot query for dungeon without a curated table is transparent",function()
    local n=#FG.messages+1
    FG:Ask("Which warrior items drop in Gnomeregan?")
    local t=joinedFrom(n)
    assert(t:find("no verified",1,true) or t:find("keine geprüfte",1,true),t)
    assert(not FG.nav)
end)
test("Deadmines and Wailing Caverns local warrior loot is recognized",function()
    local n=#FG.messages+1
    FG:Ask("Krieger loot Todesminen")
    local t=joinedFrom(n)
    assert(t:find("Smite's Mighty Hammer",1,true),t)
    n=#FG.messages+1
    FG:Ask("Krieger loot Höhlen des Wehklagens")
    t=joinedFrom(n)
    assert(t:find("Kresh's Back",1,true),t)
end)
test("dungen typo alone still triggers dungeon level list",function()
    FG:ClearChat()
    local n=#FG.messages+1
    FG:Ask("welche dungen kann ich mit level 22 machen?")
    local t=joinedFrom(n)
    assert(t:find("Todesminen",1,true),t)
end)
test("asking only where Shadowfang is keeps normal location response",function()
    local n=#FG.messages+1
    FG:Ask("Wo ist schattenfang?")
    local t=joinedFrom(n)
    assert(t:find("Lohenscheit",1,true),t)
    assert(not t:find("Schlächterbeil",1,true),t)
end)
test("all curated warrior loot is available on request",function()
    local n=#FG.messages+1
    FG:Ask("alle krieger gegenstände burg schattenfang")
    local t=joinedFrom(n)
    assert(t:find("Szepter des Barons",1,true),t)
    assert(t:find("Schlächterschnitzler",1,true),t)
end)


-- Version 0.7 additions: clickable results, optional QuestieDB, read-only gear/bags.
test("community location catalog is explicit and contains only bounded points",function()
    eq(#FG.LocationPins,7)
    for _,loc in ipairs(FG.LocationPins) do
        assert(type(loc.url)=="string" and loc.url:find("https://",1,true)==1)
        assert(loc.x>=0 and loc.x<=100 and loc.y>=0 and loc.y<=100)
        assert(FG.KnownAreaMap[loc.mapID]==nil) -- area and UI map namespaces must not be confused
    end
end)
test("named dungeon search creates clickable results without auto-navigation",function()
    FG:StopNavigation(true); FG.destination=nil; FG:RefreshDestination()
    assert(FG:SearchLocationResults("Todesminen"))
    assert(FG.searchFrame and FG.searchFrame:IsShown())
    assert(FG.searchFrame.results[1].route.points[1].mapID==1436)
    assert(not FG.nav and not FG.destination)
    assert(not FG.searchFrame.start.enabled)
    FG.searchFrame.rows[1].scripts.OnClick()
    assert(FG.destination and FG.destination.kind=="dungeon")
    assert(not FG.nav)
    assert(FG.searchFrame.start.enabled)
    FG.searchFrame.start.scripts.OnClick()
    assert(FG.nav and FG.nav.points[1].mapID==1436)
    FG:StopNavigation(true)
end)
test("clicked dungeon guidance is labelled as approximate outdoor approach",function()
    FG:SearchLocationResults("Wo sind die Höhlen des Wehklagens?")
    local r=FG.searchFrame.results[1]
    assert(r.detail:find("Community",1,true) or r.detail:find("approach",1,true))
    assert(r.route.points[1].note:find("Portal",1,true))
    eq(#r.route.points,1)
end)
test("unknown place never gets fabricated coordinates",function()
    FG.destination=nil; FG:StopNavigation(true)
    assert(not FG:SearchLocationResults("Wo ist der Magier Theodisius Witzbold?"))
    assert(not FG.destination and not FG.nav)
end)
test("gear query creates selectable item results leading only to dungeon approach",function()
    local n=#FG.messages+1
    FG:Ask("Wo finde ich ein besseres Schwert für meinen Krieger mit Level 25?")
    local t=joinedFrom(n)
    assert(t:find("Cruel Barb",1,true),t)
    local hits=FG.searchFrame.results
    local found=false
    for i,r in ipairs(hits) do
        if r.name:find("Cruel Barb",1,true) then
            found=true
            assert(r.detail:find("van Cleef",1,true) or r.detail:find("VanCleef",1,true))
            assert(r.route.points[1].mapID==1436)
            assert(#r.route.points==1)
            assert(r.detail:find("Annäherung",1,true))
        end
    end
    assert(found)
end)
test("named item asks also expose the corresponding dungeon approach",function()
    FG:Ask("Wo bekomme ich Cruel Barb?")
    local matches=FG.searchFrame.results
    assert(matches[1].name:find("Cruel Barb",1,true))
    assert(matches[1].route.points[1].mapID==1436)
end)
test("quest with client waypoint is clickable and still revalidated on start",function()
    FG:SubmitChat("quest Testquest")
    assert(FG.searchFrame.results and FG.searchFrame.results[1].source=="WoW Client")
    assert(FG.destination and FG.destination.questID==100)
    FG.searchFrame.rows[1].scripts.OnClick()
    assert(FG:StartDestination())
    assert(FG.nav.questID==100)
    FG:StopNavigation(true)
end)
test("saved place yields clickable search result in the existing chat",function()
    FG.db.places["neuer testpunkt"]={label="Neuer Testpunkt",mapID=1,x=.55,y=.66}
    FG:Ask("Wo ist Neuer Testpunkt?")
    assert(FG.searchFrame.results and FG.searchFrame.results[1].source=="SavedVariables")
    FG.db.places["neuer testpunkt"]=nil
end)
test("optional QuestieDB returns trainer positions without inventing walk paths",function()
    _G.LibQuestieDB={ModeIndicator={GetStatus=function() return {expansion="Forever"} end},
        Npc={GetAllIds=function() return {9,10} end,
        name=function(id) return id==9 and "Ranne Yoru" or "Old Scribe" end,
        subName=function(id) return id==9 and "Warrior Trainer" or "Bookseller" end,
        spawns=function(id) return id==9 and {[1519]={{51.5,61.25}}} or {[1519]={{9,9}}} end}}
    local results=FG:QuestieNpcResults("Kriegerlehrer Sturmwind",10)
    assert(#results==1,tostring(#results))
    assert(results[1].name:find("Ranne",1,true))
    assert(results[1].route.points[1].mapID==1453)
    assert(results[1].route.points[1].x==.515)
    local shown=FG:SearchLocationResults("Kriegerlehrer Sturmwind")
    assert(shown and FG.searchFrame.results[1].route.kind=="trainer")
    _G.LibQuestieDB=nil
end)
test("QuestieDB in wrong flavor is ignored",function()
    _G.LibQuestieDB={ModeIndicator={GetStatus=function() return {expansion="Wrath"} end},Npc={}}
    local r,why=FG:QuestieNpcResults("Kriegerlehrer")
    eq(#r,0);eq(why,"wrong_flavor")
    _G.LibQuestieDB=nil
end)
test("read equipped item properties safely",function()
    GetInventoryItemLink=function(_,slot) if slot==16 then return "|cffffffff|Hitem:5001|h[Testschwert]|h|r" end end
    C_Item={GetItemInfo=function()
        return "Testschwert","|Hitem:5001|h[Testschwert]|h",2,24,21,"Weapon","Sword",1,"INVTYPE_WEAPON","texture",1,2
    end,GetItemStats=function() return {ITEM_MOD_STRENGTH_SHORT=5,ITEM_MOD_STAMINA_SHORT=3} end}
    local item=FG:ReadEquipmentSlot(16)
    assert(item and item.id==5001 and item.itemLevel==24 and item.minLevel==21)
    local output=FG:EquipmentText()
    assert(output:find("Testschwert",1,true));assert(output:find("Stärke +5",1,true))
    assert(FG:BuildContext("mein besseres Schwert"):find("Testschwert",1,true))
end)
test("bag inspection is opt-in and excluded from unrelated exports",function()
    C_Container={GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end,
        GetContainerItemLink=function(bag,slot)
            if bag==0 and slot==1 then return "|Hitem:5002|h[Taschen-Schild]|h" end
        end}
    local b=FG:BagItems()
    assert(#b==1 and b[1].id==5002)
    assert(FG:BuildContext("neue Waffe"):find("Taschenübersicht",1,true)==nil)
    assert(FG:BuildContext("mein Inventar für Krieger"):find("Taschenübersicht",1,true))
    local n=#FG.messages+1
    FG:Ask("taschen")
    assert(joinedFrom(n):find("Tasche 0/1",1,true))
end)
test("combat pauses equipment and bag readout",function()
    state.combat=true
    assert(#FG:EquipmentRows()==0)
    assert(#FG:BagItems()==0)
    state.combat=false
end)


-- 0.8: free online data lookup import (transport is manual clipboard; not HTTP in addon).
local onlineSample=table.concat({
    "FGS1;forevercompanion;2026-11-09T06:00:00.000Z;Schattenfang%20Beute",
    "R;D;shadowfang-keep;shadowfang-keep;Shadowfang%20Keep;Level%2018-30",
    "R;I;1001;shadowfang-keep;Haunting%20Blade;Boss%3A%20Deathsworn%20Captain",
    "R;Q;100;-;Eine%20Testquest;Von%20der%20Community",
    "R;Q;101;-;Andere%20Aufgabe;Ohne%20Kartenposition",
    "R;R;rare-1;-;Rare%20Beast;Koordinaten%20ohne%20uiMapID",
    "END"},"\n")
test("free online lookup packet parses data only",function()
    local r=assert(FG.ParseOnlineResults(onlineSample));eq(r.bridgeType,"online");eq(#r.rows,5)
    eq(r.rows[2].name,"Haunting Blade");eq(r.rows[2].target,"shadowfang-keep")
    assert(r.updatedAt:find("2026-11-09",1,true))
end)
test("online lookup rejects injection and broken percent encoding",function()
    assert(not FG.ParseOnlineResults(onlineSample:gsub("Haunting%%20Blade","Haunting%%ZZBlade")))
    assert(not FG.ParseOnlineResults(onlineSample:gsub("R;Q;100;%-;","R;Q;100;bad;evil;")))
    assert(not FG.ParseOnlineResults(onlineSample:gsub(";rare%-1;", ";rare;evil;")))
    assert(not FG.ParseOnlineResults("return os.execute('bad')"))
    assert(not FG.ParseOnlineResults(onlineSample.."\n/run print('unsafe')"))
end)
test("online dungeon and item source resolve only pre-approved local approach point",function()
    local r=assert(FG.ParseOnlineResults(onlineSample))
    assert(FG:ApplyOnlineResults(r))
    eq(#FG.searchFrame.results,5)
    assert(not FG.nav)
    eq(FG.searchFrame.results[1].route.points[1].mapID,1421)
    eq(FG.searchFrame.results[2].route.points[1].mapID,1421)
    assert(FG.searchFrame.results[3].route and FG.searchFrame.results[3].route.questID==100)
    assert(not FG.searchFrame.results[4].route)
    assert(not FG.searchFrame.results[5].route)
end)
test("click on imported dungeon offers route, never auto-walks",function()
    FG.searchFrame.rows[1].scripts.OnClick()
    assert(FG.searchFrame.start.enabled)
    assert(FG.destination and FG.destination.points[1].mapID==1421)
    assert(not FG.nav)
    FG.searchFrame.start.scripts.OnClick()
    assert(FG.nav and FG.nav.points[1].mapID==1421)
    FG:StopNavigation(true)
end)
test("unknown map selection leaves navigation unavailable",function()
    assert(FG:ApplyOnlineResults(assert(FG.ParseOnlineResults(onlineSample))))
    FG.searchFrame.rows[5].scripts.OnClick()
    assert(not FG.searchFrame.start.enabled)
    assert(not FG.destination)
    assert(not FG.nav)
end)
test("rare entry cannot smuggle in a known dungeon target",function()
    local r=assert(FG.ParseOnlineResults("FGS1;forevercompanion;unknown;Rare\nR;R;rare-1;deadmines;Rare%20Beast;Test\nEND"))
    assert(not FG:OnlineRoute(r.rows[1]))
end)
test("Online FGS1 import window demands explicit approval",function()
    FG:ShowTransfer("import",onlineSample)
    assert(not FG.transfer.start.enabled)
    FG.transfer.check.scripts.OnClick()
    assert(FG.transfer.start.enabled)
    eq(FG.transfer.checked.bridgeType,"online")
    FG.transfer.start.scripts.OnClick()
    eq(#FG.searchFrame.results,5)
    assert(not FG.nav)
end)

test("no cache is safely reported inside game",function()
    assert(not FG:SearchSynced("Welche Schwerter mit Level 25?"))
    assert(FG:SyncedDataStatus():find("Keine automatisch",1,true))
end)
local fixture={schema=1,source="https://forevercompanion.io/developers",syncedAt="2026-11-10",updatedAt="2026-11-07",
 dungeons={{id="shadowfang-keep",name="Shadowfang Keep",min=18,max=30,zone="Silverpine Forest",pinKey="shadowfang",entrance="Pyrewood"},
   {id="unknown-dungeon",name="Secret Dungeon",min=23,max=30,zone="New Island",pinKey="",entrance="Unknown"}},
 items={{id=1001,name="A Whispering Blade",weaponType="Sword",slot="One-Hand",itemLevel=29,level=22,verified=3,classicOnly=false,
     drops={{dungeonId="shadowfang-keep",boss="Test Boss"}}},
   {id=1002,name="Ancient Axe",weaponType="Axe",slot="Two-Hand",itemLevel=31,level=24,
     drops={{dungeonId="unknown-dungeon",boss="Unknown Boss"}}}},
 quests={{id=400,name="A Haunted Mission",level=22,giver="Guide",location="Silverpine",dungeonId="shadowfang-keep"}},
 rares={{id="rare",name="Ashen Scout",zone="Westfall",coords={"51.1, 35.2"}}}}
test("synced cache status and source show in /fai daten",function()
    FG.SyncData=fixture
    assert(FG:SyncedDataStatus():find("2 Items",1,true))
    FG:Ask("daten")
    assert(FG.messages[#FG.messages]:find("Forever Companion",1,true))
end)
test("synced German shadowfang loot lists boss and clickable approach",function()
    FG:ClearChat()
    assert(FG:SearchSynced("welche beute gibt es in burg schattenfang?"))
    assert(FG.searchFrame and #FG.searchFrame.results==1)
    assert(FG.searchFrame.results[1].route)
    assert(FG.searchFrame.results[1].detail:find("Test Boss",1,true))
    FG.searchFrame.rows[1].scripts.OnClick()
    assert(FG.destination and FG.destination.points[1].mapID==1421)
    FG.destination=nil;FG:RefreshDestination()
end)
test("synced weapon question filters level and type",function()
    FG:ClearChat()
    assert(FG:SyncedWeaponResults("besseres Schwert für Krieger Level 23"))
    eq(#FG.searchFrame.results,1)
    eq(FG.searchFrame.results[1].name,"A Whispering Blade")
end)
test("English sword question works with cached dataset",function()
    FG:SetLanguage("en")
    assert(FG:SearchSynced("better sword for warrior level 25"))
    eq(FG.searchFrame.results[1].name,"A Whispering Blade")
    FG:SetLanguage("de")
end)
test("unknown dungeon returns informational result without invented map ID",function()
    assert(FG:SearchSynced("where is Secret Dungeon entrance"))
    eq(FG.searchFrame.results[1].name,"Secret Dungeon")
    assert(not FG.searchFrame.results[1].route)
end)
test("known quest with dungeon source can navigate to approximate entrance",function()
    assert(FG:SearchSynced("where is A Haunted Mission quest"))
    assert(FG.searchFrame.results[1].route and FG.searchFrame.results[1].route.points[1].mapID==1421)
end)
test("rare coordinates are informational when UiMapID unavailable",function()
    assert(FG:SearchSynced("where is Ashen Scout rare"))
    assert(not FG.searchFrame.results[1].route)
    assert(FG.searchFrame.results[1].detail:find("51.1",1,true))
end)
test("synced level-matched dungeon list works directly in addon chat",function()
    assert(FG:SearchSynced("welche dungeons für level 22"))
    eq(#FG.searchFrame.results,1)
    eq(FG.searchFrame.results[1].name,"Shadowfang Keep")
end)
test("synced general level-matched quest list",function()
    assert(FG:SearchSynced("quests für level 22"))
    eq(FG.searchFrame.results[1].name,"A Haunted Mission")
end)
test("low-level candidates excluded if character cannot equip",function()
    assert(FG:SyncedWeaponResults("two handed axe level 22")==false)
end)


-- Experimental bridge unit checks. Simulated game APIs only; Windows screen capture
-- and actual client addon hot-loading still require a real in-game test.
test("live AI is opt-in and disabled by default",function()
    eq(FG.db.liveEnabled,false)
    eq(FG:LiveQuestion("Welche Waffe ist besser?"),false)
    assert(not FG.livePending)
end)
test("/fai live an enables bridge, switch is persisted",function()
    FG:LiveCommand("an")
    assert(FG.db.liveEnabled)
    assert(FG:LiveStatus():find("EIN",1,true))
    assert(FG.liveButton.text:find("AN",1,true))
end)
test("live question builds short bilingual packet and renders a visible pixel strip",function()
    FG.db.catalog=nil
    FG.db.ai.model="auto"
    FG.liveSession="65b2c04200abcdef"
    FG.liveId=11
    FG:LiveQuestion("Welche Schwerter für Krieger Level 25?")
    assert(FG.livePending and FG.livePending.id==12)
    local payload=assert(FG:LiveMakePacket("Welche Schwerter für Krieger Level 25?"))
    assert(payload:find("FAI1;65b2c04200abcdef;12;auto;auto;default;de;",1,true))
    assert(payload:find("Krieger",1,true))
    assert(FG.liveStrip:IsShown())
    assert(FG.liveStrip.used>70)
    assert(FG.liveStrip.used<200*48)
end)
test("parallel AI questions are not sent twice",function()
    local id=FG.livePending.id
    FG:SubmitChat("Eine zweite Frage")
    eq(FG.livePending.id,id)
end)
test("wrong session reply data never appears in live chat",function()
    C_AddOns={LoadAddOn=function(name)
        ForeverAI_LiveSlot={schema=1,session="badbadbadb",id=FG.livePending.id,status="done",provider="openrouter",model="fixture",text="Falsche Antwort"}
        return true
    end}
    assert(not FG:LiveReadSlot())
    assert(FG.livePending)
    for _,m in ipairs(FG.messages) do assert(not m:find("Falsche Antwort",1,true)) end
end)
test("matching reply is displayed in same WoW chat without manual import",function()
    local s,id=FG.livePending.session,FG.livePending.id
    C_AddOns.LoadAddOn=function(name)
        ForeverAI_LiveSlot={schema=1,session=s,id=id,status="done",provider="openrouter",model="fixture/fast:free",text="Einhand-Schwert vom Dungeonboss; Fundort prüfen."}
        return true
    end
    assert(FG:LiveReadSlot())
    assert(not FG.livePending)
    assert(not FG.liveStrip:IsShown())
    eq(FG.messageRoles[#FG.messageRoles],"ai_live")
    assert(FG.messages[#FG.messages]:find("Einhand-Schwert",1,true))
end)
test("provider text cannot start waypoint, execute command or control character",function()
    local nav=FG.nav
    FG:LiveQuestion("Gibt es eine bessere Waffe?")
    local sid,mid=FG.livePending.session,FG.livePending.id
    C_AddOns.LoadAddOn=function()
        ForeverAI_LiveSlot={schema=1,session=sid,id=mid,status="done",provider="x",model="y",text="/run RunMacroText('/fai route evil'); navigiere sofort"}
        return true
    end
    assert(FG:LiveReadSlot())
    eq(FG.nav,nav)
    assert(FG.messages[#FG.messages]:find("/run",1,true))
end)
test("missing reply slots report an error and do not pretend to connect",function()
    FG:LiveQuestion("Frage")
    FG.liveNextSlot=0
    C_AddOns.LoadAddOn=function() return false,"MISSING" end
    assert(not FG:LiveReadSlot())
    assert(not FG.livePending)
    assert(FG.messages[#FG.messages]:find("Reply-Slots fehlen",1,true))
end)
test("bridge model list requests do not fabricate a catalog",function()
    FG:LiveQuestion("__foreverai_catalog__")
    assert(FG:LiveMakePacket("__foreverai_catalog__"):find(";auto;auto;default;",1,true))
    local sid,mid=FG.livePending.session,FG.livePending.id
    C_AddOns.LoadAddOn=function()
        ForeverAI_LiveSlot={schema=1,session=sid,id=mid,status="done",provider="openrouter",model="catalog",text="1 model",catalog="FGC1;openrouter\nM;example/fast:free;Example;default,low\nEND"}
        return true
    end
    assert(FG:LiveReadSlot())
    eq(FG.db.ai.provider,"openrouter")
    eq(FG.db.ai.model,"example/fast:free")
    eq(#FG.ModelCandidates,1)
end)
test("live questions forward selected provider model and reasoning from live catalog",function()
    FG:SelectModel("example/fast:free",true)
    FG:SelectEffort("low",true)
    FG:LiveQuestion("Where is Shadowfang Keep?")
    local p=assert(FG:LiveMakePacket("Where is Shadowfang Keep?"))
    assert(p:find(";openrouter;example/fast:free;low;de;",1,true))
    FG:LiveFinish(nil)
end)
test("time-out is visible and clears in-game request without accepting stale answers",function()
    _G.FAI_TEST_TIME=100
    GetTime=function() return _G.FAI_TEST_TIME end
    FG:LiveQuestion("Nachfrage")
    _G.FAI_TEST_TIME=282
    FG:LiveTick()
    assert(not FG.livePending)
    assert(FG.messages[#FG.messages]:find("Zeitüberschreitung",1,true))
end)
test("disabling live AI restores local offline knowledge without bridge",function()
    FG:LiveCommand("aus")
    assert(FG.db.liveEnabled==false)
    assert(not FG.livePending)
    FG:SubmitChat("Welche Dungeons für Level 22?")
    assert(FG.searchFrame and #FG.searchFrame.results>0)
end)

test("Questie quest index is built incrementally and supplies evidence",function()
    local previous=_G.LibQuestieDB
    _G.LibQuestieDB={Quest={GetAllIds=function() return {42} end,name=function() return "The Test Quest" end,
        questLevel=function() return 12 end,requiredLevel=function() return 10 end,
        objectivesText=function() return {"Find the artifact"} end}}
    FG:InitQuestieEvidence()
    assert(FG.questieIndexFrame.scripts.OnUpdate)
    FG.questieIndexFrame.scripts.OnUpdate(FG.questieIndexFrame)
    assert(FG.questieIndexReady)
    local evidence=FG:QuestieEvidence("Where is The Test Quest?")
    assert(evidence:find("QuestieDB quest #42",1,true)); assert(evidence:find("Find the artifact",1,true))
    eq(#FG:QuestieQuestResults("The Test Quest"),1)
    _G.LibQuestieDB=previous
    FG.questieNames=nil
end)

test("main views switch without creating another window",function()
    FG:SetMainView("settings"); assert(FG.window.views.settings:IsShown()); assert(not FG.window.views.chat:IsShown())
    FG:SetMainView("navigation"); assert(FG.window.views.navigation:IsShown()); assert(not FG.window.views.settings:IsShown())
    FG:SetMainView("chat"); assert(FG.window.views.chat:IsShown()); assert(not FG.window.views.navigation:IsShown())
end)

test("unanswered chat question does not open an export view",function()
    FG:SetMainView("chat")
    local previous=FG.db.liveEnabled;FG.db.liveEnabled=false
    assert(FG:SubmitChat("Eine unbekannte Frage ohne Treffer 918273"))
    assert(not FG.transfer or not FG.transfer:IsShown())
    assert(FG.window.views.chat:IsShown())
    FG.db.liveEnabled=previous
end)

test("transfer and search replace the active view and restore it on close",function()
    FG:SetMainView("chat")
    FG:ShowTransfer("export","Beispiel")
    assert(FG.transfer:IsShown());assert(not FG.window.views.chat:IsShown())
    FG.transfer:Hide();assert(FG.window.views.chat:IsShown())
    FG:ShowSearchResults({{name="Beispiel",detail="Info"}},"Beispiel")
    assert(FG.searchFrame:IsShown());assert(not FG.window.views.chat:IsShown())
    FG.searchFrame:Hide();assert(FG.window.views.chat:IsShown())
    FG:ShowTransfer("import","")
    FG:ShowSearchResults({{name="Beispiel",detail="Info"}},"Beispiel")
    assert(not FG.transfer:IsShown());assert(FG.searchFrame:IsShown());assert(not FG.window.views.chat:IsShown())
    FG:SetMainView("settings");assert(FG.window.views.settings:IsShown());assert(not FG.searchFrame:IsShown())
    FG:SetMainView("chat")
end)

test("disabling context removes character information from live request",function()
    local previousSession,previousId=FG.liveSession,FG.liveId
    FG.liveSession="1234567890abcd";FG.liveId=42;FG.db.shareContext=false
    local packet=FG:LiveMakePacket("Hello")
    assert(packet and packet:sub(-1)==";");assert(not packet:find("class",1,true))
    FG.db.shareContext=nil;FG.liveSession=previousSession;FG.liveId=previousId
end)

test("game context uses relevant client and community data",function()
    local oldObj=C_QuestLog.GetQuestObjectives
    C_QuestLog.GetQuestObjectives=function(id) if id==100 then return {{text="Find the artifact",finished=false}} end end
    local quest=FG:GameEvidence("Wo ist Eine Testquest?")
    assert(quest:find("WoW client active quest #100",1,true),quest)
    assert(quest:find("Find the artifact",1,true),quest)
    C_QuestLog.GetQuestObjectives=oldObj
    local previousDB,previousIndex=_G.LibQuestieDB,FG.questieNpcIndex
    _G.LibQuestieDB={Npc={spawns=function()return {[12]={{40,50}}} end}}
    FG.questieNpcIndex={{id=123,name="Testmann",normalized="testmann",sub=""}}
    local npc=FG:GameEvidence("Wo ist Testmann?")
    assert(npc:find("QuestieDB community NPC #123",1,true),npc)
    assert(npc:find("map=1429",1,true),npc)
    _G.LibQuestieDB=previousDB;FG.questieNpcIndex=previousIndex
end)

test("local destination links open the map and cannot be forged",function()
    FG:StopNavigation(true);FG:SetMainView("chat");FG:ClearChat();state.pin=nil
    local targets=FG:ResolveChatTargets("Wo ist Sturmwind?")
    assert(#targets>0);eq(targets[1].route.points[1].mapID,1453)
    FG:AddChatTargets(targets)
    local id=FG.chatTargetOrder[1]
    assert(FG.messages[#FG.messages]:find("|Hforeverai:"..id.."|h",1,true))
    assert(not FG:OpenChatTarget("foreverai:999999"));assert(not state.pin)
    assert(FG:OpenChatTarget("foreverai:"..id));eq(state.openMap,1453);eq(state.pin.uiMapID,1453)
    FG:ClearChat();assert(not FG:OpenChatTarget("foreverai:"..id))
    state.pin=nil;FG.destination=nil;FG:RefreshDestination()
end)

test("live location reply carries a local target and offers a clickable marker",function()
    FG:StopNavigation(true);FG:ClearChat();state.pin=nil
    FG.db.liveEnabled=true;FG.db.shareContext=true
    assert(FG:LiveQuestion("Wo ist Sturmwind?"))
    assert(FG.livePending and #FG.livePending.targets>0)
    FG.liveLookupTargets=FG.livePending.targets
    local packet=FG:LiveMakePacket("Wo ist Sturmwind?")
    FG.liveLookupTargets=nil
    assert(packet:find("Map%%20target",1,false),packet)
    FG:LiveFinish({status="done",provider="fixture",model="fixture",text="Sturmwind liegt im Wald von Elwynn."})
    eq(FG.messageRoles[#FG.messageRoles],"target")
    local id=FG.chatTargetOrder[1]
    assert(FG.messages[#FG.messages]:find("|Hforeverai:"..id.."|h",1,true))
    assert(not state.pin)
    assert(FG:OpenChatTarget("foreverai:"..id));eq(state.pin.uiMapID,1453)
    state.pin=nil;FG.destination=nil;FG:RefreshDestination()
end)

test("known dungeon entrance can be resolved for chat",function()
    local targets=FG:ResolveChatTargets("Wo ist der Eingang der Todesminen?")
    assert(#targets>0)
    local found=false
    for _,target in ipairs(targets) do if target.route.points[1].mapID==1436 then found=true end end
    assert(found,"missing Westfall entrance target")
end)

test("NPC chat target uses QuestieDB spawn instead of invented coordinates",function()
    local oldDB,oldIndex=_G.LibQuestieDB,FG.questieNpcIndex
    _G.LibQuestieDB={Npc={GetAllIds=function() return {123} end,name=function() return "Testmann" end,
        spawns=function() return {[1519]={{40,50}}} end}}
    FG.questieNpcIndex={{id=123,name="Testmann",sub="",canonicalName="testmann",canonicalSub=""}}
    local targets=FG:ResolveChatTargets("Wo ist NPC Testmann?")
    assert(#targets>0);eq(targets[1].source,"QuestieDB")
    eq(targets[1].route.points[1].mapID,1453);eq(targets[1].route.points[1].x,0.4)
    _G.LibQuestieDB=oldDB;FG.questieNpcIndex=oldIndex
end)

test("Shadowfang variants resolve to the outdoor approach",function()
    for _,query in ipairs({"Wo ist Schattenfangburg?","kannst du mir eine wegführung zu der schattenburg starten?"}) do
        local targets=FG:ResolveChatTargets(query)
        eq(#targets,1);eq(targets[1].route.points[1].mapID,1421)
    end
end)

test("explicit chat request starts navigation to the resolved target",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true;FG.db.shareContext=true
    local oldPath=_G.ShortestPathForever;local call
    _G.ShortestPathForever={API={NavigateRoute=function(owner,stops) call={owner,stops};return true end,Cancel=function() return true end}}
    assert(FG:LiveQuestion("kannst du mir eine wegführung zu der schattenburg starten?"))
    assert(call);eq(call[1],"ForeverAI");eq(call[2][1].map,1421)
    assert(FG.nav and FG.nav.spf);assert(FG.livePending and #FG.livePending.targets==1)
    FG:LiveFinish(nil);FG:StopNavigation(true);_G.ShortestPathForever=oldPath
end)

test("ambiguous explicit navigation does not start a journey",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    local oldPath=_G.ShortestPathForever;local called=false
    _G.ShortestPathForever={API={NavigateRoute=function() called=true;return true end}}
    assert(FG:LiveQuestion("Wegführung nach DM starten"));assert(not called);assert(not FG.nav)
    FG:LiveFinish(nil);_G.ShortestPathForever=oldPath
end)

test("local item answer takes precedence over live AI",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    FG:SubmitChat("Welche Schwerter für Krieger Level 25?")
    assert(not FG.livePending);assert(#FG.messages>1)
end)

test("unknown question falls back to live AI",function()
    FG:ClearChat();FG.db.liveEnabled=true
    FG:SubmitChat("Warum existiert das rätselhafte Sternenphänomen 84923?")
    assert(FG.livePending);FG:LiveFinish(nil)
end)

test("city location question starts the city destination",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    FG:SubmitChat("Wo ist Sturmwind?")
    assert(FG.nav);eq(FG.nav.points[1].mapID,1453);assert(not FG.livePending)
    FG:StopNavigation(true)
end)

test("unreachable route falls back to a straight line",function()
    FG:StopNavigation(true)
    local oldPath=_G.ShortestPathForever;local called=false
    _G.ShortestPathForever={API={EstimateDetail=function() return nil,"unreachable" end,
        NavigateRoute=function() called=true;return true end}}
    assert(FG:StartNavigation(simpleRoute()));assert(not called);assert(FG.nav and not FG.nav.spf)
    FG:StopNavigation(true);_G.ShortestPathForever=oldPath
end)

test("rejected path start falls back to a straight line",function()
    FG:StopNavigation(true)
    local oldPath=_G.ShortestPathForever
    _G.ShortestPathForever={API={NavigateRoute=function() return false end}}
    assert(FG:StartNavigation(simpleRoute()));assert(FG.nav and not FG.nav.spf)
    FG:StopNavigation(true);_G.ShortestPathForever=oldPath
end)

test("Shortest Path arrival clears ForeverAI guidance",function()
    FG:StopNavigation(true)
    local oldPath,oldUnsubscribe=_G.ShortestPathForever,FG.spfUnsubscribe
    local callback,reason
    FG.spfUnsubscribe=nil
    _G.ShortestPathForever={API={NavigateRoute=function() return true end,Cancel=function() return true end,
        Subscribe=function(fn) callback=fn;return function() end end,Ended=function() return reason end}}
    assert(FG:StartNavigation(simpleRoute()));assert(FG.nav and FG.nav.spf);assert(callback)
    reason="arrived";callback();assert(not FG.nav)
    _G.ShortestPathForever=oldPath;FG.spfUnsubscribe=oldUnsubscribe
end)

test("Shortest Path losing its guide falls back to the remaining target",function()
    FG:StopNavigation(true)
    local oldPath,oldUnsubscribe=_G.ShortestPathForever,FG.spfUnsubscribe
    local callback,active,cancelled=nil,true,false
    FG.spfUnsubscribe=nil
    _G.ShortestPathForever={API={NavigateRoute=function() return true end,
        Cancel=function(owner) cancelled=owner;return true end,
        Subscribe=function(fn) callback=fn;return function() end end,
        Ended=function() return nil end,Active=function() return active end,CurrentStop=function() return 1 end}}
    assert(FG:StartNavigation(simpleRoute()));assert(FG.nav and FG.nav.spf)
    callback({active=true});assert(FG.nav.spf)
    active=false;callback({active=true})
    eq(cancelled,"ForeverAI");assert(FG.nav and not FG.nav.spf);assert(FG.arrow:IsShown())
    FG:StopNavigation(true);_G.ShortestPathForever=oldPath;FG.spfUnsubscribe=oldUnsubscribe
end)

test("Shortest Path temporary non-active events do not force fallback",function()
    FG:StopNavigation(true)
    local oldPath,oldUnsubscribe=_G.ShortestPathForever,FG.spfUnsubscribe
    local callback
    FG.spfUnsubscribe=nil
    _G.ShortestPathForever={API={NavigateRoute=function() return true end,Cancel=function() return true end,
        Subscribe=function(fn) callback=fn;return function() end end,
        Ended=function() return nil end,Active=function() return false end,CurrentStop=function() return 1 end}}
    assert(FG:StartNavigation(simpleRoute()));callback({stop=true});assert(FG.nav.spf)
    FG:StopNavigation(true);_G.ShortestPathForever=oldPath;FG.spfUnsubscribe=oldUnsubscribe
end)

test("Shortest Path navigation uses its owned route and cancels only that route",function()
    local called,cancelled
    _G.ShortestPathForever={API={NavigateRoute=function(owner,stops) called={owner,stops}; return true end,
        Cancel=function(owner) cancelled=owner; return true end}}
    FG:StopNavigation(true)
    assert(FG:StartNavigation(simpleRoute()))
    eq(called[1],"ForeverAI"); assert(FG.nav.spf); eq(called[2][1].map,FG.nav.points[1].mapID)
    FG:StopNavigation(true); eq(cancelled,"ForeverAI")
    _G.ShortestPathForever=nil
end)

test("Shortest Path uses walking bends and restores the previous setting",function()
    FG:StopNavigation(true);FG:RestorePathDisplays()
    local oldSettings,oldPath=Settings,_G.ShortestPathForever
    local setting={value=true,GetValue=function(self)return self.value end,SetValue=function(self,value)self.value=value end}
    Settings={GetSetting=function(key) if key=="ShortestPathForever_guideStops" then return setting end end}
    _G.ShortestPathForever={API={NavigateRoute=function()return true end,Cancel=function()return true end}}
    assert(FG:StartNavigation(simpleRoute()));eq(setting.value,false)
    FG:StopNavigation(true);eq(setting.value,true)
    Settings=oldSettings;_G.ShortestPathForever=oldPath
end)

test("Shortest Path does not override a setting changed by the user",function()
    FG:StopNavigation(true);FG:RestorePathDisplays()
    local oldSettings=Settings
    local setting={value=false,GetValue=function(self)return self.value end,SetValue=function(self,value)self.value=value end}
    Settings={GetSetting=function(key) if key=="ShortestPathForever_guideStops" then return setting end end}
    FG:UsePathDisplays();setting.value=true;FG:RestorePathDisplays();eq(setting.value,true)
    Settings=oldSettings
end)

test("long search rows are bounded and controls do not overlap the details",function()
    FG:ShowSearchResults({{name=string.rep("Sehr langer Questtitel ",10),detail=string.rep("Ausführlicher Questtext ",20)}},"Quest")
    local f=FG.searchFrame
    assert(#f.rows[1].text<=150);eq(f.rows[1].font.wordWrap,false)
    eq(f.start.point[2],250);eq(f.start.point[3],12)
    f:Hide()
end)

test("natural question prioritizes the active quest and its client waypoint",function()
    FG:StopNavigation(true);FG:ClearChat()
    assert(FG:SubmitChat("Bei meinen aktiven Quests: Wo ist die Quest Eine Testquest? Kannst du da eine Wegführung machen?"))
    assert(FG.nav);eq(FG.nav.questID,100);FG:StopNavigation(true)
end)

test("active quest objective item resolves its QuestieDB NPC drop",function()
    FG:StopNavigation(true);FG:ClearChat()
    local oldQuests,oldDB,oldWaypoint=FG.GetQuests,_G.LibQuestieDB,C_QuestLog.GetNextWaypoint
    FG.GetQuests=function()return {{id=181,title="Der Blick zu den Sternen"}} end
    C_QuestLog.GetNextWaypoint=function()end
    _G.LibQuestieDB={Quest={objectives=function(id) if id==181 then return {{},{},{{999,1}}} end end},
        Item={name=function()return "Bronzerohr" end,npcDrops=function()return {888} end,objectDrops=function()return {} end},
        Npc={name=function()return "Oger" end,spawns=function()return {[130]={{40,50}}} end}}
    assert(FG:SubmitChat("Bei meinen aktiven Quests wo ist die Quest Der Blick zu den Sternen? Kannst du da eine Wegführung machen?"))
    assert(FG.nav);eq(FG.nav.points[1].mapID,1421);eq(FG.nav.points[1].x,.4)
    assert(FG.nav.points[1].note:find("QuestieDB",1,true))
    FG:StopNavigation(true);FG.GetQuests=oldQuests;_G.LibQuestieDB=oldDB;C_QuestLog.GetNextWaypoint=oldWaypoint
end)

test("active quest with several objective locations asks for selection",function()
    FG:StopNavigation(true);FG:ClearChat()
    local oldQuests,oldDB,oldWaypoint=FG.GetQuests,_G.LibQuestieDB,C_QuestLog.GetNextWaypoint
    FG.GetQuests=function()return {{id=181,title="Der Blick zu den Sternen"}} end
    C_QuestLog.GetNextWaypoint=function()end
    _G.LibQuestieDB={Quest={objectives=function()return {{{888,1},{889,1}}} end},
        Npc={name=function(id)return "Oger "..id end,spawns=function(id)return {[130]={{id==888 and 40 or 50,50}}} end}}
    assert(FG:SubmitChat("Wo ist die Quest Der Blick zu den Sternen?"))
    assert(not FG.nav);assert(FG.searchFrame:IsShown());eq(#FG.searchFrame.results,2)
    FG.searchFrame.rows[1].scripts.OnClick();assert(FG.searchFrame.start.enabled)
    FG.searchFrame.start.scripts.OnClick();assert(FG.nav)
    FG:StopNavigation(true);FG.GetQuests=oldQuests;_G.LibQuestieDB=oldDB;C_QuestLog.GetNextWaypoint=oldWaypoint
end)

test("navigation active quests list starts a selected client quest",function()
    FG:StopNavigation(true);FG:SetMainView("navigation")
    FG.activeQuestsButton.scripts.OnClick()
    assert(FG.searchFrame:IsShown());eq(#FG.searchFrame.results,2);assert(FG.searchFrame.directStart)
    FG.searchFrame.rows[1].scripts.OnClick()
    assert(FG.nav);eq(FG.nav.questID,100);eq(FG.activeView,"navigation");assert(not FG.searchFrame:IsShown())
    FG:StopNavigation(true)
end)

test("quest list reports missing coordinates without replacing navigation",function()
    FG:StopNavigation(true);FG:SetMainView("navigation");FG:StartNavigation(simpleRoute())
    local nav=FG.nav
    FG:ShowActiveQuestList();FG.searchFrame.rows[2].scripts.OnClick()
    eq(FG.nav,nav);assert(FG.searchFrame:IsShown());assert(FG.searchFrame.info.text:find("kein verwendbares Ziel",1,true))
    FG.searchFrame:Hide();FG:StopNavigation(true)
end)

test("navigation dungeon list filters by character level and click starts route",function()
    FG:StopNavigation(true);FG:SetMainView("navigation")
    FG.levelDungeonsButton.scripts.OnClick()
    assert(FG.searchFrame:IsShown());assert(FG.searchFrame.directStart)
    local found=false
    for _,row in ipairs(FG.searchFrame.results) do
        if row.name=="Burg Schattenfang" then found=true end
        assert(row.name~="Gnomeregan")
    end
    assert(found);FG.searchFrame.rows[1].scripts.OnClick();assert(FG.nav);assert(not FG.searchFrame:IsShown());FG:StopNavigation(true)
end)

test("navigation quest list allows choosing among objective locations",function()
    FG:StopNavigation(true);FG:SetMainView("navigation")
    local oldQuests,oldDB,oldWaypoint=FG.GetQuests,_G.LibQuestieDB,C_QuestLog.GetNextWaypoint
    FG.GetQuests=function()return {{id=181,title="Der Blick zu den Sternen"}} end
    C_QuestLog.GetNextWaypoint=function()end
    _G.LibQuestieDB={Quest={objectives=function()return {{{888,1},{889,1}}} end},
        Npc={name=function(id)return "Oger "..id end,spawns=function(id)return {[130]={{id==888 and 40 or 50,50}}} end}}
    FG:ShowActiveQuestList();FG.searchFrame.rows[1].scripts.OnClick()
    assert(not FG.nav);assert(FG.searchFrame:IsShown());eq(#FG.searchFrame.results,2);assert(FG.searchFrame.directStart)
    FG.searchFrame.rows[1].scripts.OnClick();assert(FG.nav);eq(FG.nav.points[1].mapID,1421)
    FG:StopNavigation(true);FG.GetQuests=oldQuests;_G.LibQuestieDB=oldDB;C_QuestLog.GetNextWaypoint=oldWaypoint
end)

test("quest completion automatically starts the QuestieDB turn-in route",function()
    FG:StopNavigation(true);FG:ClearChat()
    local oldDB,oldComplete=_G.LibQuestieDB,C_QuestLog.IsComplete
    local complete=false
    C_QuestLog.IsComplete=function(id)return id==100 and complete end
    _G.LibQuestieDB={Quest={finishedBy=function(id) if id==100 then return {{777},{}} end end},
        Npc={name=function()return "Abgabe NPC" end,spawns=function()return {[130]={{40,50}}} end}}
    eq(FG:StartActiveQuest(100),"started");assert(FG.questTurnInWatch)
    complete=true;event("QUEST_LOG_UPDATE")
    assert(FG.nav);eq(FG.nav.points[1].mapID,1421);eq(FG.questTurnInWatch.phase,"turnin")
    local nav=FG.nav;event("QUEST_LOG_UPDATE");eq(FG.nav,nav)
    event("QUEST_TURNED_IN",100);assert(not FG.questTurnInWatch)
    FG:StopNavigation(true);_G.LibQuestieDB=oldDB;C_QuestLog.IsComplete=oldComplete
end)

test("quest watcher survives reaching the objective and clears on manual stop",function()
    FG:StopNavigation(true);state.x=.5
    local oldComplete=C_QuestLog.IsComplete;C_QuestLog.IsComplete=function()return false end
    eq(FG:StartActiveQuest(100),"started");state.x=.6;FG:Tick()
    assert(not FG.nav);assert(FG.questTurnInWatch and FG.questTurnInWatch.id==100)
    FG:StopNavigation();assert(not FG.questTurnInWatch)
    state.x=.5;C_QuestLog.IsComplete=oldComplete
end)

test("quest turn-in waits until combat ends",function()
    FG:StopNavigation(true);state.combat=false
    local oldDB,oldComplete=_G.LibQuestieDB,C_QuestLog.IsComplete
    local complete=false;C_QuestLog.IsComplete=function()return complete end
    _G.LibQuestieDB={Quest={finishedBy=function()return {{777},{}} end},
        Npc={name=function()return "Abgabe NPC" end,spawns=function()return {[130]={{40,50}}} end}}
    eq(FG:StartActiveQuest(100),"started");local nav=FG.nav
    state.combat=true;complete=true;event("QUEST_LOG_UPDATE");eq(FG.nav,nav);eq(FG.questTurnInWatch.phase,"objectives")
    state.combat=false;event("PLAYER_REGEN_ENABLED");eq(FG.nav.points[1].mapID,1421);eq(FG.questTurnInWatch.phase,"turnin")
    FG:StopNavigation(true);_G.LibQuestieDB=oldDB;C_QuestLog.IsComplete=oldComplete
end)

test("multiple quest finishers require a selection",function()
    FG:StopNavigation(true)
    local oldDB,oldComplete=_G.LibQuestieDB,C_QuestLog.IsComplete
    local complete=false;C_QuestLog.IsComplete=function()return complete end
    _G.LibQuestieDB={Quest={finishedBy=function()return {{777,778},{}} end},
        Npc={name=function(id)return "Abgabe "..id end,spawns=function(id)return {[130]={{id==777 and 40 or 50,50}}} end}}
    eq(FG:StartActiveQuest(100),"started");complete=true;event("QUEST_LOG_UPDATE")
    assert(FG.searchFrame:IsShown());eq(#FG.searchFrame.results,2);assert(FG.searchFrame.directStart)
    FG.searchFrame.rows[1].scripts.OnClick();eq(FG.nav.points[1].mapID,1421)
    FG:StopNavigation(true);_G.LibQuestieDB=oldDB;C_QuestLog.IsComplete=oldComplete
end)

test("unrelated journey is not replaced automatically after quest completion",function()
    FG:StopNavigation(true)
    local oldDB,oldComplete,oldPath=_G.LibQuestieDB,C_QuestLog.IsComplete,_G.ShortestPathForever
    local complete=false;C_QuestLog.IsComplete=function()return complete end
    _G.LibQuestieDB={Quest={finishedBy=function()return {{777},{}} end},
        Npc={name=function()return "Abgabe NPC" end,spawns=function()return {[130]={{40,50}}} end}}
    eq(FG:StartActiveQuest(100),"started");FG:StopNavigation(true,true)
    _G.ShortestPathForever={API={Active=function()return true end}}
    complete=true;event("QUEST_LOG_UPDATE");assert(not FG.nav);assert(FG.searchFrame:IsShown());eq(FG.questTurnInWatch.phase,"selection")
    FG.searchFrame:Hide();FG:StopNavigation(true);_G.LibQuestieDB=oldDB;C_QuestLog.IsComplete=oldComplete;_G.ShortestPathForever=oldPath
end)

test("quest completion without a turn-in location does not fabricate a target",function()
    FG:StopNavigation(true)
    local oldDB,oldComplete,oldWaypoint=_G.LibQuestieDB,C_QuestLog.IsComplete,C_QuestLog.GetNextWaypoint
    local complete=false;C_QuestLog.IsComplete=function()return complete end
    _G.LibQuestieDB={Quest={finishedBy=function()return {{},{}} end}}
    eq(FG:StartActiveQuest(100),"started");local nav=FG.nav
    complete=true;event("QUEST_LOG_UPDATE");eq(FG.nav,nav);eq(FG.questTurnInWatch.phase,"missing")
    FG:StopNavigation(true);_G.LibQuestieDB=oldDB;C_QuestLog.IsComplete=oldComplete;C_QuestLog.GetNextWaypoint=oldWaypoint
end)

test("Questie public update callback checks only the watched quest",function()
    local oldQuestie,oldRegistered,oldCheck=_G.Questie,FG.questieUpdatesRegistered,FG.CheckQuestTurnIn
    local callback,count=nil,0
    FG.questieUpdatesRegistered=nil;FG.questTurnInWatch={id=100,phase="objectives"}
    FG.CheckQuestTurnIn=function() count=count+1 end
    _G.Questie={API={RegisterOnReady=function(fn)fn()end,RegisterForQuestUpdates=function(fn)callback=fn end}}
    FG:RegisterQuestieUpdates();FG:RegisterQuestieUpdates();assert(callback)
    callback(101);eq(count,0);callback(100);eq(count,1)
    FG.questTurnInWatch=nil;_G.Questie=oldQuestie;FG.questieUpdatesRegistered=oldRegistered;FG.CheckQuestTurnIn=oldCheck
end)

test("valid AI coordinate suggestion starts guidance only after its link is clicked",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    FG.livePending={targets={}}
    FG:LiveFinish({status="done",provider="fixture",model="fixture",text="Ungeprüfter Vorschlag. [FAI_LOCATION:1421:44.7:67.8:Beispielort]"})
    assert(not FG.nav);eq(FG.messageRoles[#FG.messageRoles],"target")
    local id=FG.chatTargetOrder[1];local target=FG.chatTargetLinks[id]
    eq(target.action,"navigate");eq(target.route.points[1].mapID,1421)
    assert(FG.messages[#FG.messages]:find("ungeprüft",1,true))
    assert(FG:OpenChatTarget("foreverai:"..id));assert(FG.nav);near(FG.nav.points[1].x,.447);FG:StopNavigation(true)
end)

test("AI coordinate suggestions reject invalid maps and coordinates and remain data",function()
    FG:StopNavigation(true);FG:ClearChat()
    local body,targets=FG:ExtractAiLocations("[FAI_LOCATION:999999:20:30:Unbekannt] [FAI_LOCATION:1421:101:30:Ungültig] [FAI_LOCATION:1421:20:30:|Hbad|hFake|h] /run test")
    eq(#targets,0);assert(body:find("/run test",1,true));assert(not FG.nav)
    local _,valid=FG:ExtractAiLocations("[FAI_LOCATION:1421:0:100:Nullpunkt]");eq(#valid,1)
end)

test("AI coordinate suggestion refuses starting guidance in combat",function()
    FG:StopNavigation(true);FG:ClearChat();local _,targets=FG:ExtractAiLocations("[FAI_LOCATION:1421:44:67:Test]")
    FG:AddChatTargets(targets);local id=FG.chatTargetOrder[1]
    state.combat=true;assert(not FG:OpenChatTarget("foreverai:"..id));assert(not FG.nav);state.combat=false
end)

test("active quest with no location falls back to live AI",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    local oldQuests,oldDB,oldWaypoint=FG.GetQuests,_G.LibQuestieDB,C_QuestLog.GetNextWaypoint
    FG.GetQuests=function()return {{id=181,title="Der Blick zu den Sternen"}} end
    _G.LibQuestieDB=nil;C_QuestLog.GetNextWaypoint=function()end
    FG:SubmitChat("Wo ist die Quest Der Blick zu den Sternen?")
    assert(FG.livePending);FG:LiveFinish(nil)
    FG.GetQuests=oldQuests;_G.LibQuestieDB=oldDB;C_QuestLog.GetNextWaypoint=oldWaypoint
end)

test("Goldhain coordinate question resolves and navigates locally",function()
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    assert(FG:SubmitChat("Bei welchen Koordinaten liegt Goldhain?"))
    assert(not FG.livePending);assert(FG.nav);eq(FG.nav.points[1].mapID,1429)
    near(FG.nav.points[1].x,.424);near(FG.nav.points[1].y,.666)
    local found=false;for _,line in ipairs(FG.messages) do if line:find("42.40 / 66.60",1,true) then found=true end end
    assert(found,"coordinates should appear in the chat")
    FG:StopNavigation(true)
end)

test("English Goldshire coordinates resolve to the same settlement",function()
    local targets=FG:ResolveChatTargets("What are the coordinates of Goldshire?")
    eq(#targets,1);eq(targets[1].route.points[1].mapID,1429)
    near(targets[1].route.points[1].x,.424);near(targets[1].route.points[1].y,.666)
end)

test("Goldshire qualifier does not replace an NPC or trainer target",function()
    local oldDB=_G.LibQuestieDB;_G.LibQuestieDB=nil
    local targets=FG:ResolveChatTargets("Wo ist der Trainer in Goldhain?")
    eq(#targets,0);_G.LibQuestieDB=oldDB
end)

test("QuestieDB area mappings are read as data without executing text",function()
    local oldDB=_G.LibQuestieDB
    _G.FAI_AREA_EXECUTED=nil
    _G.LibQuestieDB={Support={Get=function(name) if name=="ZoneDB" then return {private={areaIdToUiMapId="return {\n [98765] = 1421, -- zone\n [98766] = 1429,\n}; _G.FAI_AREA_EXECUTED = true",uiMapIdToAreaId="return {\n [1421] = 98765,\n [1429] = 98766,\n}"}} end end}}
    FG:InitQuestieAreaMap();eq(FG.KnownAreaMap[98765],1421);eq(FG.KnownAreaMap[98766],1429);assert(not _G.FAI_AREA_EXECUTED)
    FG.KnownAreaMap[98765]=nil;FG.KnownAreaMap[98766]=nil;_G.LibQuestieDB=oldDB
end)

test("subarea mapping without coordinate projection is not used as a point",function()
    local oldDB=_G.LibQuestieDB
    _G.LibQuestieDB={Support={Get=function()return {private={areaIdToUiMapId="return {\n [98764] = 1421,\n}",uiMapIdToAreaId="return {\n [1421] = 130,\n}"}} end}}
    FG:InitQuestieAreaMap();assert(not FG.KnownAreaMap[98764])
    _G.LibQuestieDB=oldDB
end)

test("client zone maps resolve locally and mark the center approximate",function()
    local oldChildren,oldEnum,oldInfo=C_Map.GetMapChildrenInfo,_G.Enum,C_Map.GetMapInfo
    _G.Enum={UIMapType={Zone=3,City=4,Dungeon=5}}
    C_Map.GetMapInfo=function(id) if id==1 then return {mapID=1,name="World",parentMapID=0} elseif id==1411 then return {mapID=id,name="Durotar",parentMapID=1} else return oldInfo(id) end end
    C_Map.GetMapChildrenInfo=function()return {{mapID=1411,name="Durotar",mapType=3},{mapID=1411,name="Durotar Dungeon",mapType=5}} end
    FG.clientMaps=nil;FG.clientMapRoot=nil
    local rows=FG:ClientMapResults("Wo ist Durotar?")
    eq(#rows,1);eq(rows[1].route.points[1].mapID,1411);assert(rows[1].detail:find("ungefähr",1,true))
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    FG:SubmitChat("Wo ist Durotar?");assert(FG.nav);eq(FG.nav.points[1].mapID,1411);assert(not FG.livePending)
    FG:StopNavigation(true);FG.clientMaps=nil;FG.clientMapRoot=nil;C_Map.GetMapInfo=oldInfo;C_Map.GetMapChildrenInfo=oldChildren;_G.Enum=oldEnum
end)

test("QuestieDB item names are incrementally indexed and resolve a local drop",function()
    local oldDB,oldNames,oldIndex,oldItems,oldNpcNames=_G.LibQuestieDB,FG.questieNames,FG.questieNpcIndex,FG.questieItemNames,FG.questieNpcNames
    _G.LibQuestieDB={Quest={GetAllIds=function()return {} end,name=function()end},
        Item={GetAllIds=function()return {222} end,name=function()return "Klinge des Testers" end,itemLevel=function()return 30 end,
            requiredLevel=function()return 20 end,npcDrops=function()return {777} end,objectDrops=function()return {} end,vendors=function()return {} end},
        Npc={GetAllIds=function()return {777} end,name=function()return "Testgegner" end,subName=function()return "" end,spawns=function()return {[130]={{40,50}}} end}}
    FG:InitQuestieEvidence();assert(FG.questieItemIndexFrame.scripts.OnUpdate)
    FG.questieItemIndexFrame.scripts.OnUpdate(FG.questieItemIndexFrame);assert(FG.questieItemIndexReady)
    local matches,rows=FG:QuestieItemResults("Wo finde ich Klinge des Testers?")
    eq(#matches,1);eq(matches[1].id,222);eq(#rows,1);eq(rows[1].route.points[1].mapID,1421)
    FG:StopNavigation(true);FG:ClearChat();FG.db.liveEnabled=true
    FG:SubmitChat("Was ist Klinge des Testers?");assert(not FG.livePending);assert(#FG.chatTargetOrder==1)
    FG:ClearChat();FG:SubmitChat("Wo finde ich Klinge des Testers?");assert(FG.nav);eq(FG.nav.points[1].mapID,1421);assert(not FG.livePending)
    FG:StopNavigation(true);_G.LibQuestieDB=oldDB;FG.questieNames=oldNames;FG.questieNpcIndex=oldIndex;FG.questieItemNames=oldItems;FG.questieNpcNames=oldNpcNames
end)

test("inactive named quest resolves its unique QuestieDB giver",function()
    local oldDB,oldNames=_G.LibQuestieDB,FG.questieNames
    _G.LibQuestieDB={Quest={questLevel=function()return 12 end,objectivesText=function()return {} end,startedBy=function()return {{777},{}} end},
        Npc={name=function()return "Questgeber" end,spawns=function()return {[130]={{40,50}}} end}}
    FG.questieNames={{id=999,name="Eine andere Quest",normalized="eine andere quest"}}
    local rows=FG:QuestieQuestResults("Wo ist Eine andere Quest?")
    eq(#rows,1);assert(rows[1].route);eq(rows[1].route.points[1].mapID,1421)
    _G.LibQuestieDB=oldDB;FG.questieNames=oldNames
end)

test("NPC lookup accepts natural coordinate questions for known full names",function()
    local oldDB,oldIndex=_G.LibQuestieDB,FG.questieNpcIndex
    _G.LibQuestieDB={Npc={GetAllIds=function()return {777} end,name=function()return "Testgegner" end,spawns=function()return {[130]={{40,50}}} end}}
    FG.questieNpcIndex={{id=777,name="Testgegner",sub="",canonicalName="testgegner",canonicalSub=""}}
    local rows=FG:QuestieNpcResults("Bei welchen Koordinaten liegt Testgegner?")
    eq(#rows,1);eq(rows[1].route.points[1].mapID,1421)
    _G.LibQuestieDB=oldDB;FG.questieNpcIndex=oldIndex
end)

test("named NPC lookup uses the full incremental name index",function()
    local oldDB,oldIndex,oldNames=_G.LibQuestieDB,FG.questieNpcIndex,FG.questieNpcNames
    local entry={id=777,name="Testgegner",sub="",normalized="testgegner",canonicalName="testgegner",canonicalSub=""}
    _G.LibQuestieDB={Npc={GetAllIds=function()return {} end,name=function()return "Testgegner" end,spawns=function()return {[130]={{40,50}}} end}}
    FG.questieNpcIndex={};FG.questieNpcNames={testgegner={entry}}
    local rows=FG:QuestieNpcResults("Wo finde ich Testgegner?");eq(#rows,1)
    _G.LibQuestieDB=oldDB;FG.questieNpcIndex=oldIndex;FG.questieNpcNames=oldNames
end)

test("item name index yields between batches",function()
    local oldDB,oldItems,oldNames,oldIndex,oldNpcNames=_G.LibQuestieDB,FG.questieItemNames,FG.questieNames,FG.questieNpcIndex,FG.questieNpcNames
    local ids={};for i=1,101 do ids[i]=i end
    local calls=0
    _G.LibQuestieDB={Quest={GetAllIds=function()return {} end,name=function()end},Item={GetAllIds=function()return ids end,name=function(id) calls=calls+1;return "Gegenstand "..id end}}
    FG.questieItemIndexReady=nil;FG:InitQuestieEvidence()
    FG.questieItemIndexFrame.scripts.OnUpdate(FG.questieItemIndexFrame);eq(calls,100);assert(not FG.questieItemIndexReady)
    FG.questieItemIndexFrame.scripts.OnUpdate(FG.questieItemIndexFrame);eq(calls,101);assert(FG.questieItemIndexReady)
    _G.LibQuestieDB=oldDB;FG.questieItemNames=oldItems;FG.questieNames=oldNames;FG.questieNpcIndex=oldIndex;FG.questieNpcNames=oldNpcNames
end)

test("area index reports a known zone without inventing a point",function()
    local oldDB,oldGet,oldAreas=_G.LibQuestieDB,C_Map.GetAreaInfo,FG.questieAreaNames
    _G.LibQuestieDB={Support={Get=function()return {private={areaIdToUiMapId="return {\n [98765] = 1421,\n}"}} end}}
    C_Map.GetAreaInfo=function(id) if id==98765 then return "Der Testhain" end end
    FG:InitQuestieAreaMap()
    while FG.questieAreaIndexFrame.scripts.OnUpdate do FG.questieAreaIndexFrame.scripts.OnUpdate(FG.questieAreaIndexFrame) end
    local rows=FG:ClientAreaResults("Wo ist Der Testhain?")
    eq(#rows,1);assert(not rows[1].route);assert(rows[1].detail:find("keine Ortskoordinaten",1,true))
    FG.KnownAreaMap[98765]=nil;_G.LibQuestieDB=oldDB;C_Map.GetAreaInfo=oldGet;FG.questieAreaNames=oldAreas
end)

print(string.format("\n%d tests passed. Environment: %s; simulated WoW APIs. No in-game verification.",total,_VERSION))
