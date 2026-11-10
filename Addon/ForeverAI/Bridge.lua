-- Manual data-only bridge. No HTTP, clipboard polling, credentials, macros or Lua evaluation.
local _,FG=...
local T=FG.T
local providers={chatgpt=true,openrouter=true,gemini=true,groq=true,mistral=true,ollama=true,openai=true,anthropic=true,custom=true,web=true}
local efforts={default=true,none=true,minimal=true,low=true,medium=true,high=true,xhigh=true,max=true}
FG.EffortLabels.minimal="Minimal"
local function modelID(s)
    return type(s)=="string" and #s>0 and #s<=200 and s:match("^[A-Za-z0-9][A-Za-z0-9_./:+@~%-]*$")~=nil
end
local function validUTF8(s)
    local i=1
    while i<=#s do
        local a=s:byte(i); local count=0
        if a<128 then count=1
        elseif a>=194 and a<=223 then count=2
        elseif a>=224 and a<=239 then count=3
        elseif a>=240 and a<=244 then count=4
        else return false end
        if i+count-1>#s then return false end
        for j=1,count-1 do local b=s:byte(i+j);if b<128 or b>191 then return false end end
        local b=s:byte(i+1)
        if (a==224 and b<160) or (a==237 and b>159) or (a==240 and b<144) or (a==244 and b>143) then return false end
        i=i+count
    end
    return true
