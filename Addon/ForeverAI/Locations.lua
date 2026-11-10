-- ForeverAI 0.7: curated outdoor *approach* points and optional read-only
-- QuestieDB NPC lookup. NO automatic download, network call, scraping or
-- assertion that community coordinates are a walkable path.
local _, FG = ...
local function de(self,a,b) return self.locale=="deDE" and a or b end
local function contains(text,word)
    return (" "..FG.Normalize(text).." "):find(" "..FG.Normalize(word).." ",1,true)~=nil
end
local function any(text,...)
    for i=1,select("#",...) do
        if contains(text,select(i,...)) then return true end
    end
    return false
end

-- Each address below is a community-reported outdoor point, not a guaranteed
-- portal or route. x/y from sources in LOCATION_SOURCES.md; mapID is WoW UiMap.
FG.LocationPins = {
 {id="deadmines",de="Todesminen",en="The Deadmines",aliases={"Deadmines","Die Todesminen"},
  mapID=1436,x=38.2,y=77.5,zoneDe="Westfall",zoneEn="Westfall",min=17,max=26,
  noteDe="Zugang im Gebäude von Mondbruch. In den Minenschacht hinabgehen und dem Tunnel bis zum Portal folgen.",
  noteEn="Approach in Moonbrook; enter the building, descend into the mine and follow tunnels to the portal.",
  source="Nerdsquare",url="https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/"},
 {id="shadowfang",de="Burg Schattenfang",en="Shadowfang Keep",aliases={"Schattenfang","Schattenfangburg","Schattenburg","SFK"},
  mapID=1421,x=44.7,y=67.8,zoneDe="Silberwald",zoneEn="Silverpine Forest",min=18,max=30,
  noteDe="Nur Außenannäherung. Finde vor Ort die Burgzufahrt und den tatsächlichen Instanzzugang.",
  noteEn="Outdoor approach only. Find the castle approach and actual instance portal locally.",
  source="azeroth.wiki",url="https://azeroth.wiki/forever/map/silverpine-forest/shadowfang-keep"},
 {id="wailing",de="Höhlen des Wehklagens",en="Wailing Caverns",aliases={"Wailing Caverns","WC"},
  mapID=1413,x=46.0,y=36.5,zoneDe="Brachland",zoneEn="The Barrens",min=17,max=25,
  noteDe="Außenannäherung am Höhleneingang. Innen führen mehrere Abzweigungen zum Portal.",
  noteEn="Outdoor approach near the cavern. Inside, several tunnels lead to the portal.",
  source="questing.wiki",url="https://questing.wiki/wow-forever/dungeons/wailing-caverns/"},
 {id="gnomeregan",de="Gnomeregan",en="Gnomeregan",aliases={"Gnomeregan Eingang"},
  mapID=1426,x=24.3,y=39.8,zoneDe="Dun Morogh",zoneEn="Dun Morogh",min=29,max=38,
  noteDe="Außenannäherung am Eingangshaus. Anschließend hinunter zum Aufzug und durch den Tunnel zum Portal.",
  noteEn="Approach to the outer entrance building. Take the lift and follow the tunnel to the portal.",
  source="questing.wiki",url="https://questing.wiki/wow-forever/dungeons/gnomeregan/"},
 {id="stockades",de="Das Verlies",en="The Stockade",aliases={"Verlies","Stockades","Stockade","Das Verlies in Sturmwind"},
  mapID=1453,x=52.41,y=70.01,zoneDe="Sturmwind",zoneEn="Stormwind City",min=22,max=30,
  noteDe="Außenannäherung innerhalb Sturmwinds. Koordinaten nicht als überprüften Fußweg verstehen.",
  noteEn="Approach inside Stormwind. Coordinates do not represent a verified walking route.",
  source="questing.wiki",url="https://questing.wiki/wow-forever/dungeons/stockades/"},
 {id="ragefire",de="Flammenschlund",en="Ragefire Chasm",aliases={"Ragefire","RFC"},
  mapID=1454,x=52.8,y=49.6,zoneDe="Orgrimmar",zoneEn="Orgrimmar",min=13,max=18,
  noteDe="Eingangsbereich in Orgrimmar. Geh unter die Stadt zum eigentlichen Höhleneingang.",
  noteEn="Entrance area in Orgrimmar. Find the cave beneath the city.",
  source="Nerdsquare",url="https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/"},
 {id="thanes",de="Halle der Thanen",en="Hall of Thanes",aliases={"Halle der Thane","Hall of Thanes"},
  mapID=1455,x=43.5,y=52.0,zoneDe="Eisenschmiede",zoneEn="Ironforge",min=13,max=18,
  noteDe="Ungefährer Eingangsbereich in Eisenschmiede; die Unterführung vor Ort suchen.",
  noteEn="Approximate entrance area in Ironforge; locate the underground passage on arrival.",
  source="Nerdsquare",url="https://forever.nerdsquare.eu/guides/dungeons/dungeoneingange/"},
}

