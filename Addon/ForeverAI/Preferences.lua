-- Local UI preferences only. This module does NOT authenticate or call a model.
-- Public model metadata checked on 2026-11-10. Account availability is UNKNOWN.
local _, FG = ...
local T = FG.T
FG.ModelCandidates = {
    {id="auto", name="Automatisch", efforts={"default","low","medium","high","xhigh","max"}},
    {id="gpt-6-luna", name="GPT-6 Luna", efforts={"default","none","low","medium","high","xhigh","max"}},
    {id="gpt-6.1-sol", name="GPT-6.1 Sol", efforts={"default","low","medium","high","xhigh","max"}},
    {id="gpt-6-astra", name="GPT-6 Astra", efforts={"default","low","medium","high","xhigh","max"}},
}
FG.EffortLabels = {default="Modellstandard", none="Ohne Reasoning", low="Niedrig", medium="Mittel", high="Hoch", xhigh="Sehr hoch", max="Maximum"}
local effortAliases = {auto="default",standard="default",modellstandard="default",niedrig="low",leicht="low",mittel="medium",hoch="high",["sehr hoch"]="xhigh",maximum="max",ohne="none"}

function FG:FindModel(id)
    for _,item in ipairs(self.ModelCandidates) do if item.id==id then return item end end
end

function FG:SupportsEffort(model,effort)
    local item=self:FindModel(model)
    if item then for _,value in ipairs(item.efforts) do if value==effort then return true end end end
    return false
end

function FG.ValidPosition(p)
    return type(p)=="table" and FG.IsNumber(p.x) and FG.IsNumber(p.y)
        and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end

function FG:InitPreferences()
    local old=type(self.db.ui)=="table" and self.db.ui or {}
    -- Copy only known data; positions are fractions of UIParent, never frame references.
    self.db.ui={buttonVisible=old.buttonVisible~=false, buttonLocked=old.buttonLocked==true}
    for _,key in ipairs({"launcher","window","arrow"}) do
        if FG.ValidPosition(old[key]) then self.db.ui[key]={x=old[key].x,y=old[key].y} end
    end
    local ai=type(self.db.ai)=="table" and self.db.ai or {}
    local model=self:FindModel(ai.model) and ai.model or (self:FindModel("auto") and "auto" or self.ModelCandidates[1].id)
    local effort=self:SupportsEffort(model,ai.effort) and ai.effort or "low"
    -- No passwords, tokens, model answers or network state in SavedVariables.
    self.db.ai={model=model, effort=effort}
    local navigation=type(self.db.navigation)=="table" and self.db.navigation or {}
    self.db.navigation={worldMarker=navigation.worldMarker==true}
    self.inputHistory=self.inputHistory or {}
    self.messageRoles=self.messageRoles or {}
end

function FG:SelectModel(id,quiet)
    id=FG.Trim(id):lower()
    if not self:FindModel(id) then
        self:Say(T("Unbekanntes Modell. Bitte einen Eintrag im Modellmenü auswählen.")); return false
    end
    self.db.ai.model=id
    local reset=not self:SupportsEffort(id,self.db.ai.effort)
    if reset then self.db.ai.effort=self:SupportsEffort(id,"low") and "low" or "default" end
    if self.RefreshAIControls then self:RefreshAIControls() end
    if not quiet then
        if self.db and self.db.liveEnabled and self.db.catalog then
            self:Say("Live-KI: Modell "..T(self:FindModel(id).name).." / "..T(self.EffortLabels[self.db.ai.effort])..". Gilt ab der nächsten Frage.")
        else self:Say(T("KI-Auswahl vorgemerkt: %s / %s. Noch keine KI-Verbindung.",T(self:FindModel(id).name),T(self.EffortLabels[self.db.ai.effort]))) end
        if reset then self:Say(T("Die vorherige Reasoning-Stufe passt nicht zu diesem Modell. Auf Niedrig zurückgesetzt.")) end
    end
    return true
end

function FG:SelectEffort(value,quiet)
    local key=FG.Normalize(value)
    local effort=effortAliases[key] or key
    if not self:SupportsEffort(self.db.ai.model,effort) then
        self:Say(T("Diese Reasoning-Stufe ist für die Modellauswahl nicht hinterlegt. Bitte das Reasoning-Menü verwenden.")); return false
    end
    self.db.ai.effort=effort
    if self.RefreshAIControls then self:RefreshAIControls() end
    if not quiet then
        if self.db and self.db.liveEnabled and self.db.catalog then
            self:Say("Live-KI: Reasoning "..T(self.EffortLabels[effort])..". Gilt ab der nächsten Frage.")
        else self:Say(T("Reasoning vorgemerkt: %s. Ändert keine lokalen Antworten und kein Modell im Browser.",T(self.EffortLabels[effort]))) end
    end
    return true
end

function FG:AISettingsText()
    local ai=self.db.ai
    if self.db.liveEnabled then
        return "Live-KI aktiviert: model="..ai.model.." | reasoning.effort="..ai.effort
            .."\nEin Modell aus /fai modelle kann bei kommenden Fragen über die Begleit-App benutzt werden. Ohne echten Katalog gilt die Modellwahl in der Begleit-App."
    end
    return T("KI-Wunscheinstellung (nicht aktiv): model=%s | reasoning.effort=%s",ai.model,ai.effort)
        .. "\n" .. T("Nur gespeicherte Präferenzen. Kein KI-Aufruf erfolgt; kopierter Text schaltet das Modell im ChatGPT-Browser nicht um.")
end

