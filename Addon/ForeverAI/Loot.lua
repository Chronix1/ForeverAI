-- ForeverAI 0.6: small, manually curated bilingual LOOT EXAMPLES for warrior.
-- Facts are NOT a live dungeon journal. These entries do not include item IDs,
-- drop rates, map coordinates, exact stat comparisons or guaranteed drops.
-- See KNOWLEDGE_SOURCES.md and LOOT_SOURCES.md before extending this table.
local _, FG = ...

local function rec(de,en,bossDe,bossEn,kind,typeDe,typeEn,level,roles,id)
    return {de=de,en=en,bossDe=bossDe,bossEn=bossEn,kind=kind,typeDe=typeDe,typeEn=typeEn,level=level,roles=roles,id=id}
end

FG.LootData = {
    shadowfang={
        de="Burg Schattenfang",en="Shadowfang Keep",source="https://www.wowhead.com/forever/dungeon-journal/shadowfang-keep",
        items={
            rec("Gekrümmte Kriegsaxt","Arced War Axe","Kommandant Springvale","Commander Springvale","2h","Zweihand-Axt","two-handed axe",21,{arms=true}),
            rec("Schlächterbeil","Butcher's Cleaver","Klingenklaue der Metzger","Razorclaw the Butcher","1h","Einhand-Axt","one-handed axe",20,{fury=true,protection=true}),
            rec("Wappen des Kommandanten","Commander's Crest","Kommandant Springvale","Commander Springvale","shield","Schild","shield",21,{protection=true}),
            rec("Spukklinge","Haunting Blade","Todeshöriger Captain (selten)","Deathsworn Captain (rare)","2h","Zweihand-Schwert","two-handed sword",22,{arms=true}),
            rec("Phantom-Rüstung","Phantom Armor","Todeshöriger Captain (selten)","Deathsworn Captain (rare)","armor","Ketten-Brustschutz","mail chest armor",22,{arms=true,fury=true,protection=true}),
            rec("Silverlaines Familiensiegel","Silverlaine's Family Seal","Baron Silverlaine","Baron Silverlaine","ring","Ring","ring",21,{arms=true,fury=true,protection=true}),
            rec("Szepter des Barons","Baron's Scepter","Baron Silverlaine","Baron Silverlaine","1h","Einhand-Streitkolben","one-handed mace",21,{fury=true,protection=true}),
            rec("Schlächterschnitzler","Butcher's Slicer","Klingenklaue der Metzger","Razorclaw the Butcher","1h","Einhand-Schwert","one-handed sword",18,{fury=true,protection=true}),
        },
    },
    deadmines={
        de="Todesminen",en="Deadmines",source="https://www.wowhead.com/forever/dungeon-journal/the-deadmines",
        items={
            rec("Smite's Mighty Hammer","Smite's Mighty Hammer","Mr. Smite","Mr. Smite","2h","Zweihand-Streitkolben","two-handed mace",18,{arms=true},7230),
            rec("Cruel Barb","Cruel Barb","Edwin van Cleef","Edwin VanCleef","1h","Einhand-Schwert","one-handed sword",19,{fury=true,protection=true},5191),
            rec("Smite's Reaver","Smite's Reaver","Mr. Smite","Mr. Smite","1h","Einhand-Axt","one-handed axe",17,{fury=true,protection=true}),
            rec("First Mate Band","First Mate Band","Mr. Smite","Mr. Smite","ring","Ring","ring",17,{arms=true,fury=true,protection=true}),
            rec("Rockslicer","Rockslicer","Rhahk'Zor","Rhahk'Zor","2h","Zweihand-Axt","two-handed axe",nil,{arms=true}),
        },
    },
    wailing={
        de="Höhlen des Wehklagens",en="Wailing Caverns",source="https://www.icy-veins.com/wow-forever/wailing-caverns-guide/",
        items={
            rec("Kresh's Back","Kresh's Back","Kresh","Kresh","shield","Schild","shield",nil,{protection=true}),
            rec("Cobrahn's Grasp","Cobrahn's Grasp","Lord Cobrahn","Lord Cobrahn","armor","Ketten-Gürtel","mail belt",nil,{arms=true,fury=true,protection=true}),
            rec("Mutant Scale Breastplate","Mutant Scale Breastplate","Mutanus der Verschlinger","Mutanus the Devourer","armor","Ketten-Brustschutz","mail chest armor",nil,{arms=true,fury=true,protection=true}),
            rec("Stinging Viper","Stinging Viper","Lord Pythas","Lord Pythas","1h","Einhand-Streitkolben","one-handed mace",nil,{fury=true,protection=true}),
        },
    },
}

local function padded(s) return " "..FG.Normalize(s or "").." " end
local function has(q,word) return q:find(" "..FG.Normalize(word).." ",1,true)~=nil end
local function any(q,...)
    for i=1,select("#",...) do if has(q,select(i,...)) then return true end end
    return false
end
local function say(self,de,en) self:Say(self.locale=="deDE" and de or en) end
local function roles(q)
    if any(q,"furor","fury","dual wield","dual wielding") then return "fury" end
    if any(q,"tank","tanken","schutz","protection","prot") then return "protection" end
    if any(q,"arms","waffenkrieger","waffen krieger","waffen skillung","waffen spezialisierung","zweihand build") then return "arms" end
    return nil
