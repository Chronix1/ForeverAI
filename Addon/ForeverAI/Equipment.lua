-- Read-only, explicitly user-requested player equipment inspection.
-- All data comes from allowed in-game APIs. No character name, realm, token,
-- bank contents or full bags are collected. Cached item data can be missing.
local _, FG = ...

local SLOTS = {
    {1,"Kopf","Head"},{2,"Hals","Neck"},{3,"Schultern","Shoulders"},
    {5,"Brust","Chest"},{6,"Taille","Waist"},{7,"Beine","Legs"},
    {8,"Füße","Feet"},{9,"Handgelenke","Wrists"},{10,"Hände","Hands"},
    {11,"Ring 1","Ring 1"},{12,"Ring 2","Ring 2"},
    {13,"Schmuck 1","Trinket 1"},{14,"Schmuck 2","Trinket 2"},
    {15,"Rücken","Back"},{16,"Waffenhand","Main hand"},
    {17,"Schildhand","Off hand"},{18,"Fernkampf","Ranged"},
}
local statKeys = {
    {"ITEM_MOD_STRENGTH_SHORT","Stärke","Strength"},
    {"ITEM_MOD_AGILITY_SHORT","Beweglichkeit","Agility"},
    {"ITEM_MOD_STAMINA_SHORT","Ausdauer","Stamina"},
    {"ITEM_MOD_INTELLECT_SHORT","Intelligenz","Intellect"},
    {"ITEM_MOD_SPIRIT_SHORT","Willenskraft","Spirit"},
    {"ITEM_MOD_ATTACK_POWER_SHORT","Angriffskraft","Attack Power"},
    {"ITEM_MOD_HIT_RATING_SHORT","Trefferwertung","Hit"},
    {"ITEM_MOD_CRIT_RATING_SHORT","Kritisch","Critical Strike"},
    {"ITEM_MOD_DEFENSE_SKILL_RATING_SHORT","Verteidigung","Defense"},
    {"RESISTANCE0_NAME","Rüstung","Armor"},
}
local function english(self) return self.locale~="deDE" end
local function localized(self,de,en) return english(self) and en or de end
local function cleanLink(link)
    if type(link)~="string" or FG.IsSecret(link) then return nil end
    local id=tonumber(link:match("item:(%d+)"))
    if not id or id<1 or id>2000000 then return nil end
    return link,id
end

