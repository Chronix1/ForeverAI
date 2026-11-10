-- Curated name aliases only. No coordinates, NPC records, quest translations or item stats.
-- Internal tokens deliberately are NOT WoW IDs. They are used only for text matching.
local _, FG = ...
local T = FG.T
FG.Terms = {
    {id="stormwind",kind="location",de="Sturmwind",en="Stormwind",aliases={"Stormwind City"}},
    {id="ironforge",kind="location",de="Eisenschmiede",en="Ironforge"},
    {id="darnassus",kind="location",de="Darnassus",en="Darnassus"},
    {id="orgrimmar",kind="location",de="Orgrimmar",en="Orgrimmar"},
    {id="undercity",kind="location",de="Unterstadt",en="Undercity"},
    {id="thunderbluff",kind="location",de="Donnerfels",en="Thunder Bluff"},
    {id="deadmines",kind="location",de="Todesminen",en="Deadmines",aliases={"Die Todesminen","The Deadmines"}},
    {id="diremaul",kind="location",de="Düsterbruch",en="Dire Maul"},
    {id="elwynn",kind="location",de="Wald von Elwynn",en="Elwynn Forest",aliases={"Elwynn","Elwynnwald"}},
    {id="westfall",kind="location",de="Westfall",en="Westfall"},
    {id="duskwood",kind="location",de="Dämmerwald",en="Duskwood"},
    {id="redridge",kind="location",de="Rotkammgebirge",en="Redridge Mountains",aliases={"Redridge"}},
    {id="dunmorogh",kind="location",de="Dun Morogh",en="Dun Morogh"},
    {id="lochmodan",kind="location",de="Loch Modan",en="Loch Modan"},
    {id="darkshore",kind="location",de="Dunkelküste",en="Darkshore"},
    {id="barrens",kind="location",de="Brachland",en="The Barrens",aliases={"Barrens","Das Brachland"}},
    {id="warrior",kind="class",de="Krieger",en="Warrior",trainers={"Kriegerlehrer","Kriegertrainer"}},
    {id="paladin",kind="class",de="Paladin",en="Paladin",trainers={"Paladinlehrer","Paladintrainer"}},
    {id="hunter",kind="class",de="Jäger",en="Hunter",trainers={"Jägerlehrer","Jägertrainer"}},
    {id="rogue",kind="class",de="Schurke",en="Rogue",trainers={"Schurkenlehrer","Schurkentrainer"}},
    {id="priest",kind="class",de="Priester",en="Priest",trainers={"Priesterlehrer","Priestertrainer"}},
    {id="shaman",kind="class",de="Schamane",en="Shaman",trainers={"Schamanenlehrer","Schamanentrainer"}},
    {id="mage",kind="class",de="Magier",en="Mage",trainers={"Magierlehrer","Magiertrainer"}},
    {id="warlock",kind="class",de="Hexenmeister",en="Warlock",trainers={"Hexenmeisterlehrer","Hexenmeistertrainer"}},
    {id="druid",kind="class",de="Druide",en="Druid",trainers={"Druidenlehrer","Druidentrainer"}},
    {id="alchemy",kind="profession",de="Alchemie",en="Alchemy",trainers={"Alchemielehrer","Alchemietrainer"}},
    {id="blacksmithing",kind="profession",de="Schmiedekunst",en="Blacksmithing",trainers={"Schmiedelehrer","Schmiedekunstlehrer","Schmiedekunsttrainer"}},
    {id="enchanting",kind="profession",de="Verzauberkunst",en="Enchanting",trainers={"Verzauberkunstlehrer","Verzauberkunsttrainer","Verzauberungslehrer"}},
    {id="engineering",kind="profession",de="Ingenieurskunst",en="Engineering",trainers={"Ingenieurslehrer","Ingenieurskunstlehrer","Ingenieurskunsttrainer"}},
    {id="herbalism",kind="profession",de="Kräuterkunde",en="Herbalism",trainers={"Kräuterkundelehrer","Kräuterkundetrainer"}},
    {id="leatherworking",kind="profession",de="Lederverarbeitung",en="Leatherworking",trainers={"Lederverarbeitungslehrer","Lederverarbeitungstrainer"}},
    {id="mining",kind="profession",de="Bergbau",en="Mining",trainers={"Bergbaulehrer","Bergbautrainer"}},
    {id="skinning",kind="profession",de="Kürschnerei",en="Skinning",trainers={"Kürschnerlehrer","Kürschnereilehrer","Kürschnereitrainer"}},
    {id="tailoring",kind="profession",de="Schneiderei",en="Tailoring",trainers={"Schneiderlehrer","Schneidereilehrer","Schneidereitrainer"}},
    {id="cooking",kind="profession",de="Kochkunst",en="Cooking",aliases={"Kochen"},trainers={"Kochlehrer","Kochkunstlehrer","Kochkunsttrainer"}},
    {id="firstaid",kind="profession",de="Erste Hilfe",en="First Aid",trainers={"Erste-Hilfe-Lehrer","Erste-Hilfe-Trainer"}},
    {id="fishing",kind="profession",de="Angeln",en="Fishing",trainers={"Angellehrer","Angeltrainer"}},
    {id="trainer",kind="service",de="Lehrer",en="Trainer",aliases={"Ausbilder"}},
    {id="classtrainer",kind="service",de="Klassenlehrer",en="Class Trainer",aliases={"Klassentrainer"}},
    {id="professiontrainer",kind="service",de="Berufslehrer",en="Profession Trainer",aliases={"Berufstrainer"}},
    {id="flightmaster",kind="service",de="Flugmeister",en="Flight Master"},
    {id="innkeeper",kind="service",de="Gastwirt",en="Innkeeper",aliases={"Wirt"}},
    {id="auctionhouse",kind="service",de="Auktionshaus",en="Auction House"},
    {id="bank",kind="service",de="Bank",en="Bank"},
    {id="weapon",kind="gear",de="Waffe",en="Weapon",aliases={"Waffen","Weapons"}},
    {id="twohanded",kind="gear",de="Zweihand",en="Two-handed",aliases={"Zweihandwaffe","Two handed weapon","2H"}},
    {id="onehanded",kind="gear",de="Einhand",en="One-handed",aliases={"Einhandwaffe","One handed weapon","1H"}},
    {id="shield",kind="gear",de="Schild",en="Shield"},
    {id="sword",kind="gear",de="Schwert",en="Sword"},
    {id="axe",kind="gear",de="Axt",en="Axe"},
    {id="mace",kind="gear",de="Streitkolben",en="Mace"},
    {id="dagger",kind="gear",de="Dolch",en="Dagger"},
    {id="staff",kind="gear",de="Stab",en="Staff"},
    {id="item",kind="gear",de="Gegenstand",en="Item",aliases={"Gegenstände","Items"}},
    {id="equipment",kind="gear",de="Ausrüstung",en="Equipment",aliases={"Gear"}},
    {id="level",kind="game",de="Stufe",en="Level"},
    {id="alliance",kind="faction",de="Allianz",en="Alliance"},
    {id="horde",kind="faction",de="Horde",en="Horde"},
}

