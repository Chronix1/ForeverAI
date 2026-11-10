local _, FG = ...
local T = FG.T

function FG:Help()
    self:Say(T("Suche im Chat → Ziel prüfen → Wegführung starten. /fai navi pause | resume | stop | pin. /fai hinweis Text ergänzt einen Routenpunkt."))
    self:Say(T("Chatbutton: ziehen zum Verschieben, Linksklick zum Öffnen, Rechtsklick zum Sperren. /fai button reset setzt die Positionen zurück."))
    self:Say(T("KI-Vorbereitung: /fai model Modell-ID · /fai reasoning low|medium|high · /fai benchmark zeigt nur den Testplan."))
    self:Say(T("Sprache: /fai sprache auto|de|en · Wörterbuch: /fai begriff Begriff · Eigener Questname: /fai alias quest ID Name"))
    self:Say(T("Befehle: /fai öffnet das Fenster. /fai test setzt ein Testziel. /fai wo zeigt deine Position."))
    self:Say(T("Navigation: /fai ziel KARTEN-ID X Y Name · X/Y sind Prozentwerte. /fai weiter · /fai zurueck · /fai stopp"))
    self:Say(T("Orte: /fai merken Name speichert deine Position. /fai gehe Name führt dorthin. /fai liste zeigt Orte/Routen. /fai entfernen Name löscht einen eigenen Eintrag."))
    self:Say(T("Quests: /fai quests · /fai quest Titel-oder-ID. Nur aktuelle Quests und vom Client gelieferte Zielkoordinaten."))
    self:Say(T("Route aufnehmen: /fai aufnahme Name → an Abzweigungen /fai punkt → /fai speichern. Abspielen: /fai route Name. Abbrechen: /fai abbrechen."))
    self:Say(T("Online-Daten: Begleit-App einmal einrichten. Sie aktualisiert die lokale Wissensdatenbank ohne manuellen Import; neu einloggen oder /reload. /fai daten zeigt den Stand."))
    self:Say(T("Austausch: /fai export Frage · /fai import · /fai routenexport · /fai sichern Name (aktive Route speichern). /fai diagnose erzeugt einen Fehlerbericht."))
    self:Say(T("Ausrüstung: /fai ausruestung zeigt getragene Items und verfügbare Werte; /fai taschen liest auf Wunsch bis zu 24 Taschenitems."))
    self:Say(T("Suche: /fai suche Ort · oder im Chat Ziele suchen → Treffer anklicken → Wegführung starten."))
    self:Say("Live-KI: /fai live an|aus|status · /fai modelle lädt die echte Modellliste. Benötigt eingerichtete Windows-Begleit-App und Fenster-/randlosen Modus.")
    self:Say(self.locale=="deDE" and "Alpha: kuratierte Dungeon-Anreisepunkte; NPCs optional mit QuestieDB. Kein automatisch berechneter Fußweg." or "Alpha: curated dungeon approach points; optional QuestieDB for NPCs. No automatic walking path.")
end

function FG:PositionText()
    local p,err = self:PlayerPoint()
    if not p then return err end
    local info = self:MapInfo(p.mapID)
    return string.format(T("%s · Karten-ID %d · X %.2f / Y %.2f"),FG.Clean(info and info.name or T("Unbekannte Karte"),100),p.mapID,p.x*100,p.y*100)
end

function FG:NameTaken(key)
    return self.db.places[key] or self.db.routes[key]
end

function FG:SavePlace(name)
    name = FG.Clean(name,100)
    if FG.Normalize(name) == "" then self:Say(T("Namen ins Eingabefeld schreiben, dann Merken drücken; alternativ /fai merken Kriegerlehrer Sturmwind.")); return end
    local key = FG.Normalize(name)
    if self:NameTaken(key) then self:Say(T("Dieser Name ist schon vergeben. Einen anderen Namen verwenden oder /fai entfernen ") .. name); return end
    local p,err = self:PlayerPoint()
    if not p then self:Say(err); return end
    p.label = name
    self.db.places[key] = p
    self:Say(T("Eigener Ort gespeichert: ") .. name .. T(". Aufrufen: /fai gehe ") .. name)
end