-- No persistent inventory snapshot, and no background scanning of bags.
-- The public client item cache may not contain full details for every link.
function FG:ReadItemLink(link,slot)
    if self:InCombat() then return nil end
    local id
    link,id=cleanLink(link)
    if not link then return nil end
    local infoFunc=C_Item and C_Item.GetItemInfo or GetItemInfo
    local name,quality,itemLevel,minLevel,equipLoc,classID
    if type(infoFunc)=="function" then
        local ok,a,b,c,d,e,_,_,_,i,_,_,j=pcall(infoFunc,link)
        if ok then name,quality,itemLevel,minLevel,equipLoc,classID=a,c,d,e,i,j end
    end
    if FG.IsSecret(name) or type(name)~="string" then name=nil end
    if not FG.IsNumber(quality) then quality=nil end
    if not FG.IsNumber(itemLevel) then itemLevel=nil end
    if not FG.IsNumber(minLevel) then minLevel=nil end
    if FG.IsSecret(equipLoc) or type(equipLoc)~="string" then equipLoc=nil end
    local stats={}
    local statFn=C_Item and C_Item.GetItemStats or GetItemStats
    local raw=FG.Safe(statFn,link)
    if type(raw)=="table" and not FG.IsSecret(raw) then
        for _,row in ipairs(statKeys) do
            local v=raw[row[1]]
            if FG.IsNumber(v) and v~=0 and math.abs(v)<=100000 then
                stats[#stats+1]={de=row[2],en=row[3],value=v}
            end
        end
    end
    return {id=id,slot=slot,name=FG.Clean(name or ("Item #"..id),100),quality=quality,itemLevel=itemLevel,minLevel=minLevel,stats=stats,equipLoc=equipLoc,classID=classID}
end

function FG:ReadEquipmentSlot(slot)
    if self:InCombat() then return nil end
    local link=FG.Safe(GetInventoryItemLink,"player",slot)
    return self:ReadItemLink(link,slot)
end

-- Read only after a deliberate /fai taschen (or bags) request.
-- The client may have different bag APIs; unsupported slots are skipped.
function FG:BagItems(maxItems)
    local result={}
    if self:InCombat() then return result end
    local api=C_Container or _G
    local numSlots=api and api.GetContainerNumSlots
    local linkFn=api and api.GetContainerItemLink
    if type(numSlots)~="function" or type(linkFn)~="function" then return result end
    maxItems=math.min(math.max(1,tonumber(maxItems) or 24),40)
    for bag=0,4 do
        local slots=FG.Safe(numSlots,bag)
        if FG.IsNumber(slots) and slots>=0 and slots<=60 then
            for slot=1,slots do
                local item=self:ReadItemLink(FG.Safe(linkFn,bag,slot),slot)
                if item then
                    item.slotDe="Tasche "..bag.."/"..slot
                    item.slotEn="Bag "..bag.."/"..slot
                    result[#result+1]=item
                    if #result>=maxItems then return result end
                end
            end
        end
    end
    return result
end

function FG:AskBagItems()
    local rows=self:BagItems(24)
    if #rows==0 then
        self:Say(localized(self,"Keine lesbaren Taschengegenstände; möglicherweise sind die Containerdaten nicht verfügbar oder du bist im Kampf.",
            "No readable bag items; container data may be unavailable or combat is active."))
        return
    end
    self:Say(localized(self,"Gegenstände aus deinen Taschen (max. 24, nur lesbare Daten):",
        "Items in your bags (up to 24 with available data):"))
    for _,row in ipairs(rows) do self:Say(self:FormatEquipmentItem(row)) end
end

function FG:BagText(maxItems)
    local rows=self:BagItems(maxItems or 20)
    local lines={localized(self,"Ausdrücklich angefragte Taschenübersicht:","Explicitly requested bag inventory:")}
    for _,row in ipairs(rows) do lines[#lines+1]=self:FormatEquipmentItem(row) end
    if #rows==0 then lines[#lines+1]=localized(self,"Keine lesbaren Taschengegenstände.","No readable bag items.") end
    return table.concat(lines,"\n")
end

function FG:EquipmentRows()
    local records={}
    if self:InCombat() then return records end
    for _,slot in ipairs(SLOTS) do
        local item=self:ReadEquipmentSlot(slot[1])
        if item then item.slotDe=slot[2]; item.slotEn=slot[3]; records[#records+1]=item end
    end
    return records
end

function FG:FormatEquipmentItem(item)
    local label=localized(self,item.slotDe or "Inventar",item.slotEn or "Bag")
    local s=label..": "..item.name.." (#"..item.id..")"
    if item.itemLevel then s=s.." · ilvl "..item.itemLevel end
    if item.minLevel and item.minLevel>0 then s=s..localized(self," · ab Stufe "," · requires ")..item.minLevel end
    local parts={}
    for _,stat in ipairs(item.stats or {}) do
        parts[#parts+1]=localized(self,stat.de,stat.en).." "..(stat.value>0 and "+" or "")..stat.value
        if #parts>=7 then break end
    end
    if #parts>0 then s=s.." · "..table.concat(parts,", ") end
    return s
end

function FG:EquipmentText()
    if self:InCombat() then return localized(self,"Ausrüstungsdaten im Kampf nicht gelesen.","Equipment inspection paused in combat.") end
    local rows=self:EquipmentRows()
    local lines={localized(self,"Aktuell angelegte Ausrüstung (Clientdaten, nur lesbar wenn verfügbar):",
        "Currently equipped items (client data, if available):")}
    for _,row in ipairs(rows) do lines[#lines+1]=self:FormatEquipmentItem(row) end
    if #rows==0 then lines[#lines+1]=localized(self,"Keine Itemdaten vom Client erhalten.","No item data returned by the client.") end
    lines[#lines+1]=localized(self,
        "Wichtig: Itemlevel/Attribute allein beweisen kein Upgrade. Waffenschaden, Tempo, Effekte, Skillung und Waffenfertigkeit müssen zusätzlich verglichen werden.",
        "Important: item level/stats alone do not prove an upgrade. Damage, speed, effects, spec and weapon proficiency also matter.")
    return table.concat(lines,"\n")
end

function FG:AskEquipment()
    local rows=self:EquipmentRows()
    if #rows==0 then
        self:Say(localized(self,"Keine lesbaren ausgerüsteten Items oder gerade im Kampf.","No readable equipped items, or combat is active."))
        return
    end
    self:Say(localized(self,"Deine ausgerüsteten Gegenstände:","Your equipped gear:"))
    for _,row in ipairs(rows) do self:Say(self:FormatEquipmentItem(row)) end
    self:Say(localized(self,"Waffen: Schaden und Spezialeffekte müssen zusätzlich geprüft werden. Für KI-Vergleich 'KI-Export' drücken; du siehst den Text vor dem Teilen.",
        "Weapons: damage and special effects need separate verification. Use AI Export for a comparison; you can review the text before sharing."))
end

-- Only relevant weapon candidates with known, curated acquisition sources.
-- Never rank by made-up DPS or mark a candidate as an actual upgrade.
function FG:WeaponSuggestions(query)
    local q=FG.Normalize(query)
    local words=" "..q.." "
    local function has(part) return words:find(" "..part.." ",1,true)~=nil end
    if not (has("besser") or has("besseres") or has("bessere") or has("upgrade") or has("upgrades") or has("better") or has("waffenberatung") or has("weaponupgrade")) then return false end
    if not (q:find("schwert",1,true) or q:find("sword",1,true) or q:find("waffe",1,true) or q:find("weapon",1,true) or q:find("axt",1,true) or q:find("axe",1,true)) then return false end
    local class=select(2,FG.Safe(UnitClass,"player"))
    if class and class~="WARRIOR" and not (q:find("krieger",1,true) or q:find("warrior",1,true)) then return false end
    local level=FG.Safe(UnitLevel,"player")
    if not FG.IsNumber(level) then level=nil end
    local sword=q:find("schwert",1,true) or q:find("sword",1,true)
    local axe=q:find("axt",1,true) or q:find("axe",1,true)
    local candidates={}
    for key,d in pairs(self.LootData or {}) do
        for _,item in ipairs(d.items or {}) do
            if (item.kind=="1h" or item.kind=="2h") and
                (not sword or FG.Normalize(item.typeDe):find("schwert",1,true) or FG.Normalize(item.typeEn):find("sword",1,true)) and
                (not axe or FG.Normalize(item.typeDe):find("axt",1,true) or FG.Normalize(item.typeEn):find("axe",1,true)) and
                (not level or not item.level or item.level<=level) then
                candidates[#candidates+1]={item=item,key=key,dungeon=d}
            end
        end
    end
    table.sort(candidates,function(a,b)
        local al,bl=a.item.level or 0,b.item.level or 0
        if al==bl then return a.item.en<b.item.en end
        return al>bl
    end)
    self:Say(localized(self,"Deine aktuell ausgerüsteten Waffen (sofern lesbar):", "Your equipped weapons (if readable):"))
    for _,slot in ipairs({16,17}) do
        local item=self:ReadEquipmentSlot(slot)
        if item then
            item.slotDe=slot==16 and "Waffenhand" or "Schildhand"
            item.slotEn=slot==16 and "Main hand" or "Off hand"
            self:Say(self:FormatEquipmentItem(item))
        end
    end
    if #candidates==0 then
        self:Say(localized(self,"Keine passende Waffe mit bekannter Beutequelle in der kleinen Offline-Auswahl.","No matching weapon with a curated source in this small offline list."))
        return true
    end
    self:Say(localized(self,"Mögliche Alternativen (keine geprüften Upgrades):", "Possible alternatives (not verified upgrades):"))
    for i=1,math.min(5,#candidates) do
        local c=candidates[i]
        local name=localized(self,c.item.de,c.item.en)
        local boss=localized(self,c.item.bossDe,c.item.bossEn)
        local dungeon=localized(self,c.dungeon.de,c.dungeon.en)
        local line=i..". "..name.." — "..dungeon.." / "..boss
        if c.item.level then line=line..localized(self," · ab "," · lvl ")..c.item.level end
        if c.item.id then
            local info=FG.Safe(C_Item and C_Item.GetItemInfo or GetItemInfo,"item:"..c.item.id)
            if type(info)=="string" and not FG.IsSecret(info) then line=line.." · #"..c.item.id end
        end
        self:Say(line)
    end
    self:Say(localized(self,"Die Quelle ist Community-Beute, nicht live garantiert. Im Suchfenster kannst du einen gefundenen Dungeon auswählen und die ungefähre Wegführung starten.",
        "Sources are community loot data, not guaranteed live drops. You can select a matching dungeon in search results and start approximate guidance."))
    return true
end