end
local function kind(q)
    if any(q,"schilde","schild","shield","shields") then return "shield" end
    if any(q,"zweihand","two handed","two handed weapons","two hand","2h") then return "2h" end
    if any(q,"einhand","one hand","one handed","1h") then return "1h" end
    if any(q,"ring","ringe","rings") then return "ring" end
    if any(q,"ruestung","rüstung","armor","armour","brust","breastplate","chest") then return "armor" end
    if any(q,"waffen","waffe","weapons","weapon") then return "weapon" end
    return nil
end
local function usable(item,filter)
    if not filter then return true end
    if filter=="weapon" then return item.kind=="1h" or item.kind=="2h" end
    return item.kind==filter
end
local function localizedItem(self,item,showDungeon)
    local name=self.locale=="deDE" and item.de or item.en
    local alt=self.locale=="deDE" and item.en or item.de
    local src=self.locale=="deDE" and item.bossDe or item.bossEn
    local typeName=self.locale=="deDE" and item.typeDe or item.typeEn
    local level=item.level and (self.locale=="deDE" and ", ab Stufe "..item.level or ", requires level "..item.level) or ""
    local label=name
    if FG.Normalize(name)~=FG.Normalize(alt) then label=label.." ("..alt..")" end
    local extra=showDungeon and (self.locale=="deDE" and " · "..showDungeon.de or " · "..showDungeon.en) or ""
    return label.." — "..typeName..level.."; "..src..extra
end

function FG:FindLootItem(raw,level)
    local q=padded(raw)
    local found={}
    for _,d in pairs(self.LootData) do
        for _,item in ipairs(d.items) do
            if has(q,item.de) or has(q,item.en) then found[#found+1]={item=item,dungeon=d} end
        end
    end
    if #found~=1 then return false end
    local item,d=found[1].item,found[1].dungeon
    say(self,"Fundort für diesen Gegenstand (kuratiert, nicht live geprüft):", "Source for this item (curated, not live-verified):")
    self:Say(localizedItem(self,item,d))
    if item.level and level and level<item.level then
        say(self,"Dein Level "..level.." liegt unter der Ausrüstungsanforderung "..item.level..".","Your level "..level.." is below the equip requirement "..item.level..".")
    end
    say(self,"Bossbeute ist nicht garantiert. Treffer können einen ungeprüften Anreisepunkt zum Dungeon enthalten; kein Weg zum Boss.","Boss drops are not guaranteed. Search results may offer an unverified outdoor approach, never a path to the boss.")
    return true
end

function FG:LootAnswer(key,raw,class,level)
    local d=self.LootData and self.LootData[key]
    if not d then return false end
    if class and class~="WARRIOR" then
        say(self,"Für "..d.de.." ist bisher nur eine kuratierte Krieger-Auswahl hinterlegt, keine vollständige Beuteliste für deine Klasse.","Only a curated warrior subset is available for "..d.en..", not a full loot table for your class.")
        say(self,"Für andere Klassen kannst du die Live-KI in den Einstellungen aktivieren.","For other classes, you can enable Live AI in Settings.")
        return true
    end
    local q=padded(raw)
    local spec,filter=roles(q),kind(q)
    local all=any(q,"alle","alles","all","vollstaendige","vollständige","komplett","complete")
    local listed={}
    for _,item in ipairs(d.items) do if usable(item,filter) then listed[#listed+1]=item end end
    if spec then
        table.sort(listed,function(a,b)
            local ap,bp=a.roles[spec] and 1 or 0,b.roles[spec] and 1 or 0
            return ap>bp -- Lua sort is unstable when tied, so sorted priority only.
        end)
    end
    say(self,"Krieger-Beute in "..d.de.." (kuratierte Auswahl, keine vollständige/live geprüfte Beuteliste):",
      "Warrior loot in "..d.en.." (curated selection, not a complete/live-verified loot table):")
    if #listed==0 then
        say(self,"In dieser Auswahl ist kein passender Eintrag für den gewählten Ausrüstungstyp.","No curated entry matches that equipment type.")
        return true
    end
    local count=math.min(#listed,all and 12 or 6)
    for i=1,count do
        local item=listed[i]
        self:Say(i..". "..localizedItem(self,item))
    end
    if #listed>count then
        say(self,"Weitere "..(#listed-count).." Einträge vorhanden. Frage nach 'allen Krieger-Gegenständen in "..d.de.."'.",
           (#listed-count).." more entries available. Ask for 'all warrior loot in "..d.en.."'.")
    end
    if spec=="arms" then say(self,"Für Waffen-Krieger zuerst Zweihandwaffen und ihren tatsächlichen DPS vergleichen.","For Arms, compare the available two-handed weapons and their actual DPS.") end
    if spec=="fury" then say(self,"Für Furor zuerst die Einhandwaffen und die aktuell nutzbare Waffenfertigkeit prüfen.","For Fury, compare one-handed weapons and usable weapon skills.") end
    if spec=="protection" then say(self,"Für Schutz Schild, passende Einhandwaffe und Überlebenswerte vergleichen.","For Protection, compare shield, one-handed weapon and defensive stats.") end
    local under=0
    for i=1,count do if level and listed[i].level and listed[i].level>level then under=under+1 end end
    if under>0 then
       say(self,"Hinweis: "..under.." angezeigte Gegenstände kannst du mit Level "..level.." noch nicht anlegen. Die Stufenanforderung steht direkt beim Gegenstand.",
           "Note: "..under.." listed items cannot yet be equipped at level "..level..". Check each item's requirement.")
    end
    say(self,"Dropchancen, Werte und Itemänderungen bitte im aktuellen Forever-Client prüfen. Ich setze für Loot keine erfundenen Wegpunkte.",
       "Check drop rates, stats and item changes in the current Forever client. Loot queries never create made-up waypoints.")
    return true
end
