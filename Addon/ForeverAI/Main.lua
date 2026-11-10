local addonName, FG = ...
local T = FG.T
local events = CreateFrame("Frame")

local function guarded(fn,...)
    local ok,err=pcall(fn,...)
    if not ok then
        err=tostring(err)
        if FG.lastError~=err then
            FG.lastError=err
            FG:Say(T("Interner Fehler: ") .. FG.Clean(err,300) .. T(" · Bericht mit /fai diagnose."))
        end
        if FG.arrow then FG:ArrowState(nil,nil,T("Fehler · /fai diagnose")) end
    end
end

local function initialize()
    -- WoW saves variables per addon file, not just by variable name. Copying the
    -- old SavedVariables file into the new addon's file is optional (see MIGRATION).
    -- When present in the new file, the old table is migrated without executing strings.
    if type(ForeverAIDB)~="table" then
        ForeverAIDB=type(ForeverGuideDB)=="table" and ForeverGuideDB or {}
    end
    -- Stop persisting the obsolete name in the new addon SavedVariables file.
    ForeverGuideDB=nil
    FG.db=ForeverAIDB
    FG.db.schema=4
    if FG.db.liveEnabled==nil then FG.db.liveEnabled=false end
    FG:InitLanguage()
    FG:InitPreferences()
    if type(FG.db.questAliases)~="table" then FG.db.questAliases={} end
    if type(FG.db.places)~="table" then FG.db.places={} end
    if type(FG.db.routes)~="table" then FG.db.routes={} end
    for id,names in pairs(FG.db.questAliases) do
        if not FG.IsNumber(id) or id<1 or id>1000000 or id%1~=0 or type(names)~="table" then
            FG.db.questAliases[id]=nil
        else
            local clean={}
            for _,name in ipairs(names) do
                if type(name)=="string" and FG.Normalize(name)~="" and #clean<10 then clean[#clean+1]=FG.Clean(name,180) end
            end
            FG.db.questAliases[id]=clean
        end
    end
    -- Drop invalid old records without ever evaluating stored strings as code.
    for key,p in pairs(FG.db.places) do
        local clean=FG.ValidatePoint(p)
        if type(key)~="string" or not clean then FG.db.places[key]=nil else FG.db.places[key]=clean end
    end
    for key,r in pairs(FG.db.routes) do
        local valid=type(key)=="string" and type(r)=="table" and type(r.points)=="table" and type(r.name)=="string"
        if valid then
            valid=#r.points>0 and #r.points<=FG.MAX_POINTS
            for i,p in ipairs(r.points) do local clean=FG.ValidatePoint(p); if not clean then valid=false; break else r.points[i]=clean end end
            r.name=FG.Clean(r.name,100)
        end
        if not valid then FG.db.routes[key]=nil end
    end
    SLASH_FOREVERAI1="/fai"
    SLASH_FOREVERAI2="/foreverai"
    SlashCmdList.FOREVERAI=function(msg) guarded(FG.Ask,FG,msg) end
end

local function onEvent(_,event,arg1)
    if event=="ADDON_LOADED" and arg1==addonName then
        initialize()
    elseif event=="ADDON_LOADED" and arg1=="Questie" and FG.db then
        FG:RegisterQuestieUpdates()
    elseif event=="PLAYER_LOGIN" and FG.db then
        if FG.InitQuestieAreaMap then FG:InitQuestieAreaMap() end
        if FG.InitQuestieEvidence then FG:InitQuestieEvidence() end
        FG:RegisterQuestieUpdates()
        FG:CreateMain()
        FG:CreateLauncher()
        FG:Say(T("Version ") .. FG.VERSION .. T(" geladen. /fai öffnet das Fenster; /fai test prüft Marker und Pfeil. Keine KI-Anmeldung nötig."))
        if FG.SyncData and FG.SyncData.syncedAt and FG.SyncData.syncedAt~="" then FG:Say(FG:SyncedDataStatus()) end
        local _,_,_,interface=GetBuildInfo()
        if interface~=FG.INTERFACE then FG:Say(T("Hinweis: Dieser Build zielt auf Interface 16001. Dein Client meldet ") .. tostring(interface) .. ".") end
        if not FG.db.welcomed then FG.db.welcomed=true; FG.window:Show() end
    elseif event=="USER_WAYPOINT_UPDATED" and FG.db then
        FG:OnPinChanged()
    elseif event=="PLAYER_REGEN_ENABLED" and FG.db then
        FG:CheckQuestTurnIn()
        FG:Tick()
    elseif event=="SUPER_TRACKING_CHANGED" and FG.db then
        FG:OnSuperTrackingChanged()
    elseif (event=="QUEST_LOG_UPDATE" or event=="QUEST_WATCH_UPDATE") and FG.db then
        if FG.nav and FG.nav.questID then FG.nav.questDirty=true end
        FG:CheckQuestTurnIn()
    elseif (event=="QUEST_TURNED_IN" or event=="QUEST_REMOVED") and FG.db then
        if FG.questTurnInWatch and FG.questTurnInWatch.id==arg1 then FG.questTurnInWatch=nil end
    elseif event=="PLAYER_LOGOUT" and FG.db then
        -- Do not leave an addon-owned native pin behind on a normal logout/reload.
        if FG.window then FG:SaveWidgetPosition(FG.window,"window") end
        if FG.launcher then FG:SaveWidgetPosition(FG.launcher,"launcher") end
        if FG.arrow then FG:SaveWidgetPosition(FG.arrow,"arrow") end
        if FG.searchFrame then FG:SaveWidgetPosition(FG.searchFrame,"search") end
        FG:StopNavigation(true)
    end
end

events:SetScript("OnEvent",function(...) guarded(onEvent,...) end)
for _,event in ipairs({"ADDON_LOADED","PLAYER_LOGIN","PLAYER_LOGOUT","USER_WAYPOINT_UPDATED","PLAYER_REGEN_ENABLED","SUPER_TRACKING_CHANGED","QUEST_LOG_UPDATE","QUEST_WATCH_UPDATE","QUEST_TURNED_IN","QUEST_REMOVED"}) do
    pcall(events.RegisterEvent,events,event)
end
local elapsed=0
events:SetScript("OnUpdate",function(_,dt)
    if not FG.db or (not FG.nav and not FG.pendingRestore) or (FG.nav and FG.nav.spf and not FG.pendingRestore) then return end
    elapsed=elapsed+dt
    if elapsed<0.2 then return end
    elapsed=0
    guarded(FG.Tick,FG)
end)
