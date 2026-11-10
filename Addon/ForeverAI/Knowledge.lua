-- ForeverAI 0.5: small OFFLINE information library. Text is a guide, not an authenticated game database.
-- Recommended dungeon brackets from the WoW: Forever overview published 2026-11-06;
-- weapon examples from WoW: Forever class guides (sources and limitations in KNOWLEDGE_SOURCES.md).
local _,FG=...

local function say(FG,de,en)
    FG:Say(FG.locale=="deDE" and de or en)
end
local function norm(v)
    return " "..FG.Normalize(v or "").." "
end
local function contains(q,term)
    return q:find(" "..FG.Normalize(term).." ",1,true)~=nil
end
local function any(q,...)
    for i=1,select("#",...) do if contains(q,select(i,...)) then return true end end
    return false
end
local D={
 -- Name (DE / EN), aliases, recommended level band, zone (DE / EN), location hint (DE / EN)
 {"Flammenschlund","Ragefire Chasm",{"rfc"},13,18,"Orgrimmar","Orgrimmar","Der Zugang liegt innerhalb von Orgrimmar.","Entrance is inside Orgrimmar."},
 {"Halle der Thane","Hall of Thanes",{"hallen der thane","the hall of thanes"},13,18,"Dun Morogh","Dun Morogh","Unterhalb von Eisenschmiede; noch keine importierte GPS-Route.","Beneath Ironforge; no verified waypoint route imported."},
 {"Ruinen von Lordaeron","Ruins of Lordaeron",{"lordaeron ruins"},15,20,"Tirisfal","Tirisfal Glades","Oberhalb von Unterstadt in den Ruinen von Lordaeron.","At the ruins above the Undercity."},
 {"Höhlen des Wehklagens","Wailing Caverns",{"hoehlen des wehklagens","höhle des wehklagens","wc","wehklagen","wailing cavern"},15,25,"Brachland","The Barrens","Eingang beim Oasengebiet im nördlichen Brachland.","Entrance near the northern Barrens oasis.","wailing"},
 {"Todesminen","Deadmines",{"the deadmines","vc","die todesminen"},18,23,"Westfall","Westfall","Von Sturmwind durch Elwynn nach Westfall; bei Mondbruch (Moonbrook) in den Minenkomplex gehen. Kein automatischer Fußweg vorhanden.","From Stormwind through Elwynn to Westfall; enter the mine complex at Moonbrook. No calculated walking route.","deadmines"},
 {"Burg Schattenfang","Shadowfang Keep",{"sfk","schattenfang","burg shadowfang","shadowfang"},22,30,"Silberwald","Silverpine Forest","Burg nahe dem Dorf Lohenscheit (Pyrewood Village).","Castle near Pyrewood Village.","shadowfang"},
 {"Das Verlies","The Stockade",{"das verlies","stockades","stormwind stockade","stormwind stockades"},22,30,"Sturmwind","Stormwind City","Eingang im Gefängnisbezirk von Sturmwind.","Entrance inside Stormwind's prison area."},
 {"Tiefschwarze Grotte","Blackfathom Deeps",{"bfd"},24,32,"Eschental","Ashenvale","Eingang an der Zoramküste im Nordwesten des Eschentals.","Entrance at Zoram Strand in northwestern Ashenvale."},
 {"Ausgrabungsstätte: Sumpfland","Excavation Site: Wetlands",{"excavation site","wetlands excavation site"},24,29,"Sumpfland","Wetlands","Oberhalb der Ausgrabungsstätte von Whelgar; ohne geprüfte Wegpunkte.","Above Whelgar's Excavation Site; no verified waypoints."},
 {"Stadt Dalaran","City of Dalaran",{"dalaran dungeon"},28,33,"Alteracgebirge","Alterac Mountains","Bei den Ruinen von Dalaran im Alteracgebirge.","By the ruins of Dalaran in the Alterac Mountains."},
 {"Scharlachrotes Kloster: Friedhof","Scarlet Monastery: Graveyard",{"sm graveyard","sm friedhof"},28,38,"Tirisfal","Tirisfal Glades","Nördliches Tirisfal, Scharlachrotes Kloster.","Northern Tirisfal Glades, Scarlet Monastery."},
 {"Scharlachrotes Kloster: Bibliothek","Scarlet Monastery: Library",{"sm library","sm bibliothek","sm bücherei"},29,39,"Tirisfal","Tirisfal Glades","Nördliches Tirisfal, Scharlachrotes Kloster.","Northern Tirisfal Glades, Scarlet Monastery."},
 {"Gnomeregan","Gnomeregan",{},29,38,"Dun Morogh","Dun Morogh","Bei der Gnomenstadt westlich von Eisenschmiede.","At the gnomish city west of Ironforge."},
 {"Kral der Klingenhauer","Razorfen Kraul",{"rfk"},30,40,"Brachland","The Barrens","Im südlichen Brachland am Dornenlabyrinth.","Southern Barrens, at the thorn maze."},
 {"Scharlachrotes Kloster: Waffenkammer","Scarlet Monastery: Armory",{"sm armory","sm waffenkammer"},32,42,"Tirisfal","Tirisfal Glades","Nördliches Tirisfal, Scharlachrotes Kloster.","Northern Tirisfal Glades, Scarlet Monastery."},
 {"Scharlachrotes Kloster: Kathedrale","Scarlet Monastery: Cathedral",{"sm cathedral","sm kathedrale"},35,45,"Tirisfal","Tirisfal Glades","Nördliches Tirisfal, Scharlachrotes Kloster.","Northern Tirisfal Glades, Scarlet Monastery."},
 {"Die versunkene Stadt","The Drowned City",{"drowned city"},35,40,"Schlingendorntal","Stranglethorn Vale","Vor der Küste des Schlingendorntals; Zugang vor Ort prüfen.","Off the coast of Stranglethorn Vale; check approach in game."},
 {"Krol'dok-Festung","Krol'dok Stronghold",{"krol dok stronghold","kroldok"},40,45,"Flussauen","Riverglades","In den neuen Flussauen (Riverglades).","In the new Riverglades zone."},
 {"Hügel der Klingenhauer","Razorfen Downs",{"rfd"},40,50,"Brachland","The Barrens","Südliches Brachland, nahe Kral der Klingenhauer.","Southern Barrens, near Razorfen Kraul."},
 {"Uldaman","Uldaman",{},42,52,"Ödland","Badlands","In den nördlichen Badlands (Ödland).","In northern Badlands."},
 {"Zul'Farrak","Zul'Farrak",{"zf"},44,54,"Tanaris","Tanaris","Nordwestlich in Tanaris.","In northwestern Tanaris."},
 {"Maraudon","Maraudon",{},45,55,"Desolace","Desolace","Im Tal der Speere in Desolace; mehrere Eingänge/Flügel.","In Valley of Spears, Desolace; multiple entrances/wings."},
 {"Alcaz-Gefängnis","Alcaz Prison",{"alcaz island prison"},48,53,"Düstermarschen","Dustwallow Marsh","Alcaz-Insel in den Düstermarschen; Zugang vor Ort prüfen.","Alcaz Island in Dustwallow Marsh; check approach in game."},
 {"Versunkener Tempel","Sunken Temple",{"temple of atal hakkar","the sunken temple","st"},50,60,"Sümpfe des Elends","Swamp of Sorrows","Im See im Sumpf des Elends.","In the lake in Swamp of Sorrows."},
 {"Schwarzfelstiefen","Blackrock Depths",{"brd"},52,60,"Schwarzfels","Blackrock Mountain","Zugang über den Schwarzfels zwischen Brennender Steppe und Sengender Schlucht.","Through Blackrock Mountain between Burning Steppes and Searing Gorge."},
 {"Schwarzmaulfeste","Blackmaw Hold",{"blackmaw hold"},55,60,"Azshara","Azshara","In Azshara, neue Forever-Instanz; Zugang vor Ort prüfen.","In Azshara, a new Forever dungeon; check approach in game."},
 {"Untere Schwarzfelsspitze","Lower Blackrock Spire",{"lbrs"},55,60,"Schwarzfels","Blackrock Mountain","Im Schwarzfels, unterer Flügel.","Inside Blackrock Mountain, lower section."},
 {"Obere Schwarzfelsspitze","Upper Blackrock Spire",{"ubrs"},58,60,"Schwarzfels","Blackrock Mountain","Im Schwarzfels, oberer Flügel.","Inside Blackrock Mountain, upper section."},
 {"Formergipfel","Shaper's Terrace",{"shapers terrace","shaper s terrace"},58,60,"Krater von Un'Goro","Un'Goro Crater","Im Krater von Un'Goro; Zugang vor Ort prüfen.","In Un'Goro Crater; check entrance in game."},
 {"Düsterbruch","Dire Maul",{"duesterbruch","diremaul"},58,60,"Feralas","Feralas","In Feralas, mehrere Flügel.","In Feralas; multiple wings."},
 {"Scholomance","Scholomance",{},58,60,"Westliche Pestländer","Western Plaguelands","Bei Caer Darrow im See.","At Caer Darrow, on the lake."},
 {"Stratholme","Stratholme",{},58,60,"Östliche Pestländer","Eastern Plaguelands","Im Norden der östlichen Pestländer; mehrere Zugänge.","Northern Eastern Plaguelands; multiple entrances."},
}
FG.KnowledgeDungeons=D

