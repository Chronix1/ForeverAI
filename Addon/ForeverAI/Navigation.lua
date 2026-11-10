local _, FG = ...
local T = FG.T

function FG:InCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown()
end

function FG:MapInfo(mapID)
    return FG.Safe(C_Map and C_Map.GetMapInfo, mapID)
end

function FG:PlayerPoint()
    if self:InCombat() then return nil, T("Positionsabfrage im Kampf pausiert.") end
    local mapID = FG.Safe(C_Map and C_Map.GetBestMapForUnit, "player")
    if not FG.IsNumber(mapID) then return nil, T("Der Client liefert gerade keine Spielerkarte.") end
    local pos = FG.Safe(C_Map and C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y = FG.XY(pos)
    if not x or (x == 0 and y == 0) then return nil, T("Keine lesbare Position; bitte im Freien erneut versuchen.") end
    return FG.ValidatePoint({mapID=mapID, x=x, y=y, label=T("Eigene Position")})
end

function FG:CheckRoute(route)
    if type(route) ~= "table" or type(route.points) ~= "table" or #route.points == 0 or #route.points > self.MAX_POINTS then
        return nil, T("Die Route benötigt 1 bis ") .. self.MAX_POINTS .. T(" Wegpunkte.")
    end
    local clean = {name=FG.Clean(route.name or T("Navigation"),100), points={}}
    for i, point in ipairs(route.points) do
        local p, err = FG.ValidatePoint(point)
        if not p then return nil, T("Punkt ") .. i .. ": " .. err end
        local info = self:MapInfo(p.mapID)
        if not info or FG.IsSecret(info) or not info.name then
            return nil, T("Karten-ID ") .. p.mapID .. T(" ist in deinem Client nicht verfügbar.")
        end
        clean.points[i] = p
    end
    if FG.IsNumber(route.questID) and route.questID>0 and route.questID%1==0 then clean.questID=route.questID end
    if FG.IsNumber(route.watchQuestID) and route.watchQuestID>0 and route.watchQuestID%1==0 then clean.watchQuestID=route.watchQuestID end
    if type(route.kind)=="string" and FG.KindLabels and FG.KindLabels[route.kind] then clean.kind=route.kind end
    return clean
end

function FG:ReadPin()
    local p = FG.Safe(C_Map and C_Map.GetUserWaypoint)
    if not p or FG.IsSecret(p) then return nil end
    local x, y = FG.XY(p.position)
    if not x then return nil end
    return FG.ValidatePoint({mapID=p.uiMapID, x=x, y=y, label=T("Vorheriger Kartenpin")})
end

function FG.SamePoint(a, b)
    return a and b and a.mapID == b.mapID and math.abs(a.x-b.x)<0.00001 and math.abs(a.y-b.y)<0.00001
end

function FG:WritePin(p)
    if not C_Map or type(C_Map.SetUserWaypoint) ~= "function" then return false end
    local canSet = FG.Safe(C_Map.CanSetUserWaypointOnMap, p.mapID)
    if FG.IsSecret(canSet) or canSet == false then return false end
    local location
    if UiMapPoint and type(UiMapPoint.CreateFromCoordinates) == "function" then
        location = FG.Safe(UiMapPoint.CreateFromCoordinates, p.mapID, p.x, p.y)
    end
    location = location or {uiMapID=p.mapID, position={x=p.x, y=p.y}}
    self.writingPin = true
    local ok, accepted = pcall(C_Map.SetUserWaypoint, location)
    self.writingPin = false
    return ok and accepted ~= false
end

function FG:ApplyPin()
    local nav = self.nav
    if not nav then return end
    if nav.pinBlocked then nav.pinStatus = "Eigener Kartenpin hat Vorrang"; return end
    if self:InCombat() then nav.pendingPin=true; return end
    local p = nav.points[nav.index]
    nav.pendingPin = false
    -- WritePin suppresses synchronous events from our own write.
    if self:WritePin(p) then
        nav.ownedPin = p
        nav.pinStatus = "Kartenmarker gesetzt"
        self:ApplyNativeTracking()
    else
        nav.pinStatus = "Kartenmarker hier nicht verfügbar"
        self:Say(T("Für ") .. p.label .. T(" konnte kein Kartenpin gesetzt werden. Der eigene Richtungspfeil wird unabhängig davon versucht."))
    end
end

function FG:OnPinChanged()
    if self.writingPin or not self.nav or not self.nav.ownedPin then return end
    if not FG.SamePoint(self:ReadPin(), self.nav.ownedPin) then
        self.nav.pinBlocked = true
        self.nav.nativeBlocked = true
        self:Say(T("Ein anderer Kartenpin hat Vorrang. ForeverAI überschreibt ihn nicht; der eigene Pfeil bleibt aktiv."))
    end
end

function FG:RestorePathDisplays()
    if not self.pathDisplaySettings then return end
    for _,item in ipairs(self.pathDisplaySettings) do
        if item.setting and item.setting.GetValue and item.setting.SetValue and item.setting:GetValue()==false then
            pcall(item.setting.SetValue,item.setting,item.value)
        end
    end
    self.pathDisplaySettings=nil
end

function FG:UsePathDisplays()
    if self.pathDisplaySettings or not Settings or type(Settings.GetSetting)~="function" then return end
    self.pathDisplaySettings={}
    -- guideStops=true points directly at the end of a travel leg. Disable it
    -- while ForeverAI owns guidance so the provider leads through each bend.
    for _,key in ipairs({"journeyTracker","compass","guideStops"}) do
        local ok,setting=pcall(Settings.GetSetting,"ShortestPathForever_"..key)
        if ok and setting and type(setting.GetValue)=="function" and type(setting.SetValue)=="function" then
            local got,value=pcall(setting.GetValue,setting)
            if got and type(value)=="boolean" then
                self.pathDisplaySettings[#self.pathDisplaySettings+1]={setting=setting,value=value}
                pcall(setting.SetValue,setting,false)
            end
        end
    end
end

function FG:StopNavigation(quiet,keepQuest)
    if not keepQuest then self.questTurnInWatch=nil end
    local nav = self.nav
    self.nav = nil
    if nav and nav.spf then
        local api = _G.ShortestPathForever and _G.ShortestPathForever.API
        if api and type(api.Cancel)=="function" then pcall(api.Cancel,"ForeverAI") end
        self:RestorePathDisplays()
    end
    if nav and nav.ownedPin and FG.SamePoint(self:ReadPin(), nav.ownedPin) then
        if self:InCombat() then
            -- Only restore later if this exact pin still belongs to us.
            self.pendingRestore = {owned=nav.ownedPin, previous=nav.previousPin, nav=nav}
        else
            local restoreTrack=self:CanRestoreTracking(nav)
            self:RestorePin(nav.ownedPin,nav.previousPin)
            self:RestoreTracking(nav,restoreTrack)
        end
    end
    if self.arrow then self.arrow:Hide() end
    if self.RefreshDestination then self:RefreshDestination() end
    if nav and not quiet then self:Say(T("Navigation beendet.")) end
end

function FG:RestorePin(owned, previous)
    if not FG.SamePoint(self:ReadPin(), owned) then return end
    if previous then
        self:WritePin(previous)
    elseif C_Map and type(C_Map.ClearUserWaypoint) == "function" then
        self.writingPin = true
        pcall(C_Map.ClearUserWaypoint)
        self.writingPin = false
    end
end

function FG:StartNavigation(route,forceStraight,keepQuest)
    if self:InCombat() then return nil, T("Bitte die Navigation außerhalb des Kampfes starten.") end
    local clean, err = self:CheckRoute(route)
    if not clean then return nil, err end
    local api = _G.ShortestPathForever and _G.ShortestPathForever.API
    local pathUnreachable=false
    if not forceStraight and api and type(api.EstimateDetail)=="function" and self.PlayerPoint then
        local p=self:PlayerPoint()
        local dest=clean.points[1]
        if p then
            local ok,estimate,reason=pcall(api.EstimateDetail,p.mapID,p.x,p.y,dest.mapID,dest.x,dest.y)
            pathUnreachable=ok and not estimate and reason=="unreachable"
        end
    end
    if not forceStraight and api and type(api.NavigateRoute)=="function" and not pathUnreachable then
        local stops={}
        for _,p in ipairs(clean.points) do stops[#stops+1]={map=p.mapID,x=p.x,y=p.y,title=p.label} end
        local ok,started=pcall(api.NavigateRoute,"ForeverAI",stops)
        if ok and started then
        -- The new journey already owns the provider; do not cancel it while replacing our old state.
        if self.nav and self.nav.spf then self.nav=nil;if not keepQuest then self.questTurnInWatch=nil end else self:StopNavigation(true,keepQuest) end
        self.destination=nil
        self.nav={name=clean.name,points=clean.points,index=1,questID=clean.questID,kind=clean.kind,spf=true}
        if not keepQuest and (clean.watchQuestID or clean.questID) then self.questTurnInWatch={id=clean.watchQuestID or clean.questID,phase="objectives"} end
        self:UsePathDisplays()
        if not self.spfUnsubscribe and type(api.Subscribe)=="function" then
            self.spfUnsubscribe=api.Subscribe(function(changes)
                local nav=self.nav
                if not nav or not nav.spf or nav.paused then return end
                local reason=type(api.Ended)=="function" and api.Ended("ForeverAI") or nil
                if reason then
                    self.nav=nil
                    self:RestorePathDisplays()
                    self:RefreshDestination()
                    if reason~="arrived" then self.questTurnInWatch=nil end
                    self:Say(reason=="arrived" and T("Ziel erreicht.") or T("Wegführung beendet."))
                elseif type(changes)=="table" and changes.active and type(api.Active)=="function"
                    and not api.Active() and type(api.CurrentStop)=="function" then
                    local index=api.CurrentStop("ForeverAI")
                    if index and nav.points[index] then
                        local remaining={name=nav.name,kind=nav.kind,questID=nav.questID,points={}}
                        for i=index,#nav.points do remaining.points[#remaining.points+1]=nav.points[i] end
                        self:StopNavigation(true,true)
                        self:Say(self.locale=="deDE" and "Die berechnete Wegführung ist nicht mehr verfügbar. Zeige die reine Zielrichtung (Luftlinie)." or "Calculated guidance is no longer available. Showing the straight-line target direction.")
                        local ok,err=self:StartNavigation(remaining,true,true)
                        if not ok then self:Say(err) end
                    end
                end
            end)
        end
        if self.arrow then self.arrow:Hide() end
        self:RefreshDestination()
        self:Say(T("Wegführung gestartet: ")..clean.name.." · Shortest Path Forever")
        if self.CheckQuestTurnIn then self:CheckQuestTurnIn() end
        return true
        end
        self:Say(self.locale=="deDE" and "Keine berechnete Route verfügbar. Zeige stattdessen die reine Zielrichtung (Luftlinie)." or "No calculated route is available. Showing the straight-line target direction instead.")
    end
    if pathUnreachable then self:Say(self.locale=="deDE" and "Für dieses Ziel wurde keine Route gefunden. Zeige die reine Zielrichtung (Luftlinie)." or "No route was found to this destination. Showing the straight-line target direction.") end
    self:StopNavigation(true,keepQuest)
    if self.pendingRestore then
        local restore=self.pendingRestore
        local allowed=self:CanRestoreTracking(restore.nav)
        self:RestorePin(restore.owned,restore.previous)
        self:RestoreTracking(restore.nav,allowed)
        self.pendingRestore = nil
    end
    self.destination=nil
    self.nav = {name=clean.name,points=clean.points,index=1,previousPin=self:ReadPin(),previousTrack=self:CaptureTracking(),questID=clean.questID,kind=clean.kind}
    if not keepQuest and (clean.watchQuestID or clean.questID) then self.questTurnInWatch={id=clean.watchQuestID or clean.questID,phase="objectives"} end
    if clean.questID then FG.Safe(C_QuestLog and C_QuestLog.AddQuestWatch,clean.questID) end
    self:CreateArrow()
    self.arrow:Show()
    self:ApplyPin()
    self:UpdateGuidanceHeader()
    self:ArrowState(nil,nil,T("Position wird geprüft"))
    self:RefreshDestination()
    self:Say(T("Navigation: ") .. clean.name .. " (" .. #clean.points .. T(" Punkt(e)). Pfeile zeigen die Luftlinie, keinen berechneten sicheren Fußweg."))
    if self.CheckQuestTurnIn then self:CheckQuestTurnIn() end
    return true
end

function FG:Advance(delta)
    local nav = self.nav
    if not nav then self:Say(T("Keine Navigation aktiv.")); return end
    if nav.spf then
        local api=_G.ShortestPathForever and _G.ShortestPathForever.API
        if not api or type(api.NavigateRoute)~="function" then self:Say(T("Wegführung nicht verfügbar.")); return end
        local current=type(api.CurrentStop)=="function" and api.CurrentStop("ForeverAI") or nav.index or 1
        local nextIndex=math.max(1,current+(delta or 1))
        if nextIndex>#nav.points then self:StopNavigation(); return end
        local stops={}
        for i=nextIndex,#nav.points do local p=nav.points[i]; stops[#stops+1]={map=p.mapID,x=p.x,y=p.y,title=p.label} end
        local ok,started=pcall(api.NavigateRoute,"ForeverAI",stops)
        if not ok or not started then self:Say(T("Wegführung konnte nicht fortgesetzt werden.")); return end
        nav.points={unpack(nav.points,nextIndex)}; nav.index=1;nav.paused=false
        return
    end
    local nextIndex = nav.index + (delta or 1)
    if nextIndex > #nav.points then
        self:Say(T("Letzter Wegpunkt erreicht oder übersprungen: ") .. nav.name)
        self:StopNavigation(true,true)
        return
    end
    nav.index = math.max(1, nextIndex)
    nav.geometry,nav.nearFinal,nav.nearManual,nav.bestDistance=nil,nil,nil,nil
    self:ApplyPin()
    self:UpdateGuidanceHeader()
    self:ArrowState(nil,nil,T("Position wird geprüft"))
end

function FG.WorldPosition(p)
    if not C_Map or type(C_Map.GetWorldPosFromMapPos) ~= "function" or type(CreateVector2D) ~= "function" then return nil end
    local continent, pos = FG.Safe(C_Map.GetWorldPosFromMapPos, p.mapID, CreateVector2D(p.x,p.y))
    local x, y = FG.XY(pos)
    if FG.IsNumber(continent) and x then return continent, x, y end
end

function FG:Geometry(target)
    local player, err = self:PlayerPoint()
    if not player then return nil, err end
    local pc, px, py = FG.WorldPosition(player)
    local tc, tx, ty = FG.WorldPosition(target)
    if pc and tc and pc ~= tc then return nil, T("Anderer Kontinent / Kartenraum; Übergang selbst wählen.") end
    if pc and tc then
        -- Derive the map's east/south axes rather than assuming the world's axis order.
        local origin = {mapID=target.mapID,x=0,y=0}
        local east = {mapID=target.mapID,x=1,y=0}
        local south = {mapID=target.mapID,x=0,y=1}
        local oc, ox, oy = FG.WorldPosition(origin)
        local ec, ex, ey = FG.WorldPosition(east)
        local sc, sx, sy = FG.WorldPosition(south)
        if oc == tc and ec == tc and sc == tc and ox and ex and sx then
            local el = math.sqrt((ex-ox)^2 + (ey-oy)^2)
            local sl = math.sqrt((sx-ox)^2 + (sy-oy)^2)
            if el > 0 and sl > 0 then
                local dx, dy = tx-px, ty-py
                local eastDistance = (dx*(ex-ox)+dy*(ey-oy))/el
                local northDistance = -(dx*(sx-ox)+dy*(sy-oy))/sl
                return {east=eastDistance, north=northDistance, distance=math.sqrt(dx*dx+dy*dy)}
            end
        end
    end
    if player.mapID == target.mapID then
        local width, height = FG.Safe(C_Map and C_Map.GetMapWorldSize, target.mapID)
        if FG.IsNumber(width) and FG.IsNumber(height) and width > 0 and height > 0 then
            local east, north = (target.x-player.x)*width, (player.y-target.y)*height
            return {east=east,north=north,distance=math.sqrt(east*east+north*north)}
        end
    end
    return nil, T("Keine verlässliche Richtung verfügbar. Zielkarte öffnen.")
end

function FG:Tick()
    if self.pendingRestore and not self:InCombat() then
        local restore=self.pendingRestore
        local allowed=self:CanRestoreTracking(restore.nav)
        self:RestorePin(restore.owned,restore.previous)
        self:RestoreTracking(restore.nav,allowed)
        self.pendingRestore = nil
    end
    local nav = self.nav
    if not nav then return end
    if nav.spf then return end -- Shortest Path owns progress and arrival notifications.
    self:UpdateGuidanceHeader()
    local function paused(text)
        self:ArrowState(nil,nil,text)
        self.arrow.instruction:SetText(T("Keine Richtungsanweisung verfügbar"))
    end
    if self:InCombat() then paused(T("Im Kampf pausiert")); return end
    if nav.paused then paused(T("Wegführung pausiert.")); return end
    if nav.pendingPin then self:ApplyPin() end
    local inInstance=FG.Safe(IsInInstance)
    if FG.IsSecret(inInstance) or inInstance==true then paused(T("In Instanzen pausiert")); return end
    local taxi=FG.Safe(UnitOnTaxi,"player")
    if FG.IsSecret(taxi) or taxi==true then paused(T("Während des Fluges pausiert")); return end
    self:RefreshQuestNavigation()
    if nav.questMissing then paused(T("Questziel derzeit ohne Koordinaten; bitte erneut suchen.")); return end
    local point=nav.points[nav.index]
    self:UpdateGuidanceHeader()
    local geometry,err=self:Geometry(point)
    if not geometry then paused(err); return end
    local player=self:PlayerPoint()
    local near=geometry.distance<=12 and player and player.mapID==point.mapID
    nav.nearFinal=near and nav.index==#nav.points or nil
    nav.nearManual=near and (point.confirm or point.kind=="travel") or nil
    if nav.nearFinal and not nav.nearManual then
        self:StopNavigation(true,true)
        self:Say(T("Ziel erreicht."))
        return
    end
    if near and nav.index<#nav.points and not nav.nearManual then
        self:Advance(1)
        self:Say(T("Nächster Wegpunkt: %s",nav.points[nav.index].label))
        return
    end
    local facing=FG.Safe(GetPlayerFacing)
    if not FG.IsNumber(facing) then paused(T("Blickrichtung nicht lesbar")); return end
    local right,forward=FG.RelativeVector(geometry.east,geometry.north,facing)
    self:ArrowState(right,forward,string.format(T("%.0f yd Luftlinie"),geometry.distance))
    nav.bestDistance=math.min(nav.bestDistance or geometry.distance,geometry.distance)
    if nav.nearFinal then
        self.arrow.instruction:SetText(T("Ziel in der Nähe. Vor Ort prüfen und Fertig drücken."))
    elseif nav.nearManual then
        self.arrow.instruction:SetText(T("Übergang oder Aktion prüfen, dann Bestätigen drücken."))
    elseif geometry.distance>nav.bestDistance+45 then
        self.arrow.instruction:SetText(T("Du entfernst dich vom Wegpunkt. Ein Umweg kann nötig sein."))
    else self.arrow.instruction:SetText(T(FG.DirectionHint(right,forward))) end
    self:UpdateGuidanceHeader()
end

function FG:OpenTargetMap()
    if self:InCombat() then self:Say(T("Karte bitte außerhalb des Kampfes öffnen.")); return end
    local p = self.destination and self.destination.points[1] or self.nav and self.nav.points[self.nav.index] or self:PlayerPoint()
    if not p then self:Say(T("Keine Karte verfügbar.")); return end
    if C_Map and type(C_Map.OpenWorldMap) == "function" then
        local ok = pcall(C_Map.OpenWorldMap,p.mapID)
        if ok then return end
    end
    self:Say(T("Bitte die Weltkarte mit M öffnen. Ziel-Karten-ID: ") .. p.mapID)
end

function FG:TestNavigation()
    local p, err = self:PlayerPoint()
    if not p then self:Say(err); return end
    local _, height = FG.Safe(C_Map and C_Map.GetMapWorldSize,p.mapID)
    if not FG.IsNumber(height) or height <= 0 then self:Say(T("Für diese Karte fehlt die Größe. Bitte im Freien testen.")); return end
    local delta = 60/height
    local y = p.y - delta
    if y < 0.01 then y = p.y + delta end
    if y > 0.99 then self:Say(T("Zu nah am Kartenrand; bitte an anderer Stelle testen.")); return end
    p.y, p.label = y, T("Testziel · kein geprüfter Fußweg")
    local ok, why = self:StartNavigation({name=T("Richtungstest"),points={p}})
    if not ok then self:Say(why) end
end
