local _, FG = ...
local T = FG.T

local function panel(name, width, height)
    local f = CreateFrame("Frame",name,UIParent,BackdropTemplateMixin and "BackdropTemplate" or nil)
    f:SetSize(width,height)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) self:StartMoving() end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    if f.SetBackdrop then
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",tile=false,edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
        f:SetBackdropColor(0.035,0.05,0.075,0.97)
        f:SetBackdropBorderColor(0.25,0.55,0.75,1)
    end
    return f
end

local function label(parent,text,x,y,width,font)
    local t = parent:CreateFontString(nil,"OVERLAY",font or "GameFontHighlight")
    t:SetPoint("TOPLEFT",x,y)
    t:SetWidth(width)
    t:SetJustifyH("LEFT")
    FG:BindText(t,text)
    return t
end

local function button(parent,text,x,y,width,callback)
    local b = CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,26)
    b:SetPoint("BOTTOMLEFT",x,y)
    FG:BindText(b,text)
    b:SetScript("OnClick",callback)
    return b
end

local function closeButton(parent,callback)
    local b = CreateFrame("Button",nil,parent,"UIPanelCloseButton")
    b:SetPoint("TOPRIGHT",-3,-3)
    b:SetScript("OnClick",callback or function() parent:Hide() end)
end

