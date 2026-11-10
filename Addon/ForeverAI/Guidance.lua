-- Opt-in destination preview, waypoint guidance, and local HUD state.
-- No mesh/path solver, camera access, movement commands, or invented coordinates.
local _, FG = ...
local T = FG.T
FG.KindLabels={waypoint="Wegpunkt",quest="Questziel",trainer="Lehrer",dungeon="Dungeoneingang",travel="Übergang"}

function FG.DestinationKind(route)
    if route.kind and FG.KindLabels[route.kind] then return route.kind end
    if route.questID then return "quest" end
    local final=route.points and route.points[#route.points]
    if final and final.kind then return final.kind end
    local text=FG.Normalize(route.name)
    if text:find("lehrer",1,true) or text:find("trainer",1,true) then return "trainer" end
    if text:find("dungeon",1,true) or text:find("eingang",1,true) or text:find("entrance",1,true) then return "dungeon" end
    return "waypoint"
end

function FG.RouteMode(route)
    return #route.points>1 and "Zwischenpunkt-Route · Begehbarkeit ungeprüft" or "Nur Zielrichtung · kein berechneter Fußweg"
end

function FG:OfferNavigation(route)
    local clean,err=self:CheckRoute(route)
    if not clean then self:Say(err); return nil,err end
    self.destination=clean
    self:CreateMain(); self:RefreshDestination(); self.window:Show()
    self:Say(T("Ziel gefunden: %s. Mit Wegführung starten aktivieren.",clean.name))
    return true
end

function FG:RefreshDestination()
    if not self.destinationTitle then return end
    local r=self.destination or self.nav
    if r then
        self.destinationTitle:SetText(T(self.destination and "Ausgewählt: %s" or "Aktiv: %s",FG.Clean(r.name,80)))
        local path=_G.ShortestPathForever and _G.ShortestPathForever.API
        local mode=path and (self.locale=="deDE" and "Wegberechnung: Shortest Path Forever" or "Route planning: Shortest Path Forever") or T(FG.RouteMode(r))
        self.destinationDetails:SetText(T(FG.KindLabels[FG.DestinationKind(r)]).." · "..#r.points..T(" Punkt(e)").."\n"..mode)
        self.guideButton:SetText(T(self.destination and "Wegführung starten" or "Wegführung anzeigen")); self.guideButton:Enable()
    else
        self.destinationTitle:SetText(T("Noch kein Ziel ausgewählt"))
        self.destinationDetails:SetText(T("Suche eine Quest oder einen gespeicherten Ort. Ohne Koordinaten wird keine Wegführung angeboten."))
        self.guideButton:SetText(T("Wegführung starten")); self.guideButton:Disable()
    end
end

function FG:StartDestination()
    if self.destination then
        -- Re-read quest coordinates at acceptance time; a preview may have become stale.
        local route=self.destination
        if route.questID then
            local q=self:QuestRoute(route.questID)
            if not q then self.destination=nil; self:RefreshDestination(); self:Say(T("Das Questziel ist nicht mehr verfügbar. Bitte erneut suchen.")); return false end
            route=q
        end
        local ok,err=self:StartNavigation(route)
        if not ok then self:Say(err); return false end
        self.destination=nil; self:RefreshDestination()
        return true
    end
    if self.nav then if self.arrow and not self.nav.spf then self.arrow:Show() end; return true end
    self:Say(T("Noch kein Ziel ausgewählt")); return false
end

function FG:PauseNavigation(value)
    if not self.nav then self:Say(T("Keine Navigation aktiv.")); return end
    if self.nav.spf then
        local nav=self.nav
        local pause=value==nil and not nav.paused or value==true
        local api=_G.ShortestPathForever and _G.ShortestPathForever.API
        if not api then self:Say(T("Wegführung nicht verfügbar.")); return end
        if pause then
            local index=type(api.CurrentStop)=="function" and api.CurrentStop("ForeverAI") or nil
            nav.index=index or nav.index or 1
            if type(api.Cancel)=="function" then api.Cancel("ForeverAI") end
            nav.paused=true
        else
            local stops={}
            for i=nav.index,#nav.points do local p=nav.points[i]; stops[#stops+1]={map=p.mapID,x=p.x,y=p.y,title=p.label} end
            local ok,started=pcall(api.NavigateRoute,"ForeverAI",stops)
            if not ok or not started then self:Say(T("Wegführung konnte nicht fortgesetzt werden.")); return end
            nav.points={unpack(nav.points,nav.index)};nav.index=1;nav.paused=false
        end
        self:Say(T(nav.paused and "Wegführung pausiert." or "Wegführung fortgesetzt.")); return
    end
    self.nav.paused=value==nil and not self.nav.paused or value==true
    self:Say(T(self.nav.paused and "Wegführung pausiert." or "Wegführung fortgesetzt."))
    self:Tick()
end

function FG:GuidanceCommand(text)
    local key=FG.Normalize(text)
    if key=="" or key=="start" or key=="on" or key=="an" then self:StartDestination()
    elseif key=="pause" then self:PauseNavigation(true)
    elseif key=="resume" or key=="weiter" or key=="fortsetzen" then self:PauseNavigation(false)
    elseif key=="stop" or key=="stopp" or key=="off" or key=="aus" then self:StopNavigation()
    elseif key=="pin" or key=="kartenpin" then
        local p=self:ReadPin()
        if not p then self:Say(T("Kein lesbarer Kartenpin vorhanden.")); return end
        p.label=T("Ziel aus dem Kartenpin")
        self:OfferNavigation({name=p.label,points={p}})
    elseif key=="test" then self:TestNavigation()
    elseif key=="world" or key=="welt" then self:ToggleWorldMarker()
    else self:Say(T("Wegführung: /fai navi start | pause | resume | stop | pin | test | world")) end
end

function FG:NotePoint(text)
    local p=self.recording and self.recording.points[#self.recording.points] or self.nav and self.nav.points[self.nav.index]
    if not p then self:Say(T("Erst eine Route aufnehmen oder eine Wegführung starten.")); return end
    p.note=FG.Clean(text,220)
    self:Say(T("Hinweis am aktuellen Punkt gespeichert: %s",p.note))
    if self.nav then self:Tick() end
end

-- Facing-relative guidance is deliberately not a street-turn instruction.
function FG.DirectionHint(right,forward)
    if forward<-.7 then return "Zielrichtung hinter dir" end
    if forward>.93 then return "Zielrichtung vor dir" end
    return right>=0 and "Zur Zielrichtung nach rechts drehen" or "Zur Zielrichtung nach links drehen"
end

function FG:UpdateGuidanceHeader()
    local nav,f=self.nav,self.arrow
    if not nav or not f then return end
    local p=nav.points[nav.index]
    f.title:SetText(FG.Clean(p.label,100))
    f.mode:SetText(T(FG.KindLabels[p.kind or FG.DestinationKind(nav)] or "Wegpunkt").." · "..T(FG.RouteMode(nav)))
    f.note:SetText(p.note and p.note~="" and p.note or T("Straßen und Hindernisse selbst beachten. Pfeil relativ zur Figur, nicht zur Kamera."))
    local nextPoint=nav.points[nav.index+1]
    f.nextPoint:SetText(nextPoint and T("Danach: %s",nextPoint.label) or T("Letzter Punkt: Ankunft selbst bestätigen."))
    local marker=nav.nativeOwned and not nav.nativeBlocked and T("Weltsymbol angefordert") or T(nav.pinStatus or "")
    f.step:SetText(string.format("%d / %d · %s",nav.index,#nav.points,marker))
    f.pause:SetText(T(nav.paused and "Fortsetzen" or "Pause"))
    f.nextButton:SetText(T(nav.nearFinal and "Fertig" or nav.nearManual and "Bestätigen" or "Weiter"))
    f.native:SetText(T(self.db.navigation.worldMarker and "Weltsymbol: an" or "Weltsymbol: aus"))
end

function FG:QuestRoute(id)
    local title
    for _,q in ipairs(self:GetQuests()) do if q.id==id then title=q.title; break end end
    if not title then return nil end
    local m,x,y=FG.Safe(C_QuestLog and C_QuestLog.GetNextWaypoint,id)
    local p=FG.ValidatePoint({mapID=m,x=x,y=y,label=title,kind="quest"})
    if not p then return nil end
    return {name=title,points={p},questID=id,kind="quest"}
end

function FG:CheckQuestTurnIn()
    local watch=self.questTurnInWatch
    if not watch or watch.phase~="objectives" then return end
    local quest
    for _,entry in ipairs(self:GetQuests()) do if entry.id==watch.id then quest=entry;break end end
    if not quest then return end
    local complete=FG.Safe(C_QuestLog and C_QuestLog.IsComplete,watch.id)
    if FG.IsSecret(complete) or (complete~=true and complete~=1 and quest.isComplete~=true and quest.isComplete~=1) then return end
    if self:InCombat() then
        if not watch.deferred then self:Say(self.locale=="deDE" and "Quest abgeschlossen. Der Abgabeweg startet nach dem Kampf." or "Quest complete. Turn-in guidance will start after combat.");watch.deferred=true end
        return
    end
    watch.phase="resolving"
    local rows=self.QuestieFinisherResults and self:QuestieFinisherResults(watch.id,quest.title) or {}
    local api=_G.ShortestPathForever and _G.ShortestPathForever.API
    local other=api and type(api.Active)=="function" and FG.Safe(api.Active)==true and not (self.nav and self.nav.spf)
    if #rows==1 and not other then
        watch.phase="turnin"
        local ok,err=self:StartNavigation(rows[1].route,false,true)
        if ok then
            self:Say((self.locale=="deDE" and "Quest abgeschlossen. Weg zur Abgabe: " or "Quest complete. Turn-in destination: ")..rows[1].name.." · "..rows[1].detail)
        else watch.phase="missing";self:Say(err) end
    elseif #rows>0 then
        watch.phase="selection"
        self:ShowSearchResults(rows,quest.title,{directStart=true})
        self:Say(self.locale=="deDE" and "Quest abgeschlossen. Bitte den Abgabeort auswählen." or "Quest complete. Please select a turn-in destination.")
    else
        watch.phase="missing"
        self:Say(self.locale=="deDE" and "Quest abgeschlossen. Für die Abgabe ist kein zuverlässiger Kartenpunkt verfügbar." or "Quest complete. No reliable turn-in location is available.")
    end
end

function FG:RegisterQuestieUpdates()
    if self.questieUpdatesRegistered then return end
    local api=_G.Questie and _G.Questie.API
    if type(api)~="table" or type(api.RegisterForQuestUpdates)~="function" then return end
    local function register()
        if self.questieUpdatesRegistered then return end
        local ok=pcall(api.RegisterForQuestUpdates,function(id)
            if self.questTurnInWatch and self.questTurnInWatch.id==id then pcall(self.CheckQuestTurnIn,self) end
        end)
        if ok then self.questieUpdatesRegistered=true end
    end
    if type(api.RegisterOnReady)=="function" then pcall(api.RegisterOnReady,register) else register() end
end

function FG:RefreshQuestNavigation()
    local nav=self.nav
    if not nav or not nav.questID or not nav.questDirty then return end
    nav.questDirty=false
    local route=self:QuestRoute(nav.questID)
    if not route then
        if not nav.questMissing then
            -- A stale quest pin is worse than no pin. Restore the user's prior state.
            local restore=self:CanRestoreTracking(nav)
            if nav.ownedPin then self:RestorePin(nav.ownedPin,nav.previousPin) end
            self:RestoreTracking(nav,restore)
            nav.ownedPin,nav.nativeOwned=nil,nil
            nav.pinBlocked,nav.nativeBlocked=true,true
            self:Say(T("Questkoordinaten fehlen. Alter Zielmarker entfernt; für neue Kartenmarker die Wegführung erneut starten."))
        end
        nav.questMissing=true
        return
    end
    local wasMissing=nav.questMissing
    nav.questMissing=nil
    if wasMissing or not FG.SamePoint(route.points[1],nav.points[1]) then
        nav.points=route.points; nav.index=1; nav.nearFinal=nil; nav.nearManual=nil; nav.bestDistance=nil
        self:ApplyPin(); self:RefreshDestination()
        self:Say(T("Der Client hat ein neues Questziel geliefert. Wegführung aktualisiert."))
    end
end

-- Native in-world marker: use only the public client feature; no custom 3D projection.
-- Unknown tracking types are left alone. External changes always take precedence.
function FG:CaptureTracking()
    local api=C_SuperTrack
    if not api or type(api.IsSuperTrackingUserWaypoint)~="function" or type(api.SetSuperTrackedUserWaypoint)~="function" then return {kind="unknown"} end
    if FG.Safe(api.IsSuperTrackingUserWaypoint)==true then return {kind="user"} end
    if FG.Safe(api.IsSuperTrackingQuest)==true then
        local id=FG.Safe(api.GetSuperTrackedQuestID)
        if FG.IsNumber(id) and id>0 then return {kind="quest",questID=id} end
    end
    if FG.Safe(api.IsSuperTrackingAnything)==false then return {kind="none"} end
    return {kind="unknown"}
end

function FG:ApplyNativeTracking()
    local nav=self.nav
    if not nav or not self.db.navigation.worldMarker or nav.paused or nav.nativeBlocked or nav.pinBlocked or self:InCombat() then return end
    if not nav.previousTrack or nav.previousTrack.kind=="unknown" then return end
    if not FG.SamePoint(self:ReadPin(),nav.ownedPin) then return end
    if not C_SuperTrack or type(C_SuperTrack.SetSuperTrackedUserWaypoint)~="function" then return end
    self.writingTracking=true
    local ok=pcall(C_SuperTrack.SetSuperTrackedUserWaypoint,true)
    self.writingTracking=false
    nav.nativeOwned=ok and FG.Safe(C_SuperTrack.IsSuperTrackingUserWaypoint)==true
    if nav.nativeOwned then nav.nativeSuspended=nil end
end

function FG:OnSuperTrackingChanged()
    if self.writingTracking or not self.nav then return end
    if self.nav.nativeSuspended or (self.nav.nativeOwned and FG.Safe(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint)~=true) then
        self.nav.nativeBlocked=true
    end
end

function FG:CanRestoreTracking(nav)
    if not nav or nav.nativeBlocked or not FG.SamePoint(self:ReadPin(),nav.ownedPin) then return false end
    if nav.nativeOwned then return FG.Safe(C_SuperTrack and C_SuperTrack.IsSuperTrackingUserWaypoint)==true end
    return nav.nativeSuspended and FG.Safe(C_SuperTrack and C_SuperTrack.IsSuperTrackingAnything)==false or false
end

function FG:RestoreTracking(nav,allowed)
    if not allowed or self:InCombat() or not C_SuperTrack then return end
    local previous=nav.previousTrack
    self.writingTracking=true
    FG.Safe(C_SuperTrack.SetSuperTrackedUserWaypoint,previous.kind=="user" and nav.previousPin~=nil)
    if previous.kind=="quest" then FG.Safe(C_SuperTrack.SetSuperTrackedQuestID,previous.questID) end
    self.writingTracking=false
end

function FG:ToggleWorldMarker()
    if self:InCombat() then self:Say(T("Weltsymbol bitte außerhalb des Kampfes umschalten.")); return end
    self.db.navigation.worldMarker=not self.db.navigation.worldMarker
    local nav=self.nav
    if nav then
        if self.db.navigation.worldMarker then self:ApplyNativeTracking()
        else
            if self:CanRestoreTracking(nav) then
                self.writingTracking=true
                FG.Safe(C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint,false)
                if nav.previousTrack.kind=="quest" then
                    FG.Safe(C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID,nav.previousTrack.questID)
                elseif nav.previousTrack.kind=="user" then nav.nativeSuspended=true end
                self.writingTracking=false
            end
            nav.nativeOwned=nil
        end
        self:UpdateGuidanceHeader()
    end
    self:Say(T(self.db.navigation.worldMarker and "Weltsymbol angefordert, sofern der Client es unterstützt und keine andere Verfolgung Vorrang hat." or "Weltsymbol ausgeschaltet. Der eigene Pfeil bleibt verfügbar."))
end