FG.TermByToken = {}
local aliases, seen = {}, {}
local function add(alias, canonical)
    alias = FG.Normalize(alias)
    if alias == "" then return end
    if seen[alias] then assert(seen[alias] == canonical, "Conflicting term alias: " .. alias); return end
    seen[alias] = canonical
    aliases[#aliases+1] = {alias=alias, canonical=canonical}
end
for _,term in ipairs(FG.Terms) do
    local token = "fgterm" .. term.id
    term.token = token
    FG.TermByToken[token] = term
    add(term.de,token); add(term.en,token)
    for _,alias in ipairs(term.aliases or {}) do add(alias,token) end
    for _,alias in ipairs(term.trainers or {}) do add(alias,token .. " fgtermtrainer") end
end
-- Most specific aliases first: "Class Trainer" must precede "Trainer".
table.sort(aliases,function(a,b) if #a.alias == #b.alias then return a.alias < b.alias end; return #a.alias > #b.alias end)
FG.TermAliases = aliases

function FG.Canonical(text)
    local s = " " .. FG.Normalize(text) .. " "
    for _,entry in ipairs(aliases) do
        local needle = " " .. entry.alias .. " "
        local offset = 1
        while true do
            local a,b = s:find(needle,offset,true)
            if not a then break end
            local replacement = " " .. entry.canonical .. " "
            s = s:sub(1,a-1) .. replacement .. s:sub(b+1)
            offset = a + #replacement - 1
        end
    end
    return FG.Trim(s)
end

function FG.TermsIn(text)
    local result, used = {}, {}
    for token in FG.Canonical(text):gmatch("%S+") do
        local term = FG.TermByToken[token]
        if term and not used[token] then result[#result+1]=term; used[token]=true end
    end
    return result
end

function FG.AmbiguousTerm(text)
    return (" " .. FG.Normalize(text) .. " "):find(" dm ",1,true) ~= nil
end

local ignored = {}
for word in ([[wo wohin wie ich mich mir mein meine meinen muss komme kommen fuer der die das den dem des ein eine einer eines
von nach zu zum zur hin bitte quest quests route finde finden bring zeig zeige ist sind im in am an auf mit zum zur aus
kann koennte kannst gehen gehe laufen weg fuehre navigiere woher es gibt befindet sich und
where how i me my do does can could would should get find show take bring go walk navigate the a an from to of in on at
please is are am be for into through way route quest quests location located and]]):gmatch("%S+") do ignored[word]=true end

function FG.Matches(query,label)
    query,label = FG.Canonical(query),FG.Canonical(label)
    if query == "" or label == "" then return false end
    if query == label then return true end
    local padded = " " .. label .. " "
    local found, lastLocation, usedLocation = false, 0, {}
    for token in query:gmatch("%S+") do
        -- Do not discard two-letter/numeric constraints, including levels and 1H/2H.
        if not ignored[token] then
            found=true
            local position = padded:find(" " .. token .. " ",1,true)
            if not position then return false end
            local term = FG.TermByToken[token]
            if term and term.kind == "location" and not usedLocation[token] then
                -- A route named A -> B must not be selected for a B -> A query.
                if position < lastLocation then return false end
                lastLocation=position; usedLocation[token]=true
            end
        end
    end
    return found
end

FG.CommandAliases = {
    help="hilfe", stop="stopp", diagnostic="diagnose", diagnostics="diagnose",
    remember="merken", list="liste", remove="entfernen", delete="entfernen",
    target="ziel", waypoint="ziel", next="weiter", back="zurueck", previous="zurueck", map="karte",
    record="aufnahme", point="punkt", save="speichern", cancel="abbrechen", keep="sichern",
    go="gehe", navigate="gehe", routeexport="routenexport", language="sprache", lang="sprache",
    term="begriff", dictionary="begriff", woerterbuch="begriff",
}
FG.PositionQueries = {wo=true, ["wo bin ich"]=true, position=true, where=true, ["where am i"]=true, ["my position"]=true}

function FG:ShowTerms(query)
    local result = FG.TermsIn(query)
    if FG.AmbiguousTerm(query) then self:Say(T("DM ist mehrdeutig. Bitte Todesminen / Deadmines oder Düsterbruch / Dire Maul ausschreiben.")); return end
    if #result == 0 then self:Say(T("Kein passender Wörterbucheintrag. Eigennamen werden nicht frei übersetzt.")); return end
    for _,term in ipairs(result) do self:Say(T("Wörterbuch: %s ↔ %s",term.de,term.en)) end
    self:Say(T("Ein Wörterbucheintrag ist keine Standort- oder Questdatenbank."))
end

function FG:AddQuestAlias(text)
    local kind,id,name = FG.Trim(text):match("^(%S+)%s+(%d+)%s+(.+)$")
    if not kind or FG.Normalize(kind) ~= "quest" then self:Say(T("Format: /fai alias quest ID Zusätzlicher Questtitel")); return false end
    id,name = tonumber(id),FG.Clean(name,180)
    if not FG.IsNumber(id) or id<1 or id>1000000 or id%1~=0 or FG.Normalize(name)=="" then
        self:Say(T("Quest-ID muss eine positive ganze Zahl sein; der Name darf nicht leer sein.")); return false
    end
    self.db.questAliases = self.db.questAliases or {}
    local list = self.db.questAliases[id] or {}
    for _,alias in ipairs(list) do
        if FG.Normalize(alias)==FG.Normalize(name) then self:Say(T("Dieser zusätzliche Questname ist bereits gespeichert.")); return false end
    end
    if #list >= 10 then self:Say(T("Für diese Quest sind maximal 10 eigene Namen erlaubt.")); return false end
    list[#list+1]=name; self.db.questAliases[id]=list
    self:Say(T("Zusätzlicher Questname gespeichert: %d — %s. Dieser Name ist eine eigene Zuordnung, keine geprüfte Übersetzung.",id,name))
    return true
end

function FG:QuestMatches(query,quest)
    if FG.Matches(query,quest.title) then return true end
    local title=FG.Normalize(quest.title or "")
    if #title>=4 and (" "..FG.Normalize(query or "").." "):find(" "..title.." ",1,true) then return true end
    for _,alias in ipairs(self.db.questAliases and self.db.questAliases[quest.id] or {}) do
        if FG.Matches(query,alias) then return true end
    end
    return false
end