-- Settlements are kept separate from dungeon entrances and dungeon-level lists.
FG.SettlementPins = {
 {id="goldshire",de="Goldhain",en="Goldshire",mapID=1429,x=42.4,y=66.6,
  zoneDe="Wald von Elwynn",zoneEn="Elwynn Forest",kind="waypoint",
  noteDe="Ungefähre Ortsmitte laut Forever-Kartendaten.",noteEn="Approximate settlement center from Forever map data.",
  source="WoW Forever DB",url="https://wowfdb.com/zones/elwynn-forest/map/"},
}

-- Limited, explicit AreaID -> UiMapID mapping for QuestieDB spawn tuples.
-- Arbitrary area IDs are deliberately not treated as UiMap IDs.
local AREA_MAP = {
 [1]=1426,[12]=1429,[40]=1436,[130]=1421,[17]=1413,[1519]=1453,
 [1537]=1455,[1637]=1454,[85]=1420,[14]=1411,[215]=1412,
 [10]=1431,[44]=1433,[38]=1432,[11]=1437,[267]=1424,
 [33]=1434,[1497]=1458,[1657]=1457,[1638]=1456,[16591]=2548,[16593]=2521,
}
FG.KnownAreaMap=AREA_MAP
local AREA_NAME_MAP={}
for area,map in pairs(AREA_MAP) do AREA_NAME_MAP[area]=map end