-- Bounded spelling correction for recognizable names and common intent words.
-- Proper names are never replaced in saved routes or sent to the game client.
local function distanceAtMost(a,b,limit)
    if math.abs(#a-#b)>limit then return false end
    local prev={}; for j=0,#b do prev[j]=j end
    for i=1,#a do
        local row={[0]=i};local best=i
        for j=1,#b do
            local cost=(a:sub(i,i)==b:sub(j,j)) and 0 or 1
            local value=math.min(prev[j]+1,row[j-1]+1,prev[j-1]+cost)
            row[j]=value
            if value<best then best=value end
        end
        if best>limit then return false end
        prev=row
    end
    return prev[#b]<=limit
end

local function hasApproxWord(q, word)
    for token in q:gmatch("%S+") do
        if token==word then return true end
        if #token>=5 and distanceAtMost(token,word,1) then return true end
    end
    return false
end

local function dungeonMatch(q)
    local result={}
    for _,d in ipairs(D) do
        if contains(q,d[1]) or contains(q,d[2]) then result[#result+1]=d
        else for _,alias in ipairs(d[3]) do if contains(q,alias) then result[#result+1]=d;break end end end
    end
    if #result>0 then return result end
    -- Only single-word aliases of at least eight letters qualify. Use a single
    -- clear best candidate; ambiguous near-matches must never select a dungeon.
    local lowest, selected, tie = 3,nil,false
    for token in q:gmatch("%S+") do
        if #token>=8 and #token<=28 then
            for _,d in ipairs(D) do
                local keys={FG.Normalize(d[1]),FG.Normalize(d[2])}
                for _,alias in ipairs(d[3]) do keys[#keys+1]=FG.Normalize(alias) end
                for _,key in ipairs(keys) do
                    if #key>=8 and not key:find(" ",1,true) then
                        local limit=(#key>=11 and 2 or 1)
                        if distanceAtMost(token,key,limit) then
                            -- Compute exact distance to rank competing near-matches.
                            local rank
                            if token==key then rank=0
                            elseif distanceAtMost(token,key,1) then rank=1
                            else rank=2 end
                            if rank<lowest then lowest,selected,tie=rank,d,false
                            elseif rank==lowest and selected~=d then tie=true end
                        end
                    end
                end
            end
        end
    end
    if selected and not tie then return {selected} end
    return {}
end

local function levelFrom(q)
    local x=q:match(" level (%d%d?) ") or q:match(" lvl (%d%d?) ") or q:match(" stufe (%d%d?) ")
    x=x or q:match(" level (%d%d?) (%w+) ") -- defensive; number must still be a distinct token
    if not x then x=q:match(" (%d%d?) level ") or q:match(" (%d%d?) lvl ") end
    x=tonumber(x)
    if x and x>=1 and x<=60 then return x end
    return nil
end

local function charLevel()
    local level=FG.Safe(UnitLevel,"player")
    return FG.IsNumber(level) and level>=1 and level<=60 and math.floor(level) or nil
end

local function currentClass()
    local _,id=FG.Safe(UnitClass,"player")
    return type(id)=="string" and not FG.IsSecret(id) and id or nil
end

local function explicitClass(q)
    local classes={
      {"WARRIOR",{"krieger","warrior"}},{"PALADIN",{"paladin"}},
      {"ROGUE",{"schurke","rogue"}},{"HUNTER",{"jaeger","jäger","hunter"}},
      {"PRIEST",{"priester","priest"}},{"SHAMAN",{"schamane","shaman"}},
      {"MAGE",{"magier","mage"}},{"WARLOCK",{"hexenmeister","warlock"}},
      {"DRUID",{"druide","druid"}}
    }
    for _,entry in ipairs(classes) do for _,alias in ipairs(entry[2]) do if contains(q,alias) then return entry[1] end end end
    return nil
end
local tips={
 WARRIOR={"Krieger: Waffen (Arms) orientiert sich an starken Zweihandwaffen; Furor (Fury) an aktuellen Einhandwaffen, Schutz (Protection) an Schild und Überleben. In Forever sind Talente verändert – prüfe deine Spezialisierung.","Warrior: Arms favors strong two-handed weapons; Fury keeps one-handed weapons updated; Protection focuses on shield and survivability. Forever changes talents: check your specialization."},
 PALADIN={"Paladin: Heilig heilt, Schutz tankt und Vergeltung verursacht Nahkampfschaden. Für konkrete Item-Tipps bitte Rolle und Level angeben.","Paladin: Holy heals, Protection tanks and Retribution deals melee damage. Give your role and level for item advice."},
 ROGUE={"Schurke: Waffen-DPS, Beweglichkeit und passende Waffenfertigkeiten sind beim Leveln wichtig. Wähle die Waffen passend zu deiner Spezialisierung.","Rogue: weapon DPS, Agility and usable weapon skills matter while leveling. Pick weapons that fit your specialization."},
 HUNTER={"Jäger: Eine passende Fernkampfwaffe aktuell halten; Beweglichkeit und ein gut versorgtes Begleitertier helfen beim Leveln.","Hunter: keep your ranged weapon current; Agility and a well-maintained pet help while leveling."},
 PRIEST={"Priester: Heilig/Disziplin für Heilung, Schatten für Schadensspiel. Achte auf Zauberattribute und Mana; Details hängen von Forever-Talenten ab.","Priest: Holy/Discipline for healing, Shadow for damage. Spell stats and mana matter; details depend on Forever talents."},
 SHAMAN={"Schamane: Elementar (Zauber), Verstärkung (Nahkampf) und Wiederherstellung (Heilung) brauchen unterschiedliche Ausrüstung.","Shaman: Elemental (spells), Enhancement (melee) and Restoration (healing) need different gear."},
 MAGE={"Magier: Zauberschaden, Intelligenz und Mana helfen beim Leveln. Waffe als Stat-Träger betrachten, nicht als Hauptschadensquelle.","Mage: spell damage, Intellect and mana help leveling. Weapons mainly provide stats rather than primary damage."},
 WARLOCK={"Hexenmeister: Zauberschaden und nützliche Begleitertiere sind wichtig; wähle Talente und Ausrüstung nach Spielweise.","Warlock: spell damage and useful demons matter; choose talents and gear for your playstyle."},
 DRUID={"Druide: Wilder Kampf, Gleichgewicht und Wiederherstellung haben sehr unterschiedliche Werteprioritäten. Form und Rolle zuerst nennen.","Druid: Feral, Balance and Restoration use very different stat priorities. Start with form and role."}
}
local function listDungeons(self,level)
    if not level then
        say(self,"Nenne bitte ein Level, z. B. 'Welche Instanzen für Level 22?'.", "Include a level, e.g. 'Which dungeons for level 22?'.")
        return
    end
    local candidates={}
    for _,d in ipairs(D) do
        if level>=d[4] and level<=d[5] then candidates[#candidates+1]=d end
    end
    table.sort(candidates,function(a,b)
       local am=(a[4]+a[5])/2;local bm=(b[4]+b[5])/2
       if math.abs(am-level)~=math.abs(bm-level) then return math.abs(am-level)<math.abs(bm-level) end
       return a[4]<b[4]
    end)
    if #candidates==0 then
       say(self,"Keine Instanzen für dieses Level in der kleinen lokalen Liste. Die Liste ist kein vollständiger Dungeonbrowser.","No dungeons for that level in this small offline list. It is not a complete dungeon browser.")
       return
    end
    say(self,"Instanzen für Level "..level.." (ungefähre empfohlene Forever-Levelbereiche; nicht die Eintrittsvoraussetzungen):", "Dungeons for level "..level.." (approximate recommended Forever brackets, not entry requirements):")
    for i=1,math.min(#candidates,8) do
      local d=candidates[i]
      local name=self.locale=="deDE" and d[1] or d[2]
      local zone=self.locale=="deDE" and d[6] or d[7]
      self:Say(name.." ["..d[4].."–"..d[5].."] · "..zone)
    end
    if #candidates>8 then say(self,"Weitere Instanzen in diesem Levelbereich sind möglich.","More dungeons in this level bracket may exist.") end
    say(self,"Frage nach einem Dungeon-Namen für die Eingangsregion. Ohne geprüfte Wegpunkte setze ich keinen Marker.","Ask for a dungeon by name to see its entrance area. I won't place a marker without verified waypoints.")
end

function FG:KnowledgeAnswer(raw)
    local q=norm(raw)
    if FG.AmbiguousTerm(raw) then
        say(self,"'DM' ist mehrdeutig (Todesminen oder Düsterbruch). Bitte ausschreiben.","'DM' is ambiguous (Deadmines or Dire Maul). Write the full name.")
        return true
    end
    if any(q,"hallo","hi","hey","hello","servus") and #FG.Trim(q)<18 then
       say(self,"Hallo! Frag z. B.: 'Welche Instanzen mit Level 22?', 'Wo sind die Todesminen?' oder 'Kriegerwaffen Level 25?'.", "Hello! Try 'Which dungeons at level 22?', 'Where are the Deadmines?' or 'Warrior weapons at level 25?'.")
       return true
    end
    local named=dungeonMatch(q)
    local level=levelFrom(q) or charLevel()
    local class=explicitClass(q) or currentClass()
    local wantsGear=any(q,"waffe","waffen","kriegerwaffe","kriegerwaffen","warrior weapon","warrior weapons","weapon","weapons","item","items","gegenstand","gegenstaende","gegenstaenden","beute","loot","drop","drops","ausruestung","ausrüstung","gear","zweihand","two handed","einhand","one handed","schwert","sword","axt","axe","schild","schilde","shield","shields","ring","rings","ruestung","rüstung","best in slot","bis")
        or hasApproxWord(q,"gegenstaende") or hasApproxWord(q,"waffen") or hasApproxWord(q,"loot")
    -- Specific item names take priority over generic dungeon and class advice.
    if self:FindLootItem(raw,level) then return true end
    if #named==1 then
       local d=named[1];local de,eng=d[1],d[2]
       if wantsGear then
           if self:LootAnswer(d[10],raw,class,level) then return true end
           say(self,"Für "..de.." habe ich noch keine geprüfte lokale Gegenstandsliste. Aktiviere die Live-KI für eine weitere Einschätzung und überprüfe die Antwort im Spiel.","No verified offline item list for "..eng.." yet. Enable Live AI for further guidance and verify the answer in game.")
           return true
       end
       say(self,de.." / "..eng.." · empfohlen ca. Level "..d[4].."–"..d[5].." · "..d[6]..".",eng.." / "..de.." · recommended about level "..d[4].."–"..d[5].." · "..d[7]..".")
       say(self,d[8],d[9])
       say(self,"Im Suchfenster kannst du für bekannte Instanzen einen ungefähren Außen-Anreisepunkt wählen. Noch kein geprüfter Fußweg zum Portal.","Select a community-reported outdoor approach point in the search results for known dungeons. No verified walking route to the portal.")
       return true
    end
    if #named>1 and wantsGear then
       say(self,"Mehrere Dungeons passen zu deiner Frage. Bitte nur einen Dungeon nennen.","Your question matches multiple dungeons. Please specify one dungeon.")
       return true
    end
    if any(q,"instanz","instanzen","dungeon","dungeons","dungen","dungon","instance","instances","verlies","verliess","dungi")
      or hasApproxWord(q,"dungeon") or hasApproxWord(q,"instanz") then
       listDungeons(self,level)
       return true
    end
    if wantsGear then
        if class=="WARRIOR" then
            say(self,"Krieger-Waffen für Level "..tostring(level or "?")..": wichtig sind Waffen-DPS, deine Spezialisierung (Waffen/Furor/Schutz) und ob du die Waffenart erlernt hast.","Warrior weapons for level "..tostring(level or "?")..": prioritize weapon DPS, your spec (Arms/Fury/Protection), and weapon proficiency.")
            if level and level>=18 and level<=29 then
                say(self,"Beispiele aus Forever-Guides: 'Smite's Mighty Hammer' (Zweihand, Todesminen) für Waffen; 'Cruel Barb' (Einhand, Edwin van Cleef in den Todesminen) für Furor. Bei Level 25 außerdem 'Hamhock's Cleaver' aus dem Verlies als Option für Allianz.","Forever guide examples: Smite's Mighty Hammer (two-hand, Deadmines) for Arms; Cruel Barb (one-hand, Edwin VanCleef in Deadmines) for Fury. At level 25, Hamhock's Cleaver from the Stockade is another Alliance option.")
            end
            say(self,"Das sind Beispiele, kein berechnetes Best-in-Slot. Frag nach 'Krieger-Gegenständen in Burg Schattenfang' oder nutze die KI-Begleit-App.","These are examples, not calculated best-in-slot. Ask about 'Warrior loot in Shadowfang Keep' or use the companion AI app.")
        else
            local t=tips[class]
            if t then say(self,t[1],t[2]) end
            say(self,"Für echte Itemvergleiche brauche ich Spezialisierung, Level, Rolle und Itemdaten. Nutze den KI-Export für eine vollständige Antwort.","For real item comparisons I need spec, level, role and item data. Use AI export for a detailed answer.")
        end
        return true
    end
    if any(q,"lehrer","trainer","ausbilder","klassenlehrer","class trainer","berufslehrer","profession trainer") then
        local t=tips[class]
        if t and any(q,"klasse","class","krieger","warrior","paladin","magier","mage","lehrer","trainer") then say(self,t[1],t[2]) end
        say(self,"Lehrer findest du gewöhnlich in Hauptstädten. Frage eine Stadtwache nach Klassen- oder Berufslehrer und nutze die Kartenmarkierung des Spiels. Ich habe keine geprüfte NPC-Koordinate für deinen aktuellen Ort.","Trainers are commonly in capital cities. Ask a city guard for a class/profession trainer and use the game's map marker. I have no verified NPC coordinates for your location.")
        return true
    end
    if any(q,"klasse","klassen","class","classes","talent","talente","skillung","spec","spezialisierung","build","rotation","krieger","warrior","paladin","magier","mage","jäger","hunter","schurke","rogue","druide","druid","priester","priest","shaman","schamane","warlock","hexenmeister") then
        local t=tips[class]
        if t then say(self,t[1],t[2]) else say(self,"Nenne eine Klasse und Spezialisierung für gezielte Tipps.","Name a class and specialization for targeted tips.") end
        say(self,"Forever hat überarbeitete Talente und Fähigkeiten; allgemeine Classic-Ratgeber können abweichen.","Forever changes talents and abilities; classic-era guides may differ.")
        return true
    end
    return false
end