function FG:ListPlaces()
    local lines = {}
    for _,p in pairs(self.db.places) do lines[#lines+1] = T("Ort: ") .. p.label end
    for _,r in pairs(self.db.routes) do lines[#lines+1] = T("Route: ") .. r.name .. " (" .. #r.points .. T(" Punkte)") end
    table.sort(lines)
    if #lines == 0 then self:Say(T("Noch keine eigenen Orte/Routen. /fai merken Name speichert den aktuellen Standort.")); return end
    for i=1,math.min(#lines,40) do self:Say(lines[i]) end
    if #lines>40 then self:Say(T("Weitere Einträge vorhanden; bitte direkt nach Namen aufrufen.")) end
end

function FG:StartSaved(query,exact,preview)
    if FG.AmbiguousTerm(query) then self:Say(T("DM ist mehrdeutig. Bitte Todesminen / Deadmines oder Düsterbruch / Dire Maul ausschreiben.")); return true end
    local matches = {}
    local key = FG.Normalize(query)
    if self.db.routes[key] then matches[1] = self.db.routes[key]
    elseif self.db.places[key] then matches[1] = {name=self.db.places[key].label,points={self.db.places[key]}}
    elseif not exact then
        for _,r in pairs(self.db.routes) do if FG.Matches(query,r.name) then matches[#matches+1]=r end end
        for _,p in pairs(self.db.places) do if FG.Matches(query,p.label) then matches[#matches+1]={name=p.label,points={p}} end end
    end
    if #matches == 0 then return false end
    if #matches > 1 then
        table.sort(matches,function(a,b) return a.name < b.name end)
        self:Say(T("Mehrere Treffer. Wähle einen Eintrag aus den Suchergebnissen:"))
        local rows={}
        for i=1,math.min(24,#matches) do
            rows[#rows+1]={name=matches[i].name,detail=self.locale=="deDE" and "Eigene Route" or "Saved route",
                route=matches[i],source="SavedVariables"}
        end
        if self.ShowSearchResults then self:ShowSearchResults(rows,query) end
        return true
    end
    if preview then
        if self.ShowSearchResults then
            self:ShowSearchResults({{name=matches[1].name,detail=self.locale=="deDE" and "Eigenes Ziel" or "Saved target",
                route=matches[1],source="SavedVariables"}},query)
        end
        return self:OfferNavigation(matches[1])
    end
    local ok,err = self:StartNavigation(matches[1])
    if not ok then self:Say(err) end
    return true
end

function FG:BeginRecording(name)
    if self.recording then self:Say(T("Es läuft schon eine Aufnahme. Erst /fai speichern oder /fai abbrechen.")); return end
    name = FG.Clean(name,100)
    if FG.Normalize(name) == "" then self:Say(T("Format: /fai aufnahme Routenname")); return end
    if self:NameTaken(FG.Normalize(name)) then self:Say(T("Dieser Name ist schon vergeben.")); return end
    local p,err = self:PlayerPoint()
    if not p then self:Say(err); return end
    p.label = name .. T(" – Start")
    self.recording = {name=name,points={p}}
    self:Say(T("Aufnahme gestartet. An jeder wichtigen Abzweigung /fai punkt; am Ziel ebenfalls /fai punkt, dann /fai speichern. Die Aufnahme wird nicht automatisch fortgeschrieben."))
end

function FG:RecordPoint(name)
    if not self.recording then self:Say(T("Erst /fai aufnahme Routenname verwenden.")); return end
    if #self.recording.points >= self.MAX_POINTS then self:Say(T("Maximale Punktzahl erreicht; /fai speichern.")); return end
    local p,err = self:PlayerPoint()
    if not p then self:Say(err); return end
    local i = #self.recording.points+1
    name = FG.Clean(name,100)
    p.label = name ~= "" and name or self.recording.name .. T(" – Punkt ") .. i
    self.recording.points[i] = p
    self:Say(T("Punkt ") .. i .. T(" aufgenommen: ") .. p.label)
end

function FG:SaveRecording()
    local r = self.recording
    if not r then self:Say(T("Keine Aufnahme aktiv.")); return end
    if #r.points < 2 then self:Say(T("Mindestens zwei Punkte nötig. Am nächsten Wegpunkt /fai punkt.")); return end
    if self:NameTaken(FG.Normalize(r.name)) then self:Say(T("Name inzwischen vergeben; Aufnahme nicht gespeichert.")); return end
    self.db.routes[FG.Normalize(r.name)] = r
    self.recording = nil
    self:Say(T("Route gespeichert: ") .. r.name .. ". /fai route " .. r.name .. T(" startet am ersten aufgenommenen Punkt; kein automatischer Einstieg mitten in die Strecke."))
end

function FG:GetQuests()
    local result = {}
    local count = FG.Safe(C_QuestLog and C_QuestLog.GetNumQuestLogEntries)
    if not FG.IsNumber(count) then return result end
    for i=1,math.min(count,1000) do
        local q = FG.Safe(C_QuestLog and C_QuestLog.GetInfo,i)
        if q and not FG.IsSecret(q) and not FG.IsSecret(q.isHeader) and not q.isHeader
            and FG.IsNumber(q.questID) and q.questID > 0 and not FG.IsSecret(q.title) and type(q.title)=="string" then
            local complete=not FG.IsSecret(q.isComplete) and q.isComplete or nil
            result[#result+1] = {id=q.questID,title=FG.Clean(q.title,180),isComplete=complete}
        end
    end
    return result
end

function FG:FindQuest(query,quiet,preview)
    if FG.AmbiguousTerm(query) then
        if not quiet then self:Say(T("DM ist mehrdeutig. Bitte Todesminen / Deadmines oder Düsterbruch / Dire Maul ausschreiben.")) end
        return false
    end
    if self:InCombat() then if not quiet then self:Say(T("Questsuche im Kampf pausiert.")) end; return false end
    local matches = {}
    local id = tonumber(FG.Trim(query))
    for _,q in ipairs(self:GetQuests()) do
        if (id and q.id == id) or (not id and self:QuestMatches(query,q)) then matches[#matches+1] = q end
    end
    if #matches == 0 then
        if not quiet then
            self:Say(T("Keine passende Quest im aktuellen Questlog. /fai quests zeigt die vorhandenen Titel und IDs."))
            self:Say(T("Kein fremdsprachiger Questname hinterlegt? Verwende /fai quest ID oder /fai alias quest ID Name."))
        end
        return false
    end
    if #matches > 1 then
        self:Say(T("Mehrere Quests passen. Ergebnisse mit vom Client bestätigten Zielkoordinaten sind anklickbar:"))
        local rows={}
        for i=1,math.min(#matches,24) do
            local q=matches[i]
            self:Say(q.id .. " — " .. q.title)
            local mapID,x,y=FG.Safe(C_QuestLog and C_QuestLog.GetNextWaypoint,q.id)
            local p=FG.ValidatePoint({mapID=mapID,x=x,y=y,label=q.title,kind="quest"})
            if p then rows[#rows+1]={name=q.title,detail="Quest-ID: "..q.id.." · Clientziel",
                route={name=q.title,questID=q.id,kind="quest",points={p}},source="WoW Client"} end
        end
        if #rows>0 and self.ShowSearchResults then self:ShowSearchResults(rows,query) end
        return true
    end
    local q = matches[1]
    local mapID,x,y = FG.Safe(C_QuestLog and C_QuestLog.GetNextWaypoint,q.id)
    local p,err = FG.ValidatePoint({mapID=mapID,x=x,y=y,label=q.title})
    if not p then
        self.destination=nil; self:RefreshDestination()
        self:Say(T("Gefunden: ") .. q.title .. T(". Der Client liefert dazu gerade keine nutzbaren Zielkoordinaten. Es wurde kein Ziel erfunden."))
        return true
    end
    p.kind="quest"
    local route={name=q.title,points={p},questID=q.id,kind="quest"}
    if preview then
        if self.ShowSearchResults then
            self:ShowSearchResults({{name=q.title,detail="Quest-ID: "..q.id.." · "..(self.locale=="deDE" and "Clientziel" or "Client target"),
                route=route,source="WoW Client"}},query)
        end
        return self:OfferNavigation(route)
    end
    local ok,why=self:StartNavigation(route)
    if not ok then self:Say(why) else self:Say(T("Client-Questziel. Änderungen werden bei Questlog-Ereignissen erneut geprüft.")) end
    return true
end

function FG:BuildContext(question)
    question = FG.Clean(question ~= "" and question or self.lastQuestion or T("Bitte hilf mir bei der Orientierung."),800)
    local v,b,_,i = FG.Safe(GetBuildInfo)
    local class = FG.Safe(UnitClass,"player")
    local level = FG.Safe(UnitLevel,"player")
    local faction = FG.Safe(UnitFactionGroup,"player")
    local lines = {
        T("Kontext aus ForeverAI ") .. self.VERSION .. T(". Kein Live-Zugriff auf mein Spiel."),
        T("Ich spiele offiziell über Battle.net: WoW Forever."),
        "Client: " .. tostring(v) .. " | Build: " .. tostring(b) .. " | Interface: " .. tostring(i),
        T("Klasse: ") .. (not FG.IsSecret(class) and tostring(class) or T("nicht lesbar")) .. " | Level: " .. (FG.IsNumber(level) and tostring(level) or "?") .. T(" | Fraktion: ") .. (not FG.IsSecret(faction) and tostring(faction) or "?"),
        "Position: " .. self:PositionText(),
        T("Meine Frage: ") .. question,
        "",
        T("Bitte antworte auf Deutsch. Verwende nur für diese Spielversion bestätigte Daten."),
        T("Unterscheide gesicherte Informationen von Vermutungen. Keine erfundenen Karten-IDs, Koordinaten, Quest-, NPC- oder Itemdaten."),
        T("Bei Itemempfehlungen fehlen ggf. Rolle und Budget. Die ausgerüsteten Gegenstände folgen unten. Ohne echten Kandidatenvergleich kein Best-in-Slot behaupten."),
        T("Für verifizierte Wegpunkte kann ich zusätzlich einen reinen Datenblock importieren:"),
        T("FG1;Routenname"),
        T("P;KARTEN-ID;X-IN-PROZENT;Y-IN-PROZENT;Beschriftung"),
        "END",
        T("Die P-Zeile darf bis zu 100-mal vorkommen. KARTEN-ID meint uiMapID, nicht ZoneID/AreaID. X/Y liegen zwischen 0 und 100."),
        T("Diese Formatbeschreibung ist kein gültiger Import. Erzeuge einen Block nur, wenn echte Ziele belegt sind. Das Addon prüft Zahlen und Kartenexistenz, nicht Begehbarkeit oder inhaltliche Richtigkeit."),
        "",
    }
    lines[#lines+1] = "FGP1;"..(self.db.ai.provider or "chatgpt")..";"..self.db.ai.model..";"..self.db.ai.effort
    lines[#lines+1] = self:AISettingsText()
    table.insert(lines, 4, T("Clientsprache: %s | Addonsprache: %s | Einstellung: %s", self.ClientLocale(), self.locale, self.languageMode))
    local known = {}
    for _,term in ipairs(FG.TermsIn(question)) do known[#known+1] = term.de .. " / " .. term.en end
    if #known > 0 then lines[#lines+1] = T("Bekannte Begriffe in der Frage: ") .. table.concat(known, "; ") end
    lines[#lines+1] = T("Begriffe sind nur Namenszuordnungen, keine bestätigten Ziele. Quests und Gegenstände möglichst über IDs zuordnen.")
    lines[#lines+1] = ""
    lines[#lines+1] = T("Aktuelle Quests (höchstens 40):")
    local quests = self:GetQuests()
    for n=1,math.min(#quests,40) do lines[#lines+1] = quests[n].id .. " — " .. quests[n].title end
    if #quests == 0 then lines[#lines+1] = T("Keine lesbaren Questdaten.") end
    lines[#lines+1] = ""
    lines[#lines+1] = T("Eigene gespeicherte Orte (höchstens 30; vom Spieler aufgenommen, keine externe Verifikation):")
    local places = {}
    for _,p in pairs(self.db.places) do places[#places+1] = p end
    table.sort(places,function(a,bp) return a.label<bp.label end)
    for n=1,math.min(#places,30) do
        local p=places[n]
        lines[#lines+1]=string.format("%s | uiMapID=%d | X=%.4f | Y=%.4f",p.label,p.mapID,p.x*100,p.y*100)
    end
    lines[#lines+1] = ""
    lines[#lines+1] = self:EquipmentText()
    local asked=FG.Normalize(question)
    if asked:find("tasche",1,true) or asked:find("inventar",1,true) or asked:find("bag",1,true) or asked:find("inventory",1,true) then
        lines[#lines+1]=self:BagText(20)
    end
    lines[#lines+1] = T("Hinweis: Nur beim ausdrücklichen KI-Export wird dieser Text zum manuellen Teilen vorbereitet. Keine automatische Übertragung.")
    return table.concat(lines,"\n")
end

function FG:Diagnostic()
    local v,b,_,i = FG.Safe(GetBuildInfo)
    local lines={T("ForeverAI Diagnose"), "Addon: " .. self.VERSION,
        "Client: " .. tostring(v) .. " | Build: " .. tostring(b) .. " | Interface: " .. tostring(i),
        "Position: " .. self:PositionText(), T("Im Kampf: ") .. tostring(self:InCombat()),
        T("Aktive Route: ") .. (self.nav and self.nav.name or T("keine")),
        T("Letzter Addon-Fehler: ") .. FG.Clean(self.lastError or T("keiner aufgezeichnet"),1000)}
    lines[#lines+1] = T("Clientsprache: %s | Addonsprache: %s | Einstellung: %s", self.ClientLocale(), self.locale, self.languageMode)
    for _,key in ipairs({"GetBestMapForUnit","GetPlayerMapPosition","GetMapInfo","GetWorldPosFromMapPos","GetMapWorldSize","GetUserWaypoint","SetUserWaypoint","CanSetUserWaypointOnMap","OpenWorldMap"}) do
        lines[#lines+1]="C_Map."..key..": "..tostring(C_Map and type(C_Map[key])=="function" or false)
    end
    lines[#lines+1]="C_QuestLog.GetNextWaypoint: " .. tostring(C_QuestLog and type(C_QuestLog.GetNextWaypoint)=="function" or false)
    lines[#lines+1]="C_SuperTrack.SetSuperTrackedUserWaypoint: "..tostring(C_SuperTrack and type(C_SuperTrack.SetSuperTrackedUserWaypoint)=="function" or false)
    lines[#lines+1]="Guidance native requested="..tostring(self.db.navigation.worldMarker).." | paused="..tostring(self.nav and self.nav.paused or false)
    lines[#lines+1]="GetPlayerFacing: " .. tostring(type(GetPlayerFacing)=="function")
    lines[#lines+1]=self:AISettingsText()
    lines[#lines+1]="Launcher visible="..tostring(self.db.ui.buttonVisible).." | locked="..tostring(self.db.ui.buttonLocked)
    lines[#lines+1]=T("Keine Accountdaten, Tokens oder automatisch erfassten Charakternamen enthalten.")
    return table.concat(lines,"\n")
end

function FG:Ask(raw)
    raw = FG.Trim(raw)
    if raw=="" then self:Toggle(); return end
    local head,tail = raw:match("^(%S+)%s*(.-)$")
    head,tail=FG.Normalize(head),tail or ""
    head=FG.CommandAliases[head] or head
    local query=FG.Normalize(raw)
    if head=="live" or head=="ki" then self:LiveCommand(tail); return end
    if head=="modelle" or head=="models" then
        if not self:LiveQuestion("__foreverai_catalog__") then self:Say("Live-KI zuerst aktivieren: /fai live an") end
        return
    end
    if head=="navi" or head=="navigation" or head=="guide" or head=="wegfuehrung" or head=="wegfindung" then self:GuidanceCommand(tail); return end
    if head=="pause" then self:PauseNavigation(true); return end
    if head=="resume" or head=="fortsetzen" then self:PauseNavigation(false); return end
    if head=="hinweis" or head=="note" then self:NotePoint(tail); return end
    if head=="button" or head=="knopf" then self:LauncherCommand(tail); return end
    if head=="resetui" then self:ResetUIPositions(); return end
    if head=="modell" or head=="model" then
        if tail=="" then self:Say(self:AISettingsText()) else self:SelectModel(tail) end; return
    end
    if head=="reasoning" or head=="denken" then
        if tail=="" then self:Say(self:AISettingsText()) else self:SelectEffort(tail) end; return
    end
    if head=="benchmark" or head=="testplan" then self:ShowTransfer("export",self:BenchmarkPlan()); return end
    if head=="clear" or head=="leeren" then self:ClearChat(); return end
    if head=="sprache" then self:SetLanguage(tail); return end
    if head=="begriff" then self:ShowTerms(tail); return end
    if head=="alias" then self:AddQuestAlias(tail); return end
    if head=="hilfe" or head=="help" then self:Help(); return end
    if head=="daten" or head=="data" or head=="sync" then self:Say(self:SyncedDataStatus()); return end
    if head=="stopp" or head=="stop" then self:StopNavigation(); return end
    if head=="diagnose" then self:ShowTransfer("export",self:Diagnostic()); return end
    if self:InCombat() then self:Say(T("ForeverAI pausiert im Kampf. Danach erneut versuchen.")); return end
    if head=="test" then self:TestNavigation(); return end
    if FG.PositionQueries[query] then self:Say(self:PositionText()); return end
    if head=="merken" then self:SavePlace(tail); return end
    if head=="liste" then self:ListPlaces(); return end
    if head=="entfernen" then
        local key=FG.Normalize(tail)
        if not self:NameTaken(key) then self:Say(T("Kein Eintrag mit diesem genauen Namen.")); return end
        self.db.places[key],self.db.routes[key]=nil,nil
        self:Say(T("Eigener Eintrag entfernt: ") .. FG.Clean(tail,100)); return
    end
    if head=="ziel" then
        local p,err=FG.ParsePoint(tail)
        if not p then self:Say(err); return end
        if self.chatSubmitting then self:OfferNavigation({name=p.label,points={p}}); return end
        local ok,why=self:StartNavigation({name=p.label,points={p}})
        if not ok then self:Say(why) end
        return
    end
    if head=="weiter" then self:Advance(1); return end
    if head=="zurueck" then self:Advance(-1); return end
    if head=="karte" then self:OpenTargetMap(); return end
    if head=="aufnahme" then self:BeginRecording(tail); return end
    if head=="punkt" then self:RecordPoint(tail); return end
    if head=="speichern" then self:SaveRecording(); return end
    if head=="abbrechen" then self.recording=nil; self:Say(T("Routenaufnahme verworfen.")); return end
    if head=="sichern" then
        local name=FG.Clean(tail,100)
        if not self.nav then self:Say(T("Keine aktive Route zum Speichern.")); return end
        if FG.Normalize(name)=="" or self:NameTaken(FG.Normalize(name)) then self:Say(T("Bitte einen neuen, noch nicht verwendeten Namen angeben.")); return end
        local r,err=self:CheckRoute({name=name,points=self.nav.points})
        if not r then self:Say(err); return end
        self.db.routes[FG.Normalize(name)]=r
        self:Say(T("Route gespeichert: ") .. name); return
    end
    if head=="route" or head=="gehe" then
        if not self:StartSaved(tail,false,self.chatSubmitting) then self:Say(T("Kein eigener Ort / keine Route gefunden. /fai liste zeigt deine Einträge.")) end
        return
    end
    if head=="ausruestung" or head=="ausrüstung" or head=="equipment" or head=="gear" then self:AskEquipment(); return end
    if head=="taschen" or head=="tasche" or head=="bags" or head=="inventory" or head=="inventar" then self:AskBagItems(); return end
    if head=="suche" or head=="search" or head=="find" then
        if not self:SearchLocationResults(tail) then self:Say(self.locale=="deDE" and "Keine Kartenposition gefunden. Für NPCs kann QuestieDB Forever helfen, oder einen eigenen Ort speichern." or "No mapped location found. QuestieDB Forever may help with NPCs, or save your own location.") end
        return
    end
    if head=="quests" then
        local qs=self:GetQuests()
        if #qs==0 then self:Say(T("Keine lesbaren Quests im aktuellen Questlog.")) end
        for _,q in ipairs(qs) do self:Say(q.id .. " — " .. q.title) end
        return
    end
    if head=="quest" then self:FindQuest(tail,false,self.chatSubmitting); return end
    if head=="import" then self:ShowTransfer("import",""); return end
    if head=="export" then self:ShowTransfer("export",self:BuildContext(tail)); return end
    if head=="routenexport" then
        if not self.nav then self:Say(T("Erst eine gespeicherte Route oder ein Ziel starten.")); return end
        self:ShowTransfer("export",FG.SerializeRoute(self.nav)); return
    end
    self.lastQuestion=raw
    if not self.chatSubmitting then self:Say(T("Frage: ") .. FG.Clean(raw,400)) end
    self.destination=nil; self:RefreshDestination()
    if self:StartSaved(raw,false,true) then return end
    if self:FindQuest(raw,true,true) then return end
    if self.AnswerQuestieItems and self:AnswerQuestieItems(raw) then return end
    if self:SearchSynced(raw) then return end
    if self:WeaponSuggestions(raw) then
        self:SearchLocationResults(raw)
        return
    end
    local localAnswer=self:KnowledgeAnswer(raw)
    local locations=self:SearchLocationResults(raw)
    if localAnswer or locations then return end
    if self.chatSubmitting and self:LiveQuestion(raw) then return end
    self:Say(self.locale=="deDE" and "Keine passende lokale Antwort gefunden. Für KI-Antworten unter Einstellungen die Live-KI einschalten und den KI-Zugang in der Begleit-App verbinden." or "No matching local answer found. For AI answers, enable Live AI in Settings and connect an AI provider in the companion app.")
end