-- Read the published QuestieDB mapping as data only; never execute its Lua text.
-- The separate override table contains legacy dungeon aliases, so it is not used.
function FG:InitQuestieAreaMap()
    local db=_G.LibQuestieDB
    local status=db and db.ModeIndicator and FG.Safe(db.ModeIndicator.GetStatus)
    if type(status)=="table" and type(status.expansion)=="string" and FG.Normalize(status.expansion)~="forever" then return end
    local zones=db and db.Support and FG.Safe(db.Support.Get,"ZoneDB")
    local private=type(zones)=="table" and type(zones.private)=="table" and zones.private
    local raw=private and private.areaIdToUiMapId
    local reverse=private and private.uiMapIdToAreaId
    local count=0
    local function decode(source)
        local values={}
        if type(source)=="string" and #source<=1000000 then
            for line in (source.."\n"):gmatch("([^\n]*)\n") do
                local a,b=line:match("^%s*%[(%d+)%]%s*=%s*(%d+)%s*[,}]%s*")
                if a then values[tonumber(a)]=tonumber(b) end
            end
        elseif type(source)=="table" then
            for a,b in pairs(source) do if FG.IsNumber(a) and FG.IsNumber(b) then values[a]=b end end
        end
        return values
    end
    local areas,maps=decode(raw),decode(reverse)
    for area,map in pairs(areas) do
        if area>0 and area%1==0 and map>0 and map%1==0 then
            AREA_NAME_MAP[area]=map
            -- A parent-map assignment alone does not reproject subarea coordinates.
            if maps[map]==area and not AREA_MAP[area] then AREA_MAP[area]=map;count=count+1 end
        end
    end
    self.questieAreaCount=count
    if C_Map and type(C_Map.GetAreaInfo)=="function" then
        local ids={};for area in pairs(AREA_NAME_MAP) do ids[#ids+1]=area end;table.sort(ids)
        self.questieAreaNames={}
        local index=1
        local frame=CreateFrame("Frame")
        frame:SetScript("OnUpdate",function(f)
            for _=1,100 do
                local area=ids[index]
                if not area then f:SetScript("OnUpdate",nil);self.questieAreaIndexReady=true;return end
                local name=FG.Safe(C_Map.GetAreaInfo,area)
                if type(name)=="string" and not FG.IsSecret(name) then
                    local key=FG.Normalize(name)
                    if #key>=4 and #key<=120 then
                        local bucket=self.questieAreaNames[key] or {}
                        if #bucket<12 then bucket[#bucket+1]={id=area,name=FG.Clean(name,100),mapID=AREA_NAME_MAP[area]} end
                        self.questieAreaNames[key]=bucket
                    end
                end
                index=index+1
            end
        end)
        self.questieAreaIndexFrame=frame
    end
end

function FG:ClientAreaResults(question)
    local entries=self.QuestieIndexedNames and self:QuestieIndexedNames(self.questieAreaNames,question) or {}
    local rows,seen={},{}
    for _,area in ipairs(entries) do
        local info=FG.Safe(C_Map and C_Map.GetMapInfo,area.mapID)
        local name=type(info)=="table" and info.name
        local key=area.name..":"..area.mapID
        if type(name)=="string" and not FG.IsSecret(name) and not seen[key] then
            seen[key]=true
            rows[#rows+1]={name=area.name,detail=(self.locale=="deDE" and "Gebietskarte: " or "Zone map: ")..FG.Clean(name,80)..(self.locale=="deDE" and " · keine Ortskoordinaten" or " · no place coordinates"),source="WoW / QuestieDB"}
        end
    end
    return rows
end

function FG:ClientMapResults(query)
    local api=C_Map
    if not api or type(api.GetBestMapForUnit)~="function" or type(api.GetMapChildrenInfo)~="function" then return {} end
    local id=FG.Safe(api.GetBestMapForUnit,"player")
    local seen={}
    for _=1,12 do
        if not FG.IsNumber(id) or seen[id] then break end
        seen[id]=true
        local info=FG.Safe(api.GetMapInfo,id)
        if type(info)~="table" or not FG.IsNumber(info.parentMapID) or info.parentMapID<=0 then break end
        id=info.parentMapID
    end
    if not FG.IsNumber(id) then return {} end
    if self.clientMapRoot~=id or not self.clientMaps then
        local maps=FG.Safe(api.GetMapChildrenInfo,id,nil,true)
        if type(maps)~="table" then return {} end
        self.clientMapRoot=id;self.clientMaps=maps
    end
    local normalized=" "..FG.Canonical(query or "").." "
    local rows={}
    for _,info in ipairs(self.clientMaps) do
        if type(info)=="table" and FG.IsNumber(info.mapID) and type(info.name)=="string" and not FG.IsSecret(info.name) then
            local kinds=Enum and Enum.UIMapType
            local validType=kinds and (info.mapType==kinds.Zone or info.mapType==kinds.City)
            local name=FG.Canonical(info.name)
            if validType and #name>=4 and normalized:find(" "..name.." ",1,true) then
                local title=FG.Clean(info.name,80)
                local detail=de(self,"Gebietskartenmitte · nur ungefähr","Map center · approximate only")
                rows[#rows+1]={name=title,detail=detail,source="WoW Map",route={name=title,kind="waypoint",points={{mapID=info.mapID,x=.5,y=.5,label=title,note=detail}}}}
                if #rows>=8 then break end
            end
        end
    end
    return rows
end

local function locLabel(self,loc)
    return de(self,loc.de,loc.en)
end
local function locMatch(raw,loc)
    -- Recognize complete aliases, not single loose words like "die" or "der".
    local query=FG.Canonical(raw)
    if contains(query,FG.Canonical(loc.de)) or contains(query,FG.Canonical(loc.en)) then return true end
    for _,alias in ipairs(loc.aliases or {}) do if contains(raw,alias) then return true end end
    return false
end

function FG:LocateDungeonByKey(key)
    for _,loc in ipairs(self.LocationPins) do if loc.id==key then return loc end end
end

local function toResult(self,loc)
    local name=locLabel(self,loc)
    local kind=loc.kind or "dungeon"
    local point={mapID=loc.mapID,x=loc.x/100,y=loc.y/100,label=name,
        kind=kind,note=de(self,loc.noteDe,loc.noteEn)}
    local zone=de(self,loc.zoneDe,loc.zoneEn)
    return {name=name,detail=zone.." · "..string.format("%.2f / %.2f",loc.x,loc.y).." · "..
        de(self,"Community · Annäherung","Community · approach"),
        route={name=name,kind=kind,points={point}},source=loc.source,sourceURL=loc.url,key=loc.id}
end

function FG:DungeonLocationResult(loc)
    if type(loc)~="table" or not loc.mapID or not self:MapInfo(loc.mapID) then return nil end
    return toResult(self,loc)
end

local function QueryClass(raw)
    local words=FG.Canonical(raw)
    local found={}
    for _,t in ipairs(FG.TermsIn(raw)) do
        if t.kind=="class" or t.kind=="profession" then found[#found+1]=t.id end
    end
    return found[1],words
end

local function relevantWords(raw)
    -- Only use words which can identify an NPC; all common search words and
    -- zone names are stripped. Avoid broad, accidental name matching.
    local ignored={wo=true,wie=true,ist=true,sind=true,der=true,die=true,das=true,den=true,
        mein=true,meine=true,meinen=true,finde=true,finden=true,ich=true,mir=true,du=true,
        suche=true,gesucht=true,wohin=true,zu=true,zum=true,zur=true,["in"]=true,im=true,
        bitte=true,zeigt=true,zeige=true,zeig=true,karte=true,person=true,personen=true,
        koordinaten=true,coordinates=true,coords=true,welchen=true,welche=true,welcher=true,liegt=true,findet=true,what=true,
        lehrer=true,ausbilder=true,npc=true,trainer=true,klassenlehrer=true,berufslehrer=true,
        where=true,is=true,are=true,the=true,can=true,i=true,my=true,find=true,locate=true,
        please=true,show=true,me=true,location=true,of=true,at=true,["for"]=true,
        class=true,profession=true,from=true,to=true,instructor=true,way=true,route=true}
    local terms={}
    for _,t in ipairs(FG.TermsIn(raw)) do if t.kind=="location" then terms[t.id]=true end end
    local seen={};local tokens={}
    for word in FG.Canonical(raw):gmatch("%S+") do
        if not ignored[word] and not terms[word] and word:sub(1,6)~="fgterm" and #word>2 and not tonumber(word) and not seen[word] then
            tokens[#tokens+1]=word;seen[word]=true
        end
    end
    return tokens,terms
end

function FG:QuestieNpcResults(raw, maxResults)
    local provider=_G.LibQuestieDB
    if type(provider)~="table" or type(provider.Npc)~="table" then return {},"missing" end
    local status=provider.ModeIndicator and provider.ModeIndicator.GetStatus and FG.Safe(provider.ModeIndicator.GetStatus)
    if type(status)=="table" and type(status.expansion)=="string" and FG.Normalize(status.expansion)~="forever" then
        return {},"wrong_flavor"
    end
    local npc=provider.Npc
    if type(npc.GetAllIds)~="function" or type(npc.name)~="function" or type(npc.spawns)~="function" then return {},"api" end
    local nameWords,terms=relevantWords(raw)
    local trainerWanted=any(raw,"lehrer","trainer","ausbilder","class trainer","berufslehrer","klassenlehrer")
        or FG.Canonical(raw):find("fgtermtrainer",1,true)~=nil
    local cls=QueryClass(raw)
    if not trainerWanted and #nameWords==0 then return {},"unspecific" end
    local filterMap
    for key in pairs(terms) do
        local mapByTerm={stormwind=1453,ironforge=1455,orgrimmar=1454,elwynn=1429,westfall=1436,
            dunmorogh=1426,barrens=1413,redridge=1433,duskwood=1431,undercity=1458}
        if mapByTerm[key] then filterMap=mapByTerm[key];break end
    end
    -- Generic trainer queries without explicit class/profession/city are limited to player map.
    local playerMap=FG.Safe(C_Map and C_Map.GetBestMapForUnit,"player")
    if not filterMap and trainerWanted and not cls then filterMap=playerMap end
    local exact=self.QuestieIndexedNames and self:QuestieIndexedNames(self.questieNpcNames,raw) or {}
    local ids=#exact>0 and exact or self.questieNpcIndex or FG.Safe(npc.GetAllIds)
    if type(ids)~="table" then return {},"api" end
    local hits={}
    for idx,entry in ipairs(ids) do
        if idx>20000 then break end
        local id=type(entry)=="table" and entry.id or entry
        if type(id)=="number" and id>0 then
            local npcName=type(entry)=="table" and entry.name or FG.Safe(npc.name,id)
            local npcSub=type(entry)=="table" and entry.sub or FG.Safe(npc.subName,id)
            if type(npcName)=="string" and not FG.IsSecret(npcName) then
                npcSub=type(npcSub)=="string" and not FG.IsSecret(npcSub) and npcSub or ""
                local nameN=type(entry)=="table" and entry.canonicalName or FG.Canonical(npcName)
                local subN=type(entry)=="table" and entry.canonicalSub or FG.Canonical(npcSub)
                local isTrainer=not trainerWanted or subN:find("trainer",1,true) or subN:find("lehrer",1,true) or subN:find("ausbilder",1,true)
                local classMatched=not cls or contains(subN,cls) or (subN:find(cls,1,true) and #cls>=5)
                local named=true
                for _,w in ipairs(nameWords) do
                    if not contains(nameN,w) and not contains(subN,w) then named=false;break end
                end
                if #FG.Normalize(npcName)>=4 and contains(raw,npcName) then named=true end
                -- Class/profession tokens are matched through NPC subtitle.
                if trainerWanted and cls and #nameWords==1 and nameWords[1]==cls then named=true end
                if isTrainer and classMatched and named and (trainerWanted or #nameWords>0) then
                    local spawns=FG.Safe(npc.spawns,id)
                    if type(spawns)=="table" then
                        local best=nil
                        for area,places in pairs(spawns) do
                            local mapID=AREA_MAP[area]
                            if mapID and (not filterMap or mapID==filterMap) and type(places)=="table"
                                and FG.Safe(C_Map and C_Map.GetMapInfo,mapID) then
                                for _,coords in ipairs(places) do
                                    if type(coords)=="table" and FG.IsNumber(coords[1]) and FG.IsNumber(coords[2]) and
                                        coords[1]>=0 and coords[1]<=100 and coords[2]>=0 and coords[2]<=100 then
                                        local proximity=(mapID==playerMap) and 100 or 0
                                        local coordScore=0
                                        if mapID==playerMap then
                                            local player=FG.Safe(C_Map and C_Map.GetPlayerMapPosition,mapID,"player")
                                            local x,y=FG.XY(player)
                                            if x then coordScore=1-((x-coords[1]/100)^2+(y-coords[2]/100)^2) end
                                        end
                                        local score=proximity+coordScore+(npcSub~="" and 1 or 0)
                                        if not best or score>best.score then best={mapID=mapID,x=coords[1],y=coords[2],score=score} end
                                    end
                                end
                            end
                        end
                        if best then
                            local rowLabel=npcName..(npcSub~="" and " ("..npcSub..")" or "")
                            hits[#hits+1]={name=FG.Clean(rowLabel,110),detail=de(self,"QuestieDB · Community-Spawn, unbestätigt","QuestieDB · community spawn, unverified")..
                                " · "..string.format("%.1f / %.1f",best.x,best.y),
                                score=best.score,source="QuestieDB",sourceURL="https://github.com/Questie/QuestieDB",
                                route={name=npcName,kind=trainerWanted and "trainer" or "waypoint",points={{
                                    mapID=best.mapID,x=best.x/100,y=best.y/100,label=npcName,
                                    kind=trainerWanted and "trainer" or "waypoint",
                                    note=de(self,"Ungeprüfter Community-Spawnpunkt. NPC kann sich bewegen, in Gebäuden oder phasenabhängig sein.",
                                        "Unverified community spawn. NPC may move, be inside a building or be phased.")
                                }}}}
                        end
                    end
                end
            end
        end
    end
    table.sort(hits,function(a,b)
        if a.score~=b.score then return a.score>b.score end
        return a.name<b.name
    end)
    local limited={}
    for i=1,math.min(maxResults or 8,#hits) do limited[#limited+1]=hits[i] end
    return limited,nil
end

function FG:SearchLocationResults(query,collectOnly)
    local q=FG.Canonical(query)
    if FG.AmbiguousTerm(query) then return false end
    local levelQuery=q:find("dungeon",1,true) or q:find("instanz",1,true) or q:find("dungen",1,true)
    local searchIntent=any(q,"wo","wohin","eingang","eingänge","where","entrance","finde","finden","find","route","gehe","navigate","suche","search","lehrer","trainer","npc","location","ortsname","koordinaten","coordinates","coords")
        or q:find("wie komme",1,true) or q:find("how do i get",1,true)
    local gearQuery=q:find("schwert",1,true) or q:find("sword",1,true) or q:find("waffe",1,true) or q:find("weapon",1,true)
    local dungeonQuery=(q:find("instanz",1,true) or q:find("dungeon",1,true) or q:find("dungen",1,true))
    local explicitName=false
    for _,loc in ipairs(self.LocationPins) do
        if locMatch(query,loc) then explicitName=true;break end
    end
    local settlementQualifier=any(query,"npc","trainer","lehrer","ausbilder","quest","dungeon","instanz","eingang","entrance","item","gegenstand","waffe")
    if not settlementQualifier then
        for _,loc in ipairs(self.SettlementPins or {}) do if locMatch(query,loc) then explicitName=true;break end end
    end
    local itemName=false
    for _,d in pairs(self.LootData or {}) do
        for _,item in ipairs(d.items or {}) do
            local a,b=FG.Normalize(item.de),FG.Normalize(item.en)
            if #a>=5 and (contains(query,a) or contains(query,b)) then itemName=true;break end
        end
        if itemName then break end
    end
    local questResults=self.QuestieQuestResults and self:QuestieQuestResults(query) or {}
    local itemMatches,itemRows={},{}
    if searchIntent and self.QuestieItemResults then itemMatches,itemRows=self:QuestieItemResults(query) end
    if not searchIntent and not dungeonQuery and not gearQuery and not explicitName and not itemName and #questResults==0
        and not FG.Canonical(query):find("fgtermtrainer",1,true) then return false end
    local locations={}
    local added={}
    local function add(row)
        if row and #locations<24 then
            local k=row.key or (row.name..":"..tostring(row.route and row.route.points[1].mapID or "info"))
            if not added[k] then added[k]=true;locations[#locations+1]=row end
        end
    end
    for _,row in ipairs(questResults) do add(row) end
    for _,row in ipairs(itemRows) do add(row) end
    -- For gear questions, show the dungeon(s) containing candidate weapon drops.
    if gearQuery and (q:find("besser",1,true) or q:find("better",1,true) or q:find("upgrade",1,true)) then
        local wantsSword=q:find("sword",1,true) or q:find("schwert",1,true)
        local wantsAxe=q:find("axt",1,true) or q:find("axe",1,true)
        local level=FG.Safe(UnitLevel,"player")
        for key,d in pairs(self.LootData or {}) do
            for _,item in ipairs(d.items or {}) do
                if (item.kind=="1h" or item.kind=="2h") and
                    (not wantsSword or FG.Normalize(item.typeEn):find("sword",1,true)) and
                    (not wantsAxe or FG.Normalize(item.typeEn):find("axe",1,true)) and
                    (not FG.IsNumber(level) or not item.level or item.level<=level) then
                    local loc=self:LocateDungeonByKey(key)
                    if loc then
                        local row=toResult(self,loc)
                        local name=de(self,item.de,item.en)
                        row.name=name.." — "..de(self,loc.de,loc.en)
                        row.detail=de(self,"Boss: ","Boss: ")..de(self,item.bossDe,item.bossEn)..
                            " · "..de(self,loc.zoneDe,loc.zoneEn)..
                            de(self," · Annäherung"," · approach")
                        row.key=loc.id..":"..item.en
                        row.route.name=name.." — "..de(self,loc.de,loc.en)
                        add(row)
                    end
                end
            end
        end
    end
    -- If the question names a curated item, offer its known dungeon approach
    -- as an explicitly selectable result. No claimed route to the boss.
    for key,d in pairs(self.LootData or {}) do
        for _,item in ipairs(d.items or {}) do
            local nameDe,nameEn=FG.Normalize(item.de),FG.Normalize(item.en)
            local plain=FG.Normalize(query)
            if #nameDe>=5 and (contains(plain,nameDe) or contains(plain,nameEn)) then
                local loc=self:LocateDungeonByKey(key)
                if loc then
                    local row=toResult(self,loc)
                    local name=de(self,item.de,item.en)
                    row.name=name.." — "..de(self,loc.de,loc.en)
                    row.detail=de(self,"Boss: ","Boss: ")..de(self,item.bossDe,item.bossEn)..
                        " · "..de(self,loc.zoneDe,loc.zoneEn)..de(self," · Annäherung"," · approach")
                    row.key=loc.id..":"..item.en
                    row.route.name=name.." — "..de(self,loc.de,loc.en)
                    add(row)
                end
            end
        end
    end
    local named=false
    for _,loc in ipairs(self.LocationPins) do
        if locMatch(query,loc) then add(toResult(self,loc)); named=true end
    end
    if not settlementQualifier then
        for _,loc in ipairs(self.SettlementPins or {}) do
            if locMatch(query,loc) then add(toResult(self,loc));named=true end
        end
        if searchIntent then
            for _,row in ipairs(self:ClientMapResults(query)) do add(row);named=true end
        end
    end
    if not named and dungeonQuery and not gearQuery then
        local lvl=tonumber(q:match("level%s*(%d+)") or q:match("stufe%s*(%d+)"))
        if not lvl then lvl=FG.Safe(UnitLevel,"player") end
        for _,loc in ipairs(self.LocationPins) do
            if not FG.IsNumber(lvl) or (lvl>=loc.min and lvl<=loc.max) then add(toResult(self,loc)) end
        end
    end
    -- If no named dungeon was found, ask optional QuestieDB for people/trainers.
    local trainerQuery=any(q,"lehrer","trainer","ausbilder","npc")
        or FG.Canonical(query):find("fgtermtrainer",1,true)~=nil
    local npcNameQuery=searchIntent and not named and not dungeonQuery and not gearQuery
    if trainerQuery or npcNameQuery then
        local npcResults=self:QuestieNpcResults(query,12)
        for _,r in ipairs(npcResults) do add(r) end
    end
    if collectOnly then return locations end
    if #locations==0 then return false end
    if self.ShowSearchResults then self:ShowSearchResults(locations,query) end
    self:Say(de(self,"Suchtreffer: ","Location results: ")..#locations..de(self," · anklicken, prüfen und dann Wegführung starten."," · click, review and start guidance."))
    return true
end