function FG:CreateMain()
    if self.window then return end
    local f=panel("ForeverAIWindow",680,620)
    self.window=f
    f.views={}
    for _,name in ipairs({"chat","navigation","settings"}) do
        local view=CreateFrame("Frame",nil,f)
        view:SetAllPoints(f)
        f.views[name]=view
    end
    local chatView,navView,settings=f.views.chat,f.views.navigation,f.views.settings
    self:RestoreWidgetPosition(f,"window")
    f:SetScript("OnDragStop",function(frame) frame:StopMovingOrSizing(); self:SaveWidgetPosition(frame,"window") end)
    f:SetScript("OnHide",function(frame)
        frame:StopMovingOrSizing(); self:SaveWidgetPosition(frame,"window")
        if self.input then self.input:ClearFocus() end
        if self.optionMenu then self.optionMenu:Hide() end
    end)
    label(f,"ForeverAI · Chat",20,-18,370,"GameFontNormalLarge")
    label(settings,"Modell",20,-90,305,"GameFontHighlightSmall")
    label(settings,"Reasoning",345,-90,315,"GameFontHighlightSmall")
    self.modelButton=button(settings,"",20,488,305,function()
        local entries={}
        for _,model in ipairs(self.ModelCandidates) do entries[#entries+1]={value=model.id,label=T(model.name)} end
        self:ShowOptions(self.modelButton,entries,self.db.ai.model,function(value) self:SelectModel(value) end)
    end)
    self.effortButton=button(settings,"",345,488,315,function()
        local entries={}
        for _,value in ipairs(self:FindModel(self.db.ai.model).efforts) do entries[#entries+1]={value=value,label=T(self.EffortLabels[value])} end
        self:ShowOptions(self.effortButton,entries,self.db.ai.effort,function(value) self:SelectEffort(value) end)
    end)
    local note=label(settings,"KI-Zugang in der Begleit-App verbinden; Modellkatalog im Spiel laden.",20,-145,640,"GameFontHighlightSmall")
    note:SetHeight(30); note:SetJustifyV("TOP")
    local chat=CreateFrame("ScrollingMessageFrame",nil,chatView)
    chat:SetPoint("TOPLEFT",20,-85)
    chat:SetSize(640,390)
    chat:SetFontObject(ChatFontNormal or GameFontHighlight)
    chat:SetJustifyH("LEFT"); chat:SetFading(false); chat:SetMaxLines(120); chat:SetSpacing(5)
    chat:EnableMouseWheel(true)
    chat:SetScript("OnMouseWheel",function(frame,delta) if delta>0 then frame:ScrollUp() else frame:ScrollDown() end end)
    if type(chat.SetHyperlinksEnabled)=="function" then chat:SetHyperlinksEnabled(true) end
    chat:EnableMouse(true)
    chat:SetScript("OnHyperlinkClick",function(_,link) self:OpenChatTarget(link) end)
    self.chat=chat; self:RedrawChat()
    self.destinationTitle=label(navView,"Noch kein Ziel ausgewählt",20,-100,640,"GameFontNormal")
    self.destinationTitle:SetHeight(22)
    self.destinationDetails=label(navView,"",20,-135,580,"GameFontHighlightSmall")
    self.destinationDetails:SetHeight(56); self.destinationDetails:SetJustifyV("TOP")
    self.guideButton=button(navView,"Wegführung starten",20,335,200,function() self:StartDestination() end)
    button(navView,"Pause / Fortsetzen",230,335,200,function() self:PauseNavigation() end)
    button(navView,"Stopp",440,335,200,function() self:StopNavigation() end)
    button(navView,"Weiter",20,295,200,function() self:Advance(1) end)
    button(navView,"Karte",230,295,200,function() self:OpenTargetMap() end)
    self.activeQuestsButton=button(navView,"Aktive Quests",20,245,200,function() self:ShowActiveQuestList() end)
    self.levelDungeonsButton=button(navView,"Dungeons für mein Level",230,245,200,function() self:ShowLevelDungeonList() end)
    local edit=CreateFrame("EditBox",nil,chatView,"InputBoxTemplate")
    edit:SetSize(520,28); edit:SetPoint("BOTTOMLEFT",25,80)
    edit:SetAutoFocus(false); edit:SetMaxLetters(512)
    edit:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
    edit:SetScript("OnArrowPressed",function(_,key) self:ChatHistory(key) end)
    local submit=function()
        if self:SubmitChat(edit:GetText()) then edit:SetText("") end
        edit:ClearFocus()
    end
    edit:SetScript("OnEnterPressed",submit)
    self.input=edit
    self.sendButton=button(chatView,"Senden",560,80,100,submit)
    local contextButton
    contextButton=button(settings,"",20,380,265,function()
        self.db.shareContext=self.db.shareContext==false
        contextButton:SetText(self.db.shareContext==false and "Spielkontext: AUS" or "Spielkontext: AN")
    end)
    contextButton:SetText(self.db.shareContext==false and "Spielkontext: AUS" or "Spielkontext: AN")
    button(settings,"Test",20,200,100,function() self:TestNavigation() end)
    button(settings,"Position",130,200,120,function() self:Say(self:PositionText()) end)
    button(settings,"Merken",260,200,100,function() self:SavePlace(edit:GetText()) end)
    button(settings,"KI-Modelle",20,430,200,function() self:Ask("modelle") end)
    button(settings,"Import",20,240,100,function() self:ShowTransfer("import","") end)
    button(settings,"Hilfe",130,240,120,function() self:Help() end)
    button(settings,"Diagnose",260,240,140,function() self:ShowTransfer("export",self:Diagnostic()) end)
    button(chatView,"Ziele suchen",430,35,230,function()
        local query=edit:GetText()~="" and edit:GetText() or self.lastQuestion or "dungeons"
        if not self:SearchLocationResults(query) and not self:StartSaved(query,false,true)
            and not self:FindQuest(query,true,true) then
            self:Say(self.locale=="deDE" and "Kein Ziel gefunden. Versuche 'Todesminen', einen Questtitel oder 'Kriegerlehrer Sturmwind' (QuestieDB optional)." or
                "No target found. Try 'Deadmines', a quest title or 'Warrior Trainer Stormwind' (optional QuestieDB).")
        end
    end)
    self.clearChatButton=button(settings,"Verlauf löschen",20,155,165,function() self:ClearChat() end)
    self.liveButton=button(settings,"Live-KI: AUS",230,430,225,function() self:LiveCommand(self.db.liveEnabled and "aus" or "an") end)
    self.resetUIButton=button(settings,"Button/Fenster zurücksetzen",195,155,230,function() self:ResetUIPositions() end)
    self.languageButton=button(settings,"DE / EN",300,380,115,function() self:CycleLanguage() end)
    button(f,"Chat",20,545,120,function() self:SetMainView("chat") end)
    button(f,"Navigation",150,545,120,function() self:SetMainView("navigation") end)
    button(f,"Einstellungen",280,545,140,function() self:SetMainView("settings") end)
    closeButton(f)
    if UISpecialFrames then table.insert(UISpecialFrames,"ForeverAIWindow") end
    self:RefreshLocale(); self:RefreshAIControls(); self:RefreshDestination(); self:UpdateLiveButton()
    self:SetMainView("chat")
    f:Hide()
end

function FG:SetMainView(name)
    if not self.window or not self.window.views then return end
    self.activeView=name
    self.activeSubview=nil
    if self.optionMenu then self.optionMenu:Hide() end
    if self.searchFrame then self.searchFrame:Hide() end
    if self.transfer then self.transfer:Hide() end
    for key,view in pairs(self.window.views) do if key==name then view:Show() else view:Hide() end end
end

function FG:ShowSubview(name)
    self.activeSubview=name
    if self.optionMenu then self.optionMenu:Hide() end
    if name~="search" and self.searchFrame then self.searchFrame:Hide() end
    if name~="transfer" and self.transfer then self.transfer:Hide() end
    for _,view in pairs(self.window.views) do view:Hide() end
end

function FG:CloseSubview(name)
    if self.activeSubview~=name then return end
    self.activeSubview=nil
    local view=self.window and self.window.views and self.window.views[self.activeView or "chat"]
    if view then view:Show() end
end

-- A small, dependency-free menu, rather than a Retail-only menu API.
function FG:ShowOptions(owner,entries,selected,callback)
    if not self.optionMenu then
        local f=panel("ForeverAIOptions",315,100)
        f:SetParent(self.window); f:SetMovable(false); f:RegisterForDrag()
        f:SetFrameStrata("FULLSCREEN_DIALOG"); f.rows={}
        self.optionMenu=f
        if UISpecialFrames then table.insert(UISpecialFrames,"ForeverAIOptions") end
        f:Hide()
    end
    local f=self.optionMenu
    if f:IsShown() and f.owner==owner then f:Hide(); return end
    f.owner=owner
    f:ClearAllPoints(); f:SetPoint("TOPLEFT",owner,"BOTTOMLEFT",0,-2)
    f:SetSize(owner:GetWidth(),#entries*30+12)
    for _,row in ipairs(f.rows) do row:Hide() end
    for i,entry in ipairs(entries) do
        local row=f.rows[i]
        if not row then row=CreateFrame("Button",nil,f,"UIPanelButtonTemplate"); f.rows[i]=row end
        local value=entry.value
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",6,-6-(i-1)*30)
        row:SetSize(owner:GetWidth()-12,26)
        row:SetText((value==selected and "> " or "")..entry.label)
        row:SetScript("OnClick",function() f:Hide(); callback(value) end)
        row:Show()
    end
    f:Show()
end

function FG:RefreshAIControls()
    if not self.db or not self.db.ai then return end
    local model=self:FindModel(self.db.ai.model)
    if self.modelButton then self.modelButton:SetText(T(model.name).."  v") end
    if self.effortButton then self.effortButton:SetText(T(self.EffortLabels[self.db.ai.effort]).."  v") end
end

function FG:CreateLauncher()
    if self.launcher then return end
    local b=CreateFrame("Button","ForeverAILauncher",UIParent,"UIPanelButtonTemplate")
    self.launcher=b
    b:SetSize(50,46); b:SetText("FAI"); b:SetFrameStrata("HIGH")
    b:SetClampedToScreen(true); b:SetMovable(true); b:EnableMouse(true)
    b:RegisterForDrag("LeftButton"); b:RegisterForClicks("LeftButtonUp","RightButtonUp")
    self:RestoreWidgetPosition(b,"launcher")
    b:SetScript("OnMouseDown",function(frame) frame.suppressClick=false end)
    b:SetScript("OnDragStart",function(frame)
        if self.db.ui.buttonLocked then return end
        frame.dragging=true; frame:StartMoving()
    end)
    b:SetScript("OnDragStop",function(frame)
        if not frame.dragging then return end
        frame:StopMovingOrSizing(); frame.dragging=false; frame.suppressClick=true
        self:SaveWidgetPosition(frame,"launcher")
    end)
    b:SetScript("OnClick",function(frame,mouseButton)
        if frame.suppressClick then frame.suppressClick=false; return end
        if mouseButton=="RightButton" then
            self.db.ui.buttonLocked=not self.db.ui.buttonLocked
            self:Say(T(self.db.ui.buttonLocked and "Buttonposition gesperrt. Rechtsklick entsperrt." or "Button beweglich: linke Maustaste halten und ziehen. Rechtsklick sperrt."))
        else self:Toggle() end
    end)
    b:SetScript("OnEnter",function(frame)
        if not GameTooltip then return end
        GameTooltip:SetOwner(frame,"ANCHOR_LEFT"); GameTooltip:SetText("ForeverAI")
        GameTooltip:AddLine(T("Linksklick: Chat öffnen/schließen."),1,1,1)
        GameTooltip:AddLine(T(self.db.ui.buttonLocked and "Rechtsklick: Position entsperren." or "Ziehen: verschieben. Rechtsklick: Position sperren."),1,1,1)
        GameTooltip:AddLine(self:LiveStatus(),1,.75,.35,true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    b:SetScript("OnHide",function(frame)
        if frame.dragging then frame:StopMovingOrSizing(); frame.dragging=false; self:SaveWidgetPosition(frame,"launcher") end
        if GameTooltip then GameTooltip:Hide() end
    end)
    if self.db.ui.buttonVisible then b:Show() else b:Hide() end
end

function FG:Toggle()
    self:CreateMain()
    if self.window:IsShown() then self.window:Hide() else self.window:Show() end
end

function FG:CreateArrow()
    if self.arrow then return end
    local f=panel("ForeverAIArrow",300,145)
    self.arrow=f
    self:RestoreWidgetPosition(f,"arrow")
    f:SetFrameStrata("HIGH")
    f:SetScript("OnDragStop",function(frame) frame:StopMovingOrSizing(); self:SaveWidgetPosition(frame,"arrow") end)
    f:SetScript("OnHide",function(frame) frame:StopMovingOrSizing(); self:SaveWidgetPosition(frame,"arrow") end)
    f.title=label(f,"Navigation",16,-14,300,"GameFontNormalLarge"); f.title:SetHeight(32)
    f.mode=label(f,"",16,-42,268,"GameFontHighlightSmall"); f.mode:SetHeight(22); f.mode:SetJustifyV("TOP")
    local area=CreateFrame("Frame",nil,f)
    area:SetSize(88,72); area:SetPoint("TOPLEFT",20,-88)
    f.area,f.lines=area,{}
    if type(area.CreateLine)=="function" then
        for i=1,3 do
            local line=area:CreateLine(nil,"OVERLAY"); line:SetThickness(5); line:SetColorTexture(0.35,0.8,1,1); f.lines[i]=line
        end
    end
    area:ClearAllPoints(); area:SetPoint("TOPLEFT",16,-63)
    f.distance=label(f,"",110,-66,175,"GameFontNormalLarge"); f.distance:SetHeight(26)
    f.instruction=label(f,"",110,-94,175,"GameFontHighlight"); f.instruction:SetHeight(42)
    f.note=label(f,"",16,-174,328,"GameFontHighlightSmall"); f.note:SetHeight(36); f.note:SetJustifyV("TOP")
    f.nextPoint=label(f,"",16,-215,328,"GameFontHighlightSmall"); f.nextPoint:SetHeight(30)
    f.step=label(f,"",16,-251,328,"GameFontHighlightSmall"); f.step:SetHeight(30)
    f.note:Hide(); f.nextPoint:Hide(); f.step:Hide()
    button(f,"Zurück",16,42,74,function() self:Advance(-1) end):Hide()
    f.pause=button(f,"Pause",96,42,84,function() self:PauseNavigation() end)
    f.nextButton=button(f,"Weiter",186,42,78,function() self:Advance(1) end)
    button(f,"Karte",270,42,74,function() self:OpenTargetMap() end):Hide()
    f.native=button(f,"Weltsymbol: aus",16,10,174,function() self:ToggleWorldMarker() end)
    button(f,"Stopp",200,10,144,function() self:StopNavigation() end):Hide()
    f.pause:Hide(); f.nextButton:Hide(); f.native:Hide()
    closeButton(f,function() self:StopNavigation() end)
end

function FG:ArrowState(right,forward,text)
    local f = self.arrow
    if not f then return end
    f.distance:SetText(text or "")
    if not right then
        for _,line in ipairs(f.lines) do line:Hide() end
        return
    end
    local sx,sy = -right*25,-forward*25
    local tx,ty = right*28,forward*28
    local bx,by = tx-right*15,ty-forward*15
    local perpendicularX,perpendicularY = -forward*12,right*12
    local points = {
        {sx,sy,tx,ty},
        {tx,ty,bx+perpendicularX,by+perpendicularY},
        {tx,ty,bx-perpendicularX,by-perpendicularY},
    }
    for i,line in ipairs(f.lines) do
        local p = points[i]
        line:SetStartPoint("CENTER",f.area,p[1],p[2])
        line:SetEndPoint("CENTER",f.area,p[3],p[4])
        line:Show()
    end
    if #f.lines == 0 then f.distance:SetText(T("Pfeilzeichnung nicht verfügbar · ") .. (text or "")) end
end

function FG:RefreshTransferLocale()
    local f = self.transfer
    if not f then return end
    local mode = f.mode
    if mode == "import" then
        f.title:SetText(T("Antwort, Modellliste oder Route importieren"))
        f.hint:SetText(T("FGA1: KI-Antwort. FGC1: Modellliste. FGS1: Online-Treffer. FG1/FG2: Route. Nur Daten, keine Programme. KI-Inhalte und Begehbarkeit werden nicht verifiziert."))
        f.preview:SetText(T("Noch nicht geprüft. Es wird kein Lua-Code ausgeführt."))
        f.check:Show(); f.start:Show()
    else
        f.title:SetText(T("Text zum Kopieren"))
        f.hint:SetText(T("Alles markieren → Strg+C → außerhalb von WoW einfügen. Keine automatische Übertragung; keine Anmeldung und kein Token im Addon."))
        f.preview:SetText(T("Prüfe den Text vor dem Weitergeben. Namen und Accountdaten werden nicht automatisch exportiert."))
        f.check:Hide(); f.start:Hide()
    end
end

function FG:ShowTransfer(mode,text)
    if not self.transfer then
        self:CreateMain()
        local f = panel("ForeverAITransfer",660,530)
        f:SetParent(self.window); f:ClearAllPoints(); f:SetPoint("TOP",self.window,"TOP",0,-78); f:SetMovable(false); f:RegisterForDrag()
        f:SetScript("OnHide",function() self:CloseSubview("transfer") end)
        self.transfer = f
        f.title = label(f,"Import / Export",20,-18,600,"GameFontNormalLarge")
        f.hint = label(f,"",20,-49,610,"GameFontHighlightSmall")
        f.hint:SetHeight(42)
        local scroll = CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",23,-99)
        scroll:SetSize(586,285)
        local edit = CreateFrame("EditBox",nil,scroll)
        edit:SetMultiLine(true)
        edit:SetAutoFocus(false)
        edit:SetFontObject(ChatFontNormal or GameFontHighlight)
        edit:SetSize(580,285)
        edit:SetMaxLetters(self.MAX_IMPORT)
        edit:SetTextInsets(3,3,3,3)
        scroll:SetScrollChild(edit)
        edit:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        edit:SetScript("OnTextChanged",function(e,userInput)
            if userInput then
                f.checked = nil
                f.start:Disable()
                f.preview:SetText(T("Nach jeder Änderung erneut prüfen."))
            end
            local lines = 1
            for line in (e:GetText() .. "\n"):gmatch("([^\n]*)\n") do
                lines = lines + math.max(1,math.ceil(#line/70))
            end
            e:SetHeight(math.max(285,lines*17))
        end)
        edit:SetScript("OnCursorChanged",function(_,x,y,width,height)
            local offset = scroll:GetVerticalScroll()
            local cursor = -y
            if cursor < offset then scroll:SetVerticalScroll(math.max(0,cursor))
            elseif cursor+height > offset+285 then scroll:SetVerticalScroll(math.max(0,cursor+height-285)) end
        end)
        f.edit, f.scroll = edit, scroll
        f.preview = label(f,"",20,-402,610,"GameFontHighlightSmall")
        f.preview:SetHeight(65)
        f.preview:SetJustifyV("TOP")
        f.check = button(f,"Prüfen",20,20,100,function()
            local raw=FG.Trim(edit:GetText())
            local checked,why
            if raw:find("FGA1;",1,true) or raw:find("FGC1;",1,true) or raw:find("FGS1;",1,true) then
                if raw:find("FGS1;",1,true) then checked,why=FG.ParseOnlineResults(raw)
                elseif raw:find("FGA1;",1,true) then checked,why=FG.ParseReply(raw) else checked,why=FG.ParseCatalog(raw) end
                f.checked=checked
                if not checked then f.start:Disable();f.preview:SetText(T("Nicht importiert: ")..tostring(why));return end
                if checked.bridgeType=="online" then
                    f.preview:SetText((self.locale=="deDE" and "Online-Treffer (Quelle laut Import): " or "Online results (source claimed by import): ")..#checked.rows.." · "..checked.updatedAt.."\n"..
                        (self.locale=="deDE" and "Nur bestätigte Kartenpunkte aus Client/eigener Datenbank sind navigierbar. Erst Treffer anklicken." or "Only client or previously mapped targets can be navigated. Choose a result."))
                elseif checked.bridgeType=="reply" then
                    f.preview:SetText(T("Ungeprüfte KI-Antwort: ")..checked.provider.." / "..checked.model.."\n"..FG.Clean(checked.text,350))
                else f.preview:SetText(T("Modellkatalog: ")..checked.provider.." · "..#checked.models..T(" Modelle. Verbindung und Verfügbarkeit in der Begleit-App prüfen.")) end
                f.start:SetText(T("Übernehmen"));f.start:Enable();return
            end
            f.start:SetText(T("Navigation starten"))
            local route,err = FG.ParseImport(raw)
            if route then route,err = self:CheckRoute(route) end
            f.checked = route
            if not route then
                f.start:Disable()
                f.preview:SetText(T("Nicht importiert: ") .. tostring(err))
                return
            end
            local lines = {route.name .. " · " .. #route.points .. T(" Punkte · Keine Prüfung der Begehbarkeit.")}
            for i=1,math.min(#route.points,4) do
                local p = route.points[i]
                local info = self:MapInfo(p.mapID)
                lines[#lines+1] = string.format("%d. %s — %s (%d), %.1f / %.1f",i,p.label,FG.Clean(info.name,60),p.mapID,p.x*100,p.y*100)
            end
            if #route.points > 4 then lines[#lines+1] = T("Weitere Punkte stehen im Textfeld oben.") end
            f.preview:SetText(table.concat(lines,"\n"))
            f.start:Enable()
        end)
        f.start = button(f,"Navigation starten",130,20,180,function()
            if not f.checked then return end
            if f.checked.bridgeType=="reply" then self:ApplyReply(f.checked);f:Hide();return end
            if f.checked.bridgeType=="catalog" then self:ApplyCatalog(f.checked);f:Hide();return end
            if f.checked.bridgeType=="online" then if self:ApplyOnlineResults(f.checked) then f:Hide() end; return end
            local ok,err = self:StartNavigation(f.checked)
            if ok then f:Hide() else f.preview:SetText(err) end
        end)
        f.select = button(f,"Alles markieren",320,20,150,function() edit:SetFocus(); edit:HighlightText() end)
        button(f,"Schließen",480,20,150,function() f:Hide() end)
        closeButton(f)
        f:Hide()
    end
    local f = self.transfer
    f.mode, f.checked = mode,nil
    f.start:Disable()
    f.edit:SetText(text or "")
    f.edit:SetCursorPosition(0)
    f.scroll:SetVerticalScroll(0)
    self:RefreshTransferLocale()
    self.window:Show()
    self:ShowSubview("transfer")
    f:Show()
    f.edit:SetFocus()
end

-- Search results are actual clickable buttons; text in ScrollingMessageFrame
-- remains plain text and is never interpreted as executable commands.
function FG:ShowSearchResults(results,query,options)
    if type(results)~="table" or #results==0 then return false end
    if not self.searchFrame then
        self:CreateMain()
        local f=panel("ForeverAISearchResults",565,410)
        f:SetParent(self.window); f:ClearAllPoints(); f:SetPoint("TOP",self.window,"TOP",0,-85); f:SetMovable(false); f:RegisterForDrag()
        f:SetScript("OnHide",function() self:CloseSubview("search") end)
        self.searchFrame=f
        f.title=label(f,"",20,-16,490,"GameFontNormalLarge")
        f.subtitle=label(f,"",20,-45,525,"GameFontHighlightSmall")
        f.info=label(f,"",20,-312,525,"GameFontHighlightSmall")
        f.info:SetHeight(32); f.info:SetJustifyV("TOP")
        f.rows={}
        for i=1,8 do
            local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
            b:SetSize(520,29)
            b:SetPoint("TOPLEFT",20,-74-(i-1)*29)
            local text=b.GetFontString and b:GetFontString()
            if text then
                text:ClearAllPoints();text:SetPoint("LEFT",b,"LEFT",10,0);text:SetPoint("RIGHT",b,"RIGHT",-10,0)
                if text.SetWordWrap then text:SetWordWrap(false) end
                if text.SetMaxLines then text:SetMaxLines(1) end
                text:SetJustifyH("LEFT")
            end
            b:SetScript("OnClick",function()
                local selected=f.results and f.results[(f.page-1)*8+i]
                if not selected then return end
                if f.directStart then
                    if selected.activeQuestID then
                        local outcome=self:StartActiveQuest(selected.activeQuestID,selected.name,true)
                        if outcome=="started" then f:Hide();self:SetMainView("navigation")
                        elseif outcome~="select" then f.info:SetText(self.locale=="deDE" and "Für diese Quest ist derzeit kein verwendbares Ziel verfügbar." or "No usable destination is currently available for this quest.") end
                    elseif selected.route then
                        local ok,err=self:StartNavigation(selected.route)
                        if ok then f:Hide();self:SetMainView("navigation") else f.info:SetText(FG.Clean(err,180)) end
                    end
                    return
                end
                local ok=selected.route and self:OfferNavigation(selected.route)
                if ok then
                    f.selected=selected
                    local source=selected.source or "?"
                    local hasPath=_G.ShortestPathForever and _G.ShortestPathForever.API
                    f.info:SetText((self.locale=="deDE" and "Ausgewählt: " or "Selected: ")..
                        FG.Clean(selected.name,100).." · "..source.."\n"..
                        (hasPath and (self.locale=="deDE" and "Wegberechnung durch Shortest Path Forever." or "Route planning by Shortest Path Forever.") or
                        (self.locale=="deDE" and "Quelle/Position nachprüfen. Luftlinie statt Fußweg." or
                            "Verify source and position. Straight line, not a walking route.")))
                    f.start:Enable()
                else
                    f.selected=nil;f.start:Disable()
                    self.destination=nil;self:RefreshDestination()
                    f.info:SetText((self.locale=="deDE" and "Nur Information: keine überprüfte Kartenposition für " or "Information only: no verified map position for ")..
                        FG.Clean(selected.name,100).."\n"..FG.Clean(selected.detail,180))
                end
            end)
            f.rows[i]=b
        end
        f.prev=button(f,"",20,12,100,function()
            if f.page>1 then f.page=f.page-1; self:RefreshSearchResults() end
        end)
        f.next=button(f,"",130,12,100,function()
            if f.page*8<#(f.results or {}) then f.page=f.page+1; self:RefreshSearchResults() end
        end)
        f.start=button(f,"",250,12,290,function()
            if f.selected and self:StartDestination() then f:Hide(); self:SetMainView("navigation") end
        end)
        closeButton(f)
        f:Hide()
    end
    local f=self.searchFrame
    f.results=results;f.query=FG.Clean(query,160);f.page=1;f.selected=nil;f.directStart=type(options)=="table" and options.directStart==true
    self:RefreshSearchResults()
    self.window:Show()
    self:ShowSubview("search")
    f:Show()
    return true
end

function FG:ShowActiveQuestList()
    local rows={}
    for _,quest in ipairs(self:GetQuests()) do
        rows[#rows+1]={name=quest.title,detail=(self.locale=="deDE" and "Aktive Quest #" or "Active quest #")..quest.id,activeQuestID=quest.id}
    end
    if #rows==0 then
        local message=self.locale=="deDE" and "Keine aktiven Quests im Questlog gefunden." or "No active quests found in the quest log."
        self:Say(message);if self.destinationDetails then self.destinationDetails:SetText(message) end;return false
    end
    return self:ShowSearchResults(rows,self.locale=="deDE" and "Aktive Quests · Ziel anklicken" or "Active quests · click a destination",{directStart=true})
end

function FG:ShowLevelDungeonList()
    local level=FG.Safe(UnitLevel,"player")
    if not FG.IsNumber(level) then
        local message=self.locale=="deDE" and "Dein Level ist gerade nicht verfügbar." or "Your level is currently unavailable."
        self:Say(message);if self.destinationDetails then self.destinationDetails:SetText(message) end;return false
    end
    local rows={}
    for _,loc in ipairs(self.LocationPins or {}) do
        if FG.IsNumber(loc.min) and FG.IsNumber(loc.max) and level>=loc.min and level<=loc.max then
            local row=self:DungeonLocationResult(loc)
            if row then row.detail="Lv "..loc.min.."–"..loc.max.." · "..row.detail;rows[#rows+1]=row end
        end
    end
    table.sort(rows,function(a,b)return a.name<b.name end)
    if #rows==0 then
        local message=self.locale=="deDE" and "Für dein Level sind keine Dungeon-Eingänge mit Kartenposition hinterlegt." or "No mapped dungeon entrances are available for your level."
        self:Say(message);if self.destinationDetails then self.destinationDetails:SetText(message) end;return false
    end
    return self:ShowSearchResults(rows,(self.locale=="deDE" and "Dungeon-Ziele für Level " or "Dungeon destinations for level ")..level,{directStart=true})
end

function FG:RefreshSearchResults()
    local f=self.searchFrame
    if not f or not f.results then return end
    local english=self.locale~="deDE"
    f.title:SetText(english and "Search results" or "Suchergebnisse")
    f.subtitle:SetText((english and "Query: " or "Suche: ")..(f.query or "")..
        (english and " · click a result" or " · Treffer anklicken"))
    for i,b in ipairs(f.rows) do
        local r=f.results[(f.page-1)*8+i]
        if r then
            local display=FG.Clean(r.name,65).." — "..FG.Clean(r.detail or "",75)
            b:SetText(display)
            b:Show()
        else b:Hide() end
    end
    f.prev:SetText(english and "Previous" or "Zurück")
    f.next:SetText(english and "Next" or "Weiter")
    if f.page>1 then f.prev:Enable() else f.prev:Disable() end
    if f.page*8<#f.results then f.next:Enable() else f.next:Disable() end
    f.start:SetText(english and "Start guidance" or "Wegführung starten")
    if f.directStart then f.start:Hide() else f.start:Show() end
    if f.selected then f.start:Enable() else f.start:Disable() end
    if not f.selected then
        f.info:SetText(f.directStart and (english and "Click a result to start guidance when a destination is available. " or "Treffer anklicken, um die verfügbare Wegführung zu starten. ")..f.page.."/"..math.ceil(#f.results/8) or (english and "No target selected. Community pins are approximate; obstacles and zone changes need manual routing. " or
            "Noch kein Ziel gewählt. Community-Pins sind ungefähr; Hindernisse und Zonenwechsel benötigen eigene Wegpunkte. ")..
            f.page.."/"..math.ceil(#f.results/8))
    end
end

function FG:UpdateLiveButton()
    if self.liveButton then self.liveButton:SetText((self.locale=="deDE" and "Live-KI: " or "Live AI: ")..(self.db and self.db.liveEnabled and "AN" or "AUS")) end
end
