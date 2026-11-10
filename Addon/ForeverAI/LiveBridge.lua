-- ForeverAI experimental two-way bridge for the Forever 16001 client.
-- Only visible pixels leave the WoW Lua sandbox. Data-only, preinstalled
-- LoadOnDemand addon slots deliver replies. No sockets, input automation,
-- file reads or executable user/AI text are used in the game.
local _,FG=...
local MAX_PAYLOAD=2750
local CELL,PER_ROW,MAX_ROWS=2,80,96
local SLOT_COUNT=120
local CHECKS={6,13,23,37,55,80,120,180}
local commands={test=true,hilfe=true,help=true,sprache=true,language=true,modell=true,model=true,reasoning=true,
 denken=true,navi=true,navigation=true,guide=true,wegfuehrung=true,wegfindung=true,pause=true,resume=true,
 hinweis=true,note=true,button=true,knopf=true,resetui=true,benchmark=true,testplan=true,clear=true,
 leeren=true,begriff=true,term=true,alias=true,daten=true,data=true,sync=true,stopp=true,
 stop=true,diagnose=true,merken=true,liste=true,entfernen=true,ziel=true,weiter=true,zurueck=true,
 karte=true,aufnahme=true,punkt=true,speichern=true,abbrechen=true,sichern=true,route=true,
 gehe=true,ausruestung=true,["ausrüstung"]=true,equipment=true,gear=true,taschen=true,tasche=true,
 bags=true,inventory=true,inventar=true,suche=true,search=true,find=true,quests=true,quest=true,
 import=true,export=true,routenexport=true,live=true,ki=true,modelle=true,models=true,position=true}
local function now() return type(GetTime)=="function" and GetTime() or 0 end
local function hexByte(b) return string.format("%%%02X",b) end
local function escape(s)
 return (tostring(s or ""):gsub("([^%w%-%._~])",function(c)return hexByte(c:byte()) end))
end
local function validText(s,max)
 if type(s)~="string" or #s>max or s:find("[%z\1-\8\11\12\14-\31]") then return false end
 return true