function FG:BenchmarkPlan()
    local lines={
        T("KI-Vergleich: noch nicht durchgeführt"),
        T("Ohne angemeldete Begleit-App gibt es keine gemessenen KI-Antwortzeiten oder Qualitätswerte. Dieser Button öffnet einen Testplan, keinen Live-Benchmark."),
        "",self:AISettingsText(),"",
        T("Kandidaten, sofern im angemeldeten Account verfügbar:"),
        "GPT-6 Luna: none / low / medium",
        "GPT-6.1 Sol: low / medium",
        "GPT-6 Astra: low ("..T("Vergleichsreferenz")..")",
        "",T("Testfälle jeweils auf Deutsch und Englisch:"),
        T("1. Lehrer anhand einer mitgelieferten, geprüften Ortsliste auswählen."),
        T("2. Quest anhand von ID und mitgeliefertem Questlog zuordnen."),
        T("3. Eine geprüfte Route Sturmwind–Todesminen erklären, ohne neue Koordinaten zu erfinden."),
        T("4. Krieger-Items anhand einer geprüften Gegenstandsliste und einer vorgegebenen Rolle vergleichen."),
        T("5. Bei fehlenden Kartendaten ausdrücklich kein Ziel erfinden."),
        T("6. Bei mehrdeutigem DM zuerst Todesminen oder Düsterbruch klären."),
        "",T("Messung: gleiche Daten und Antwortlänge, zufällige Reihenfolge, mehrere Wiederholungen. Zeit bis zum ersten Text und bis zur vollständigen Antwort getrennt messen."),
        T("Auswahlregel: erst Datenrichtigkeit, dann Geschwindigkeit. Fehlerhafte IDs, erfundene Koordinaten und unvollständige Antworten disqualifizieren eine Einstellung."),
        T("Bis zum echten Vergleich ist Niedrig nur ein Startwert, kein nachgewiesenes Optimum. Modellverfügbarkeit und erlaubte Stufen müssen bei der Anmeldung erneut geprüft werden."),
    }
    return table.concat(lines,"\n")
end

function FG:SaveWidgetPosition(frame,key)
    if not self.db or not self.db.ui or not frame then return false end
    local x,y=FG.Safe(frame.GetCenter,frame)
    local width=FG.Safe(UIParent.GetWidth,UIParent)
    local height=FG.Safe(UIParent.GetHeight,UIParent)
    local scale=FG.Safe(frame.GetEffectiveScale,frame) or 1
    local parentScale=FG.Safe(UIParent.GetEffectiveScale,UIParent) or 1
    if not FG.IsNumber(x) or not FG.IsNumber(y) or not FG.IsNumber(width) or not FG.IsNumber(height)
        or width<=0 or height<=0 or not FG.IsNumber(scale) or not FG.IsNumber(parentScale) or parentScale<=0 then return false end
    self.db.ui[key]={x=math.max(0,math.min(1,x*scale/parentScale/width)),y=math.max(0,math.min(1,y*scale/parentScale/height))}
    return true
end

function FG:RestoreWidgetPosition(frame,key)
    if not frame then return end
    local p=self.db and self.db.ui and self.db.ui[key]
    if not FG.ValidPosition(p) then p=key=="launcher" and {x=.86,y=.55} or key=="arrow" and {x=.72,y=.58} or {x=.5,y=.5} end
    local width=FG.Safe(UIParent.GetWidth,UIParent) or 0
    local height=FG.Safe(UIParent.GetHeight,UIParent) or 0
    frame:ClearAllPoints()
    if width>0 and height>0 then frame:SetPoint("CENTER",UIParent,"BOTTOMLEFT",width*p.x,height*p.y)
    else frame:SetPoint("CENTER",UIParent,"CENTER",key=="launcher" and 250 or 0,0) end
end

function FG:ResetUIPositions()
    self.db.ui.launcher,self.db.ui.window,self.db.ui.arrow,self.db.ui.search=nil,nil,nil,nil
    if self.arrow then self.arrow:StopMovingOrSizing(); self:RestoreWidgetPosition(self.arrow,"arrow") end
    if self.searchFrame then self.searchFrame:StopMovingOrSizing(); self:RestoreWidgetPosition(self.searchFrame,"search") end
    self.db.ui.buttonVisible=true
    if self.window then self.window:StopMovingOrSizing(); self:RestoreWidgetPosition(self.window,"window") end
    if self.launcher then self.launcher:StopMovingOrSizing(); self.launcher.dragging=false; self:RestoreWidgetPosition(self.launcher,"launcher"); self.launcher:Show() end
    self:Say(T("Button und Chatfenster wurden neu zentriert. Der Button ist wieder sichtbar."))
end

function FG:LauncherCommand(value)
    local key=FG.Normalize(value)
    if key=="reset" or key=="zuruecksetzen" then self:ResetUIPositions(); return end
    if key=="hide" or key=="ausblenden" then
        self.db.ui.buttonVisible=false
        if self.launcher then self.launcher:Hide() end
        self:Say(T("Button ausgeblendet. /fai button show blendet ihn wieder ein.")); return
    end
    if key=="lock" or key=="sperren" then self.db.ui.buttonLocked=true
    elseif key=="unlock" or key=="entsperren" then self.db.ui.buttonLocked=false
    elseif key=="" or key=="show" or key=="anzeigen" then
        self.db.ui.buttonVisible=true; self:CreateLauncher(); self.launcher:Show()
    else self:Say(T("Button: /fai button show | hide | lock | unlock | reset")); return end
    self:Say(T(self.db.ui.buttonLocked and "Buttonposition gesperrt. Rechtsklick entsperrt." or "Button beweglich: linke Maustaste halten und ziehen. Rechtsklick sperrt."))
end