end
local function decode(s)
    local parts,i={},1
    while i<=#s do
        local c=s:sub(i,i)
        if c=="%" then local hex=s:sub(i+1,i+2);if #hex~=2 or not hex:match("^%x%x$") then return nil end;parts[#parts+1]=string.char(tonumber(hex,16));i=i+3
        else parts[#parts+1]=c;i=i+1 end
    end
    local result=table.concat(parts)
    if not validUTF8(result) or result:find("[%z\1-\8\11\12\14-\31\127]") then return nil end
    return result
end
local function lines(text)
    if type(text)~="string" or #text>FG.MAX_IMPORT then return nil end
    local result={}
    for line in (text.."\n"):gmatch("([^\n]*)\n") do
        line=FG.Trim(line:gsub("\r",""))
        if line~="" and line~="```" and line~="```text" then result[#result+1]=line end
    end
    return result
end
function FG.ParseReply(text)
    local list=lines(text)
    if not list or #list<3 or list[#list]~="END" then return nil,T("Ungültiger Antwortblock.") end
    local provider,model=list[1]:match("^FGA1;([a-z]+);([^;]+)$")
    if not providers[provider] or not modelID(model) then return nil,T("Ungültiger Antwortblock.") end
    local chunks,size={},0
    for i=2,#list-1 do
        local encoded=list[i]:match("^T;(.*)$");local value=encoded and decode(encoded)
        if not value then return nil,T("Ungültiger Antwortblock.") end
        size=size+#value;if size>8000 then return nil,T("Antwort ist zu groß.") end
        for line in (value.."\n"):gmatch("([^\n]*)\n") do chunks[#chunks+1]=FG.Clean(line,8000) end
    end
    local answer=table.concat(chunks,"\n")
    if FG.Trim(answer)=="" then return nil,T("Ungültiger Antwortblock.") end
    return {bridgeType="reply",provider=provider,model=model,text=answer}
end
function FG.ParseCatalog(text)
    local list=lines(text)
    if not list or #list<3 or list[#list]~="END" then return nil,T("Ungültiger Modellkatalog.") end
    local provider=list[1]:match("^FGC1;([a-z]+)$")
    if not providers[provider] or provider=="web" then return nil,T("Ungültiger Modellkatalog.") end
    local models,seen={},{}
    for i=2,#list-1 do
        local id,encoded,levels=list[i]:match("^M;([^;]+);([^;]*);([a-z,]+)$")
        local name=encoded and decode(encoded)
        if not modelID(id) or id=="auto" or seen[id] or not name then return nil,T("Ungültiger Modellkatalog.") end
        local allowed,used={},{}
        for e in (levels..","):gmatch("(.-),") do
            if not efforts[e] or used[e] then return nil,T("Ungültiger Modellkatalog.") end
            allowed[#allowed+1]=e;used[e]=true
        end
        if not used.default then return nil,T("Ungültiger Modellkatalog.") end
        models[#models+1]={id=id,name=FG.Clean(name,180),efforts=allowed};seen[id]=true
        if #models>80 then return nil,T("Ungültiger Modellkatalog.") end
    end
    if #models==0 then return nil,T("Ungültiger Modellkatalog.") end
    return {bridgeType="catalog",provider=provider,models=models,raw=text}
end
function FG:ApplyReply(reply)
    if type(reply)~="table" or reply.bridgeType~="reply" then return false end
    -- Display only; imported text never invokes Ask(), macros, or navigation.
    self:AddChatMessage("ai",reply.provider.." / "..reply.model.."\n"..reply.text)
    if self.window then self.window:Show() end
    return true
end
function FG:ApplyCatalog(catalog)
    if type(catalog)~="table" or catalog.bridgeType~="catalog" then return false end
    local validated=FG.ParseCatalog(catalog.raw);if not validated then return false end
    self.db.catalog=validated.raw;self.ModelCandidates=validated.models
    local old=self.db.ai or {};local model=self:FindModel(old.model) and old.model or validated.models[1].id
    self.db.ai={provider=validated.provider,model=model,effort=self:SupportsEffort(model,old.effort) and old.effort or "default"}
    if self.RefreshAIControls then self:RefreshAIControls() end
    self:Say(self.db.liveEnabled and "Live-Modellliste aktualisiert. Die Auswahl gilt für kommende KI-Fragen." or T("Modellkatalog übernommen. Auswahl beim nächsten KI-Export in der Begleit-App bestätigen."))
    return true
end
local legacyModels=FG.ModelCandidates
local init=FG.InitPreferences
function FG:InitPreferences()
    local c=type(self.db.catalog)=="string" and FG.ParseCatalog(self.db.catalog)
    if c then self.ModelCandidates=c.models else self.db.catalog=nil;self.ModelCandidates=legacyModels end
    init(self)
    self.db.ai.provider=c and c.provider or "chatgpt"
    if not self:SupportsEffort(self.db.ai.model,self.db.ai.effort) then self.db.ai.effort="default" end
end

-- FGS1 is a bounded, non-executable lookup-result format from the local
-- companion. Imported source claims are untrusted; only known addon positions
-- or actual client quest waypoints can enable navigation.
function FG.ParseOnlineResults(text)
    local data=lines(text)
    if not data or #data<3 or data[#data]~="END" then return nil,T("Ungültige Online-Suchergebnisse.") end
    local updated,encodedQuery=data[1]:match("^FGS1;forevercompanion;([^;]+);(.*)$")
    if not updated or #updated>50 or (updated~="unknown" and not updated:match("^%d%d%d%d%-%d%d%-%d%dT[%d%:%-%.Z%+]+$")) then
        return nil,T("Ungültige Online-Suchergebnisse.")
    end
    local query=decode(encodedQuery)
    if not query or #query>700 then return nil,T("Ungültige Online-Suchergebnisse.") end
    local rows={}
    for i=2,#data-1 do
        local kind,id,target,name,detail=data[i]:match("^R;([DIQR]);([%w_%-]+);([a-z0-9%-]+);([^;]*);([^;]*)$")
        if not kind or #id>80 or #target>80 or #name>1200 or #detail>2000 then return nil,T("Ungültige Online-Suchergebnisse.") end
        name,detail=decode(name),decode(detail)
        if not name or name=="" or not detail then return nil,T("Ungültige Online-Suchergebnisse.") end
        if target=="-" then target="" end
        rows[#rows+1]={kind=kind,id=id,target=target,name=FG.Clean(name,125),detail=FG.Clean(detail,210)}
        if #rows>24 then return nil,T("Zu viele Online-Suchergebnisse.") end
    end
    if #rows==0 then return nil,T("Keine Online-Suchergebnisse.") end
    return {bridgeType="online",updatedAt=updated,query=FG.Clean(query,180),rows=rows}
end

local dungeonKeys={
    ["deadmines"]="deadmines",["the-deadmines"]="deadmines",
    ["shadowfang-keep"]="shadowfang",["shadowfang"]="shadowfang",
    ["wailing-caverns"]="wailing",["gnomeregan"]="gnomeregan",
    ["the-stockade"]="stockades",["the-stockades"]="stockades",["stockades"]="stockades",
    ["ragefire-chasm"]="ragefire",["hall-of-thanes"]="thanes",
}
function FG:OnlineRoute(result)
    if result.kind=="Q" then
        local questID=tonumber(result.id)
        if not questID then return nil end
        local known=false
        for _,q in ipairs(self:GetQuests()) do if q.id==questID then known=true;break end end
        if not known then return nil end
        local map,x,y=FG.Safe(C_QuestLog and C_QuestLog.GetNextWaypoint,questID)
        local p=FG.ValidatePoint({mapID=map,x=x,y=y,label=result.name,kind="quest"})
        if not p or not self:MapInfo(p.mapID) then return nil end
        return {name=result.name,points={p},kind="quest",questID=questID}
    end
    if result.kind~="D" and result.kind~="I" then return nil end
    local key=dungeonKeys[result.target]
    local loc=key and self:LocateDungeonByKey(key)
    if not loc then return nil end
    local title=result.name.." — "..(self.locale=="deDE" and "Dungeon-Anreise" or "Dungeon approach")
    local note=self.locale=="deDE" and "Ungefähre Außenannäherung; keinen sicheren Fußweg oder Bossweg ableiten." or
        "Approximate outdoor approach; not a verified walking or boss route."
    local p=FG.ValidatePoint({mapID=loc.mapID,x=loc.x/100,y=loc.y/100,label=loc.de,
        kind="dungeon",note=note})
    if not p or not self:MapInfo(p.mapID) then return nil end
    return {name=title,points={p},kind="dungeon"}
end
function FG:ApplyOnlineResults(lookup)
    if type(lookup)~="table" or lookup.bridgeType~="online" then return false end
    self.destination=nil
    if self.RefreshDestination then self:RefreshDestination() end
    local results={}
    for _,r in ipairs(lookup.rows) do
        results[#results+1]={name=r.name,detail=r.detail,route=self:OnlineRoute(r),
            source="Forever Companion (laut Import) · "..lookup.updatedAt,kind=r.kind}
    end
    if not self:ShowSearchResults(results,lookup.query) then return false end
    if self.window then self.window:Show() end
    self:Say((self.locale=="deDE" and "Online-Suchergebnisse übernommen: " or "Online lookup imported: ")..
        #results..(self.locale=="deDE" and ". Treffer anklicken. Ohne Kartenpunkt keine Wegführung." or ". Click a result. No position, no navigation."))
    return true
end