end
local function encodePacket(id,payload)
 if id<1 or id>65535 or type(payload)~="string" or #payload>MAX_PAYLOAD then return nil end
 local bytes={0xC7,0x1A,math.floor(id/256)%256,id%256,math.floor(#payload/256),#payload%256}
 for i=1,#payload do bytes[#bytes+1]=payload:byte(i) end
 local s1,s2=0,0
 for i=3,#bytes do s1=(s1+bytes[i])%255;s2=(s2+s1)%255 end
 bytes[#bytes+1]=s1;bytes[#bytes+1]=s2
 local bits,count,cells=0,0,{}
 for _,b in ipairs(bytes) do
  bits=bits*256+b;count=count+8
  while count>=3 do count=count-3;cells[#cells+1]=math.floor(bits/2^count)%8;bits=bits%2^count end
 end
 if count>0 then cells[#cells+1]=bits*2^(3-count) end
 if #cells>PER_ROW*MAX_ROWS then return nil end
 return cells
end
FG.LiveEncodePacket=encodePacket
FG.LiveEncodeText=escape
function FG:IsLocalCommand(text)
 local head=FG.Normalize((text or ""):match("^(%S+)") or "")
 return commands[head]==true
end
function FG:LiveStatus()
 local active=self.db and self.db.liveEnabled
 local pending=self.livePending
 local de=self.locale=="deDE"
 local prefix=active and (de and "Live-KI: EIN" or "Live AI: ON") or (de and "Live-KI: AUS" or "Live AI: OFF")
 if pending then return prefix..(de and " · Anfrage wartet auf Begleit-App" or " · waiting for companion") end
 return prefix..(de and " · nur mit laufender, eingerichteter Begleit-App" or " · requires configured, running companion")
end
function FG:LiveCommand(arg)
 if not self.db then return end
 local s=FG.Normalize(arg or "")
 if s=="an" or s=="ein" or s=="on" or s=="enable" then self.db.liveEnabled=true
 elseif s=="aus" or s=="off" or s=="disable" then
  self.db.liveEnabled=false
  self:LiveFinish(nil)
 elseif s~="" and s~="status" then self:Say(self.locale=="deDE" and "Befehl: /fai live an|aus|status" or "Command: /fai live on|off|status");return end
 self:Say(self:LiveStatus())
 if self.UpdateLiveButton then self:UpdateLiveButton() end
end
local function context(self,question)
 if self.db and self.db.shareContext==false then return "" end
 local c,l=FG.Safe(UnitClass,"player"),FG.Safe(UnitLevel,"player")
 local faction=FG.Safe(UnitFactionGroup,"player")
 local v,build,_,interface=FG.Safe(GetBuildInfo)
 local parts={"WoW Forever; client="..tostring(v).."; build="..tostring(build).."; interface="..tostring(interface),
  "class="..FG.Clean(c or "?",32).."; level="..tostring(l or "?").."; faction="..FG.Clean(faction or "?",20)}
 if self.liveNavigationContext then parts[#parts+1]=self.liveNavigationContext end
 local p=self.PlayerPoint and self:PlayerPoint()
 if p then
  local info=FG.Safe(C_Map and C_Map.GetMapInfo,p.mapID)
  local zone=type(info)=="table" and info.name
  local name=type(zone)=="string" and not FG.IsSecret(zone) and ("; zone="..FG.Clean(zone,60)) or ""
  parts[#parts+1]=string.format("WoW client position: map=%d; x=%.2f; y=%.2f",p.mapID,p.x*100,p.y*100)..name
 end
 for i,target in ipairs(self.liveLookupTargets or {}) do
  if i>2 then break end
  local p=target.route and target.route.points and target.route.points[1]
  if p then
   parts[#parts+1]=string.format("Map target: %s; source=%s; map=%d; x=%.1f; y=%.1f; %s",FG.Clean(target.name,60),FG.Clean(target.source,30),p.mapID,p.x*100,p.y*100,FG.Clean(target.detail,75))
  end
 end
 -- Include a bounded summary of equipped items only for explicit gear questions.
 local q=FG.Normalize(question or "")
 if self.EquipmentText and (q:find("waffe",1,true) or q:find("schwert",1,true) or q:find("item",1,true) or q:find("weapon",1,true) or q:find("gear",1,true) or q:find("ausruestung",1,true)) then
  local gear=FG.Clean(self:EquipmentText(),700)
  if gear~="" then parts[#parts+1]=gear end
 end
 if self.QuestieEvidence then
  local evidence=self:QuestieEvidence(question)
  if evidence~="" then parts[#parts+1]=evidence end
 end
 if self.GameEvidence then
  local evidence=self:GameEvidence(question)
  if evidence~="" then parts[#parts+1]=evidence end
 end
 -- No character name, chat logs, coordinates from other players or secrets.
 return table.concat(parts,"\n")
end
function FG:LiveMakePacket(text)
 if not validText(text,512) then return nil,"invalid_question" end
 local ai=self.db and self.db.ai or {}
 local model=tostring(ai.model or "auto");local effort=tostring(ai.effort or "default")
 -- A stored provider accompanies its model so the companion can detect a
 -- stale catalog after the user switches providers. The companion decides.
 local provider=tostring(ai.provider or "auto")
 if not model:match("^[%w_%.%/:%+@~%-]+$") or #model>180 then model="auto" end
 if not effort:match("^[a-z]+$") or #effort>12 then effort="default" end
 if not (self.db and type(self.db.catalog)=="string") then model="auto";provider="auto";effort="default" end
 if text=="__foreverai_catalog__" then provider="auto";model="auto";effort="default" end
 if not provider:match("^[a-z]+$") or #provider>20 then provider="openrouter" end
 local lang=self.locale=="deDE" and "de" or "en"
 local session=self.liveSession or "";local id=self.liveId or 0
 local prefix="FAI1;"..session..";"..id..";"..provider..";"..model..";"..effort..";"..lang..";"..escape(text)..";"
 local ctx=context(self,text)
 -- Leave room for percent encoding and never split a UTF-8 character.
 while #ctx>1200 or (#prefix+#escape(ctx))>MAX_PAYLOAD do
  if ctx=="" then break end
  ctx=ctx:gsub("[\128-\191]*$",""):sub(1,-2)
 end
 local body=prefix..escape(ctx)
 if #body>MAX_PAYLOAD then return nil,"question_too_long" end
 return body
end
function FG:LiveCreateStrip()
 if self.liveStrip then return self.liveStrip end
 local f=CreateFrame("Frame","ForeverAIPixelBridge",UIParent)
 f:SetFrameStrata("TOOLTIP");f:SetPoint("TOPLEFT",UIParent,"TOPLEFT",0,0)
 if UIParent and type(UIParent.GetEffectiveScale)=="function" then
  local sc=UIParent:GetEffectiveScale()
  if type(sc)=="number" and sc>0 then f:SetScale(1/sc) end
 end
 f:SetSize(PER_ROW*CELL,MAX_ROWS*CELL)
 local timer,pulse=0,0
 f:SetScript("OnUpdate",function(frame,dt)
  timer=timer+(dt or 0);pulse=(pulse+(dt or 0))%3
  frame:SetAlpha(pulse<1 and 1 or 0)
  if timer>=0.35 then timer=0;self:LiveTick() end
 end)
 f.textures={};f:Hide()
 self.liveStrip=f
 return f
end
function FG:LiveDraw(cells)
 local f=self:LiveCreateStrip()
 for i,v in ipairs(cells) do
  local t=f.textures[i]
  if not t then
   t=f:CreateTexture(nil,"OVERLAY");t:SetSize(CELL,CELL)
   local col=(i-1)%PER_ROW;local row=math.floor((i-1)/PER_ROW)
   t:SetPoint("TOPLEFT",f,"TOPLEFT",col*CELL,-row*CELL)
   f.textures[i]=t
  end
  t:SetColorTexture(math.floor(v/4)%2,math.floor(v/2)%2,v%2,1)
  t:Show()
 end
 for i=#cells+1,(f.used or 0) do f.textures[i]:Hide() end
 f.used=#cells;f:Show()
end
-- AI suggestions are strictly parsed as data and can never start navigation
-- without a click. Map validity is not evidence that the location is correct.
function FG:ExtractAiLocations(text)
 if type(text)~="string" then return "",{} end
 local targets={}
 local cleaned=text:gsub("%[FAI_LOCATION:(%d+):(%d+%.?%d*):(%d+%.?%d*):([^%[%]|:\r\n]+)%]",function(map,x,y,name)
  local mapID,xp,yp=tonumber(map),tonumber(x),tonumber(y)
  if #targets>=3 or not FG.IsNumber(mapID) or not FG.IsNumber(xp) or not FG.IsNumber(yp) or xp<0 or xp>100 or yp<0 or yp>100 then return nil end
  name=FG.Clean(name,80)
  if name=="" then return nil end
  local note=self.locale=="deDE" and "KI-Koordinaten ungeprüft" or "Unverified AI coordinates"
  local route=self:CheckRoute({name=name,kind="waypoint",points={{mapID=mapID,x=xp/100,y=yp/100,label=name,note=note}}})
  if not route then return nil end
  targets[#targets+1]={name=name,source="AI",action="navigate",detail=string.format("%s · %d · %.1f / %.1f",note,mapID,xp,yp),route=route}
  return ""
 end)
 return cleaned,targets
end

function FG:LiveFinish(reply)
 local p=self.livePending
 if self.liveStrip then self.liveStrip:Hide() end
 self.livePending=nil
 if not p then return end
 if reply then
  if reply.status=="done" then
   local body,aiTargets=self:ExtractAiLocations(reply.text)
   local safe=FG.Clean(body,4800)
   if safe=="" then safe="(empty reply)" end
   self:AddChatMessage("ai_live",(reply.provider or "AI").." / "..(reply.model or "").."\n"..safe)
   if p.targets and self.AddChatTargets then self:AddChatTargets(p.targets) end
   if (not p.targets or #p.targets==0) and self.AddChatTargets then self:AddChatTargets(aiTargets) end
   if self.window then self.window:Show() end
   -- A user may click "Ziele suchen" to locate trustworthy local destinations.
  else
   self:AddChatMessage("local",self.locale=="deDE" and "KI-Fehler: "..FG.Clean(reply.text,400) or "AI error: "..FG.Clean(reply.text,400))
  end
 end
end
function FG:LiveReadSlot()
 local p=self.livePending;if not p then return false end
 if (self.liveNextSlot or 0)>=SLOT_COUNT then
  self:LiveFinish({status="error",text=self.locale=="deDE" and "Antwort-Slots aufgebraucht. /reload setzt sie zurück." or "Reply slots exhausted. /reload resets them."})
  return false
 end
 self.liveNextSlot=(self.liveNextSlot or 0)+1
 local name=string.format("ForeverAI_R%03d",self.liveNextSlot)
 local loader=(C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
 if type(loader)~="function" then
  self:LiveFinish({status="error",text="C_AddOns.LoadAddOn unavailable"});return false
 end
 ForeverAI_LiveSlot=nil
 local ok,loaded=pcall(loader,name)
 if not ok or loaded==false then
  if self.liveNextSlot==1 then self:LiveFinish({status="error",text=self.locale=="deDE" and "Reply-Slots fehlen. Brücke einrichten und WoW vollständig neu starten." or "Reply slots missing. Configure bridge and fully restart WoW."}) end
  return false
 end
 local data=ForeverAI_LiveSlot
 ForeverAI_LiveSlot=nil
 if type(data)~="table" or data.schema~=1 or data.session~=p.session or data.id~=p.id then return false end
 if data.status~="done" and data.status~="error" then return false end
 if not validText(data.text,6000) or type(data.provider)~="string" or type(data.model)~="string" then return false end
 if data.catalog and type(data.catalog)=="string" then
  local parsed=FG.ParseCatalog(data.catalog)
  if parsed then self:ApplyCatalog(parsed) end
 end
 self:LiveFinish(data)
 return true
end
function FG:LiveTick()
 local p=self.livePending;if not p then return end
 local elapsed=now()-p.started
 if elapsed>180 then
  self:LiveFinish({status="error",text=self.locale=="deDE" and "Zeitüberschreitung. Läuft die Begleit-App? Prüfe ihre Live-Statusanzeige." or "Timed out. Is the companion running? Check live status."})
  return
 end
 if elapsed<(p.nextCheck or 0) then return end
 p.nextCheck=elapsed+0.45
 local triggered=false
 if not p.signalSeen and type(PlaySoundFile)=="function" then
  local filename=string.format("Interface\\AddOns\\ForeverAI\\LiveSignals\\r%03d.wav",(p.id-1)%SLOT_COUNT+1)
  local ok,playable=pcall(PlaySoundFile,filename,"Master")
  triggered=ok and playable==true
  if triggered then p.signalSeen=true end
 end
 local nextTime=CHECKS[p.checkIndex or 1] or (180)
 if triggered or elapsed>=nextTime then
  p.checkIndex=(p.checkIndex or 1)+1
  self:LiveReadSlot()
 end
end
function FG:LiveQuestion(text)
 if not self.db or self.db.liveEnabled~=true then return false end
 if self.livePending then self:Say(self.locale=="deDE" and "Eine KI-Anfrage läuft bereits." or "An AI request is already running.");return true end
 -- A new, ephemeral session avoids replaying a request after reload, and the
 -- bridge also checks the (session,id) pair to drop duplicated capture frames.
 if not self.liveSession then
  local clock=type(time)=="function" and time() or 1
  self.liveSession=string.format("%08x%06x",clock%4294967295,math.random(0,16777215))
 end
 self.liveId=(self.liveId or 0)+1
 if self.liveId>65535 then self.liveSession=nil;self.liveId=1 end
 local targets={}
 if text~="__foreverai_catalog__" and self.ResolveChatTargets then
  local ok,found=pcall(self.ResolveChatTargets,self,text)
  if ok and type(found)=="table" then targets=found end
 end
 local q=" "..FG.Normalize(text).." "
 local startRequested=(q:find(" starten ",1,true) or q:find(" starte ",1,true) or q:find(" start ",1,true) or q:find(" begin ",1,true))
  and (q:find(" wegfuehrung ",1,true) or q:find(" navigation ",1,true) or q:find(" route ",1,true) or q:find(" guidance ",1,true))
 if startRequested then
  if #targets==1 then
   local ok,started,why=pcall(self.StartNavigation,self,targets[1].route)
   if ok and started then
    local mode=self.nav and self.nav.spf and "Shortest Path Forever" or "straight-line direction only, no calculated walking route"
    self.liveNavigationContext="ForeverAI navigation started for locally resolved target: "..FG.Clean(targets[1].name,80).."; mode: "..mode..". The destination may be an approximate approach; do not claim the character moves automatically."
   else
    self.liveNavigationContext="ForeverAI navigation did not start."
    self:Say((self.locale=="deDE" and "Wegführung konnte nicht gestartet werden: " or "Could not start guidance: ")..FG.Clean(ok and why or started,200))
   end
  else
   self.liveNavigationContext="ForeverAI navigation did not start because the target was missing or ambiguous."
   self:Say(self.locale=="deDE" and "Wegführung nicht gestartet: Bitte ein eindeutiges Ziel nennen oder einen Treffer auswählen." or "Guidance not started: Name one unambiguous destination or select a result.")
  end
 end
 self.liveLookupTargets=targets
 local packet,err=self:LiveMakePacket(text)
 self.liveLookupTargets=nil
 self.liveNavigationContext=nil
 if not packet then self:Say("Live-KI: "..tostring(err));return true end
 local cells=encodePacket(self.liveId,packet)
 if not cells then self:Say("Live-KI: packet_too_large");return true end
 self.livePending={session=self.liveSession,id=self.liveId,started=now(),checkIndex=1,nextCheck=0,targets=targets}
 self:LiveDraw(cells)
 self:Say(self.locale=="deDE" and "Live-KI: Frage an die Begleit-App bereitgestellt. Warte auf Antwort …" or "Live AI: Question ready for companion. Waiting for response …")
 return true
end
