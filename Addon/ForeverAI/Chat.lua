-- Session-only conversation history. No account credentials or automated AI calls.
local _, FG = ...
local T = FG.T

function FG:ChatLine(index)
    local text=self.messages[index] or ""
    if self.messageRoles and self.messageRoles[index]=="target" then return text,false end
    local user=self.messageRoles and self.messageRoles[index]=="user"
    local prefix=user and T("Du") or (self.messageRoles and (self.messageRoles[index]=="ai" and T("KI · importiert, ungeprüft") or (self.messageRoles[index]=="ai_live" and "KI · Live" or T("ForeverAI · lokal"))))
    return prefix..": "..text,user
end

function FG:ResolveChatTargets(question)
    if self:InCombat() or FG.AmbiguousTerm(question) then return {} end
    local query=" "..FG.Normalize(question or "").." "
    local locationIntent=false
    for _,word in ipairs({"wo","wohin","where","finde","finden","find","suche","search","karte","map","route","wegfuehrung","navigation","navigate","ziel","npc","trainer","lehrer","quest","dungeon","instanz","eingang","entrance","location","koordinaten","coordinates","coords"}) do
        if query:find(" "..word.." ",1,true) then locationIntent=true;break end
    end
    local targets,seen={},{}
    local function add(row)
        local route=row and row.route
        local clean=route and self:CheckRoute(route)
        if not clean or not clean.points[1] then return end
        local p=clean.points[1]
        local key=tostring(p.mapID)..":"..string.format("%.4f:%.4f",p.x,p.y)
        if seen[key] or #targets>=4 then return end
        seen[key]=true
        targets[#targets+1]={name=FG.Clean(row.name or clean.name,80),source=FG.Clean(row.source or "",40),route=clean,detail=FG.Clean(row.detail or "",100)}
    end
    local cities={stormwind=1453,ironforge=1455,darnassus=1457,orgrimmar=1454,undercity=1458,thunderbluff=1456}
    -- A city used to qualify an NPC, quest or item is not the requested target.
    for _,word in ipairs({"npc","trainer","lehrer","ausbilder","quest","dungeon","instanz","eingang","entrance","item","gegenstand","waffe"}) do
        if query:find(" "..word.." ",1,true) then cities={};break end
    end
    for _,term in ipairs(FG.TermsIn(question)) do
        local id=cities[term.id]
        local info=id and FG.Safe(C_Map and C_Map.GetMapInfo,id)
        if id and type(info)=="table" and not FG.IsSecret(info) then
            local name=self.locale=="deDE" and term.de or term.en
            add({name=name,source="WoW Map",detail=self.locale=="deDE" and "Kartenmitte, ungefähres Ziel" or "Map center, approximate target",
                route={name=name,kind="waypoint",points={{mapID=id,x=0.5,y=0.5,label=name,note="Map center, approximate"}}}})
        end
    end
    if locationIntent and self.SearchLocationResults then
        local rows=self:SearchLocationResults(question,true)
        if type(rows)=="table" then for _,row in ipairs(rows) do add(row) end end
    end
    return targets
end

function FG:AddChatTargets(targets)
    self.chatTargetLinks=self.chatTargetLinks or {}
    self.chatTargetOrder=self.chatTargetOrder or {}
    for _,target in ipairs(targets or {}) do
        self.chatTargetSerial=(self.chatTargetSerial or 0)+1
        local id=self.chatTargetSerial
        self.chatTargetLinks[id]=target
        self.chatTargetOrder[#self.chatTargetOrder+1]=id
        if #self.chatTargetOrder>120 then self.chatTargetLinks[table.remove(self.chatTargetOrder,1)]=nil end
        local label=target.action=="navigate" and (self.locale=="deDE" and "Wegführung (KI-Vorschlag, ungeprüft): " or "Start guidance (unverified AI suggestion): ") or (self.locale=="deDE" and "Auf Karte: " or "Show on map: ")
        label=label..target.name
        if target.detail~="" then label=label.." · "..target.detail end
        self:AddChatMessage("target","|cffffd100|Hforeverai:"..id.."|h["..label.."]|h|r")
    end
end

function FG:OpenChatTarget(link)
    local id=type(link)=="string" and tonumber(link:match("^foreverai:(%d+)$"))
    local target=id and self.chatTargetLinks and self.chatTargetLinks[id]
    if not target then return false end
    if self:InCombat() then self:Say(T("Karte bitte außerhalb des Kampfes öffnen.")); return false end
    local route=self:CheckRoute(target.route)
    if not route or not route.points[1] then return false end
    if target.action=="navigate" then
        local ok,why=self:StartNavigation(route)
        if not ok then self:Say(why);return false end
        self:Say(self.locale=="deDE" and "KI-Koordinaten sind ungeprüft. Ziel und Zugang vor Ort prüfen." or "AI coordinates are unverified. Check the destination and entrance locally.")
        return true
    end
    if self.nav then
        self:Say(self.locale=="deDE" and "Bitte zuerst die aktive Wegführung stoppen, bevor ein neuer Kartenmarker gesetzt wird." or "Stop the active guidance before setting a new map marker.")
        return false
    end
    local point=route.points[1]
    if not self:WritePin(point) then self:Say(self.locale=="deDE" and "Auf dieser Karte kann kein Marker gesetzt werden." or "A marker cannot be placed on this map."); return false end
    self:OfferNavigation(route)
    self:OpenTargetMap()
    return true
end

function FG:StartActiveQuest(id,query,directSelection)
    if self:InCombat() then self:Say(T("ForeverAI pausiert im Kampf. Danach erneut versuchen."));return "unavailable" end
    local quest
    for _,entry in ipairs(self:GetQuests()) do if entry.id==id then quest=entry;break end end
    if not quest then self:Say(self.locale=="deDE" and "Diese Quest ist nicht mehr aktiv. Bitte die Liste erneut öffnen." or "This quest is no longer active. Reopen the list.");return "missing" end
    local route=self:QuestRoute(quest.id)
    if route then
        self:Say((self.locale=="deDE" and "Aktive Quest: " or "Active quest: ")..quest.title.." (#"..quest.id..")")
        local ok,err=self:StartNavigation(route);if not ok then self:Say(err);return "unavailable" end
        return "started"
    end
    local rows=self.QuestieObjectiveResults and self:QuestieObjectiveResults(quest.id,quest.title) or {}
    for _,row in ipairs(rows) do if row.route then row.route.watchQuestID=quest.id end end
    if #rows==1 then
        self:AddChatTargets(rows)
        self:Say((self.locale=="deDE" and "Aktive Quest: " or "Active quest: ")..quest.title.." (#"..quest.id..") · "..rows[1].detail)
        local ok,err=self:StartNavigation(rows[1].route);if not ok then self:Say(err);return "unavailable" end
        return "started"
    elseif #rows>1 then
        self:ShowSearchResults(rows,query or quest.title,{directStart=directSelection})
        self:Say(self.locale=="deDE" and "Für die aktive Quest gibt es mehrere mögliche QuestieDB-Ziele. Bitte ein Ziel auswählen." or "There are multiple possible QuestieDB objectives for the active quest. Select a destination.")
        return "select"
    end
    self:Say(self.locale=="deDE" and "Die aktive Quest ist gefunden, aber Client und QuestieDB liefern kein verwendbares Ziel. Es wurde keine Position erfunden." or "The active quest was found, but the client and QuestieDB have no usable destination. No position was invented.")
    return "missing"
end

function FG:TryAutomaticLocation(text)
    local q=" "..FG.Normalize(text or "").." "
    local intent=false
    for _,word in ipairs({"wo","wohin","where","finde","finden","find","karte","map","route","wegfuehrung","wegfindung","navigation","navigate","eingang","entrance","koordinaten","coordinates","coords"}) do
        if q:find(" "..word.." ",1,true) then intent=true;break end
    end
    if not intent and not q:find("wie komme",1,true) and not q:find("how do i get",1,true) then return false end
    if FG.AmbiguousTerm(text) then
        self:Say(self.locale=="deDE" and "DM ist mehrdeutig. Bitte Todesminen oder Düsterbruch ausschreiben." or "DM is ambiguous. Please specify Deadmines or Dire Maul.")
        return true
    end
    if self:InCombat() then self:Say(T("ForeverAI pausiert im Kampf. Danach erneut versuchen."));return true end
    -- Resolve the player's quest ID before looking up identically named quest
    -- chain entries in the community database.
    local quests={}
    for _,quest in ipairs(self:GetQuests()) do
        local title=FG.Normalize(quest.title or "")
        if #title>=4 and q:find(" "..title.." ",1,true) then quests[#quests+1]=quest end
    end
    if #quests>1 then
        self:Say(self.locale=="deDE" and "Mehrere aktive Quests haben diesen Namen. Bitte die Quest-ID angeben." or "Multiple active quests share that name. Please specify the quest ID.")
        return true
    end
    if #quests==1 then
        local outcome=self:StartActiveQuest(quests[1].id,text,false)
        if outcome=="missing" and self.LiveQuestion then self:LiveQuestion(text) end
        return true
    end
    local targets=self:ResolveChatTargets(text)
    if #targets==0 then
        if self:StartSaved(text,false,false) then return true end
        local previous=self.nav
        if self:FindQuest(text,true,false) then
            if self.nav==previous and self.LiveQuestion then self:LiveQuestion(text) end
            return true
        end
        local areas=self.ClientAreaResults and self:ClientAreaResults(text) or {}
        if #areas>0 then
            for i=1,math.min(#areas,4) do self:Say(areas[i].name.." · "..areas[i].detail) end
        end
        if self.LiveQuestion and self:LiveQuestion(text) then return true end
        if #areas>0 then return true end
        return false
    end
    self:AddChatTargets(targets)
    if #targets>1 then
        self:Say(self.locale=="deDE" and "Mehrere Ziele passen. Bitte den gewünschten Kartentreffer auswählen." or "Multiple destinations match. Please select the intended map result.")
        return true
    end
    local target=targets[1]
    self:Say((self.locale=="deDE" and "Lokales Ziel: " or "Local destination: ")..target.name.." · "..target.detail)
    local note=target.route.points[1].note
    if note and note~="" then self:Say(note) end
    local ok,err=self:StartNavigation(target.route)
    if not ok then self:Say(err) end
    return true
end

function FG:RedrawChat()
    if not self.chat then return end
    self.chat:Clear()
    for i=1,#self.messages do
        local line,user=self:ChatLine(i)
        if user then self.chat:AddMessage(line,0.45,0.8,1) else self.chat:AddMessage(line,0.88,0.91,0.95) end
    end
    self.chat:ScrollToBottom()
end

function FG:AddChatMessage(role,text)
    text=tostring(text or "")
    self.messageRoles=self.messageRoles or {}
    self.messages[#self.messages+1]=text
    self.messageRoles[#self.messages]=role or "local"
    if #self.messages>120 then table.remove(self.messages,1); table.remove(self.messageRoles,1) end
    if self.chat then
        local line,user=self:ChatLine(#self.messages)
        if user then self.chat:AddMessage(line,0.45,0.8,1) else self.chat:AddMessage(line,0.88,0.91,0.95) end
        self.chat:ScrollToBottom()
    end
end

function FG:SubmitChat(raw)
    local text=FG.Clean(raw,512)
    text=text:gsub("^/[fF][aA][iI]%s+",""):gsub("^/foreverai%s+","")
    if text=="" or text=="/fai" or text=="/foreverai" then return false end
    self.lastQuestion=text
    self.inputHistory=self.inputHistory or {}
    if self.inputHistory[#self.inputHistory]~=text then self.inputHistory[#self.inputHistory+1]=text end
    if #self.inputHistory>30 then table.remove(self.inputHistory,1) end
    self.historyIndex,self.historyDraft=nil,nil
    self:AddChatMessage("user",text)
    self.chatSubmitting=true
    local ok,err=pcall(function()
        if not self:IsLocalCommand(text) and self:TryAutomaticLocation(text) then return end
        self:Ask(text)
    end)
    self.chatSubmitting=false
    if not ok then
        self.lastError=tostring(err)
        self:Say(T("Interner Fehler: ")..FG.Clean(err,300)..T(" · Bericht mit /fai diagnose."))
    end
    return true
end

function FG:ChatHistory(direction)
    if not self.input or not self.inputHistory or #self.inputHistory==0 then return end
    if direction~="UP" and direction~="DOWN" then return end
    local count=#self.inputHistory
    if not self.historyIndex then self.historyDraft=self.input:GetText(); self.historyIndex=count+1 end
    self.historyIndex=math.max(1,math.min(count+1,self.historyIndex+(direction=="UP" and -1 or 1)))
    self.input:SetText(self.inputHistory[self.historyIndex] or self.historyDraft or "")
    self.input:SetCursorPosition(#self.input:GetText())
end

function FG:ClearChat()
    -- The companion stores conversation context by ephemeral session.
    self.liveSession=nil
    self.messages,self.messageRoles,self.inputHistory={},{},{}
    self.lastQuestion,self.historyIndex,self.historyDraft=nil,nil,nil
    self.chatTargetLinks,self.chatTargetOrder,self.chatTargetSerial={},{},0
    self:RedrawChat()
end
