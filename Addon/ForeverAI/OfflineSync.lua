-- ForeverAI 0.9: cached, public WoW Forever knowledge available entirely inside
-- the game. Companion may replace SyncData.lua on disk, but WoW reads it only
-- after next login or /reload. No external communication from addon Lua.
local _,FG=...
local function localize(self,de,en) return self.locale=='deDE' and de or en end
local function norm(s) return FG.Normalize(s or '') end
local function canonical(s) return FG.Canonical(s or '') end
local function contains(q,s)
    s=norm(s)
    return #s>2 and (' '..q..' '):find(' '..s..' ',1,true)~=nil
end
local function has(q,words)
    for _,word in ipairs(words) do if contains(q,word) then return true end end
    return false
end
local function validCache(s)
    return type(s)=='table' and s.schema==1 and type(s.dungeons)=='table' and
        type(s.items)=='table' and type(s.quests)=='table' and type(s.rares)=='table'
end
function FG:SyncedDataStatus()
    local data=self.SyncData
    if not validCache(data) or not data.syncedAt or data.syncedAt=='' then
        return localize(self,'Keine automatisch synchronisierten Internetdaten geladen. Begleit-App starten, dort den Forever-Spielordner einmal einrichten und Daten laden; danach neu einloggen oder /reload.','No synchronized internet data loaded. Configure your Forever game folder and sync in the desktop companion once, then log in again or /reload.')
    end
    local info=string.format('Forever Companion · %d Dungeons · %d Items · %d Quests · %d Rares',
        #data.dungeons,#data.items,#data.quests,#data.rares)
    local status=localize(self,'Datenstand: ','Data updated: ')..FG.Clean(data.updatedAt or '',55)
    if data.incomplete then status=status..localize(self,' · Teilauswahl durch Schutzlimit',' · partial cache due to safety cap') end
    return info..' · '..status..localize(self,' · Neue Daten nach Login oder /reload.',' · New data after login or /reload.')
end
local function pinFor(self,id)
    local d
    for _,dungeon in ipairs(self.SyncData.dungeons or {}) do if dungeon.id==id then d=dungeon;break end end
    if not d or not d.pinKey then return nil end
    return self:LocateDungeonByKey(d.pinKey)
end
local function locationRow(self,name,detail,dungeonId)
    local pin=pinFor(self,dungeonId)
    local row={name=FG.Clean(name,110),detail=FG.Clean(detail,190),source='Forever Companion',
        sourceURL='https://forevercompanion.io/developers'}
    if pin and FG.IsNumber(pin.mapID) and FG.IsNumber(pin.x) and FG.IsNumber(pin.y) then
        local place=localize(self,pin.de,pin.en)
        row.route={name=name..' — '..place,kind='dungeon',points={{mapID=pin.mapID,x=pin.x/100,y=pin.y/100,
            label=place,kind='dungeon',note=localize(self,pin.noteDe,pin.noteEn)}}}
        row.detail=row.detail..localize(self,' · Annäherungspfeil',' · approach arrow')
    end
    return row
end
local function matchingDungeon(self,d,q)
    if contains(q,d.name) then return true end
    local pin=pinFor(self,d.id)
    if pin then
        if contains(q,pin.de) or contains(q,pin.en) then return true end
        for _,alias in ipairs(pin.aliases or {}) do if contains(q,alias) then return true end end
        -- A user may type only the second half of a localized multiword name.
        local tail=canonical(pin.de):match('(%S+)$')
        if tail and #tail>=7 and contains(q,tail) then return true end
    end
    local last=canonical(d.name):match('(%S+)$')
    return last and #last>=8 and contains(q,last) or false
end
local function itemTypeQuery(q)
    if has(q,{'schwert','schwerter','sword','swords'}) then return 'sword' end
    if has(q,{'axt','äxte','aexte','axe','axes'}) then return 'axe' end
    if has(q,{'schild','schilde','shield','shields'}) then return 'shield' end
    if has(q,{'dolch','dagger'}) then return 'dagger' end
    if has(q,{'streitkolben','kolben','mace'}) then return 'mace' end
    if has(q,{'stab','staff'}) then return 'staff' end
    return nil
end
local function itemMatchesType(item,requested)
    if not requested then
        local v=norm(item.weaponType or '')..' '..norm(item.slot or '')
        return v:find('sword',1,true) or v:find('axe',1,true) or v:find('mace',1,true)
            or v:find('dagger',1,true) or v:find('staff',1,true) or v:find('shield',1,true)
            or v:find('hand',1,true)
    end
    return norm(item.weaponType):find(requested,1,true) or norm(item.slot):find(requested,1,true)
end
local function levelOf(self,q)
    local level=tonumber((' '..q..' '):match(' level (%d%d?) ') or (' '..q..' '):match(' lvl (%d%d?) ') or (' '..q..' '):match(' stufe (%d%d?) '))
    if not level then level=FG.Safe(UnitLevel,'player') end
    if FG.IsNumber(level) and level>=1 and level<=60 then return level end
    return nil
end
local function showRows(self,rows,title,query)
    if #rows==0 then return false end
    self:Say(title)
    for i=1,math.min(#rows,6) do
        self:Say(i..'. '..FG.Clean(rows[i].name,100)..' — '..FG.Clean(rows[i].detail,190))
    end
    if self.ShowSearchResults then self:ShowSearchResults(rows,query) end
    self:Say(localize(self,'Treffer anklicken. Navigation gibt es nur bei bekanntem Anreisepunkt.','Click a result. Guidance is available only for known approach points.'))
    return true
end
local function describeItem(self,item)
    local level=item.level and 'Lv '..item.level or localize(self,'Level unbekannt','level unknown')
    local info=FG.Clean(item.weaponType or item.slot or '',30)
    if item.itemLevel then info=info..' · ilvl '..item.itemLevel end
    if item.verified and item.verified>0 then info=info..localize(self,' · teilweise bestätigt',' · partially verified')
    elseif item.classicOnly then info=info..localize(self,' · Classic-Daten ungeprüft',' · Classic-derived unverified') end
    return level..' · '..info
end
function FG:SyncedWeaponResults(raw)
    local data=self.SyncData
    if not validCache(data) or not data.syncedAt or data.syncedAt=='' then return false end
    local q=norm(raw)
    local gearIntent=has(q,{'schwert','schwerter','sword','waffe','waffen','weapon','swords','axt','axe',
        'schild','shield','dolch','dagger','mace','kolben','stab','staff','upgrade','ausrüstung','ausruestung'})
    if not gearIntent then return false end
    local level,wanted=levelOf(self,q),itemTypeQuery(q)
    local candidates={}
    for _,item in ipairs(data.items) do
        if type(item)=='table' and type(item.name)=='string' and itemTypeQuery and itemMatchesType(item,wanted)
            and (not level or not item.level or item.level<=level) then
            local source=item.drops and item.drops[1]
            if type(source)=='table' and source.dungeonId and source.dungeonId~='' then
                candidates[#candidates+1]={item=item,source=source}
            end
        end
    end
    table.sort(candidates,function(a,b)
        local av=a.item.level or 0;local bv=b.item.level or 0
        if av~=bv then return av>bv end
        local al=a.item.itemLevel or 0;local bl=b.item.itemLevel or 0
        if al~=bl then return al>bl end
        return a.item.name<b.item.name
    end)
    if #candidates==0 then return false end
    local worn=self.ReadEquipmentSlot and self:ReadEquipmentSlot(16)
    if worn then
        self:Say(localize(self,'Derzeitige Waffenhand: ','Equipped main hand: ')..self:FormatEquipmentItem(worn))
    end
    local rows={}
    for i=1,math.min(#candidates,12) do
        local c=candidates[i]
        local dungeon;for _,d in ipairs(data.dungeons) do if d.id==c.source.dungeonId then dungeon=d.name;break end end
        local detail=describeItem(self,c.item)..' · '..FG.Clean(dungeon or c.source.dungeonId,70)
        if c.source.boss and c.source.boss~='' then detail=detail..' / '..FG.Clean(c.source.boss,60) end
        rows[#rows+1]=locationRow(self,c.item.name,detail,c.source.dungeonId)
    end
    self:Say(localize(self,'Aus der synchronisierten Beuteliste: mögliche Waffen, KEINE bestätigten Upgrades. Waffenschaden, Tempo, Effekte und Skillung sind nicht vollständig verglichen.',
        'From synchronized loot: weapon candidates, NOT verified upgrades. Damage, speed, effects and spec have not been fully compared.'))
    return showRows(self,rows,localize(self,'Waffen aus Forever Companion:','Weapons from Forever Companion:'),raw)
end
function FG:SearchSynced(raw)
    local data=self.SyncData
    if not validCache(data) or not data.syncedAt or data.syncedAt=='' then return false end
    local q=norm(raw)
    if FG.AmbiguousTerm(raw) then return false end
    local loot=has(q,{'beute','loot','drop','drops','gegenstand','gegenstände','gegenstaende','waffen','waffe','items','item','rüstung','ruestung'})
    local results={}
    -- Named dungeon queries should reveal actual loot when relevant, not just a generic class tip.
    if loot then
        for _,d in ipairs(data.dungeons) do
            if matchingDungeon(self,d,q) then
                local matches={}
                for _,item in ipairs(data.items) do
                    for _,drop in ipairs(item.drops or {}) do
                        if drop.dungeonId==d.id then matches[#matches+1]={item=item,drop=drop};break end
                    end
                end
                table.sort(matches,function(a,b)
                    return (a.item.itemLevel or 0)>(b.item.itemLevel or 0)
                end)
                for _,found in ipairs(matches) do
                    if #results>=18 then break end
                    local detail=describeItem(self,found.item)
                    if found.drop.boss~='' then detail=detail..' · '..FG.Clean(found.drop.boss,70) end
                    results[#results+1]=locationRow(self,found.item.name,detail,d.id)
                end
                if #results>0 then
                    self:Say(localize(self,'Dungeonbeute laut Community-Daten (nicht garantiert):','Dungeon loot from community data (not guaranteed):'))
                    return showRows(self,results,localize(self,d.name..' · Beute',d.name..' · loot'),raw)
                end
            end
        end
    end
    if self:SyncedWeaponResults(raw) then return true end
    local where=has(q,{'wo','where','finden','finde','find','quest','quests','npc','rare','selten','lehrer','trainer','dungeon','dungeons','instanz','instanzen','dungen'})
    if where then
        -- For named dungeon and quest matches, show text and a known approach point.
        for _,d in ipairs(data.dungeons) do
            if matchingDungeon(self,d,q) then
                local detail='Lv '..tostring(d.min or '?')..'-'..tostring(d.max or '?')..' · '..FG.Clean(d.zone,65)
                if d.entrance~='' then detail=detail..' · '..FG.Clean(d.entrance,75) end
                results[#results+1]=locationRow(self,d.name,detail,d.id)
            end
        end
        if #results>0 then return showRows(self,results,localize(self,'Dungeon-Ziele:','Dungeon destinations:'),raw) end
        if has(q,{'dungeon','dungeons','dungen','instanz','instanzen'}) then
            local level=levelOf(self,q)
            for _,d in ipairs(data.dungeons) do
                if not level or (not d.min or level>=d.min) and (not d.max or level<=d.max) then
                    local detail='Lv '..tostring(d.min or '?')..'-'..tostring(d.max or '?')..' · '..FG.Clean(d.zone,65)
                    results[#results+1]=locationRow(self,d.name,detail,d.id)
                    if #results>=18 then break end
                end
            end
            if #results>0 then return showRows(self,results,localize(self,'Dungeons für dein Level (Richtwerte):','Dungeons for your level (indicative ranges):'),raw) end
        end
        for _,quest in ipairs(data.quests) do
            if contains(q,quest.name) then
                local detail=FG.Clean(quest.giver,75)..' · '..FG.Clean(quest.location or quest.zone,85)
                results[#results+1]=locationRow(self,quest.name,detail,quest.dungeonId)
                if #results>=12 then break end
            end
        end
        if #results>0 then return showRows(self,results,localize(self,'Quests aus der Datenbank:','Quests from data cache:'),raw) end
        if has(q,{'quest','quests','aufgabe','aufgaben'}) and has(q,{'level','lvl','stufe'}) then
            local level=levelOf(self,q)
            if level then
                for _,quest in ipairs(data.quests) do
                    if (not quest.min or quest.min<=level) and (not quest.level or math.abs(quest.level-level)<=3) then
                        local detail=FG.Clean(quest.giver,70)..' · '..FG.Clean(quest.location or quest.zone,75)
                        results[#results+1]=locationRow(self,quest.name,detail,quest.dungeonId)
                        if #results>=16 then break end
                    end
                end
                if #results>0 then return showRows(self,results,localize(self,'Quests für dein Level:','Quests for your level:'),raw) end
            end
        end
        for _,rare in ipairs(data.rares) do
            if contains(q,rare.name) then
                local xy=table.concat(rare.coords or {},' | ')
                local info=FG.Clean(rare.zone,70)..' · '..FG.Clean(xy,80)
                results[#results+1]={name=rare.name,detail=info,source='Forever Companion'}
                if #results>=10 then break end
            end
        end
        if #results>0 then return showRows(self,results,localize(self,'Seltene Gegner (ohne sichere Karten-ID):','Rares (no verified map ID):'),raw) end
    end
    return false
end
