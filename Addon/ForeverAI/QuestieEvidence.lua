-- Incremental, read-only index of the installed QuestieDB's localized quest names.
local _, FG = ...
local function read(fn,id)
    if type(fn)~="function" then return nil end
    return FG.Safe(fn,id)
end
local genericItemNames={waffe=true,waffen=true,weapon=true,weapons=true,schwert=true,schwerter=true,sword=true,swords=true,
    gegenstand=true,gegenstaende=true,item=true,items=true,ruestung=true,armor=true,armour=true,shield=true,schild=true,
    dagger=true,dolch=true,staff=true,hammer=true}

function FG:InitQuestieEvidence()
    local db=_G.LibQuestieDB
    local quest=db and db.Quest
    if not quest or type(quest.GetAllIds)~="function" or type(quest.name)~="function" then return end
    local ids=read(quest.GetAllIds)
    if type(ids)~="table" then return end
    self.questieNames={}
    local index=1
    local frame=CreateFrame("Frame")
    frame:SetScript("OnUpdate",function(f)
        for _=1,100 do
            local id=ids[index]
            if not id then f:SetScript("OnUpdate",nil); self.questieIndexReady=true; return end
            local name=read(quest.name,id)
            if type(name)=="string" and not FG.IsSecret(name) then
                self.questieNames[#self.questieNames+1]={id=id,name=name,normalized=FG.Normalize(name)}
            end
            index=index+1
        end
    end)
    self.questieIndexFrame=frame
    local npc=db.Npc
    local npcIds=npc and read(npc.GetAllIds)
    if type(npcIds)=="table" and type(npc.name)=="function" then
        self.questieNpcIndex={}
        self.questieNpcNames={}
        local n=1
        local npcFrame=CreateFrame("Frame")
        npcFrame:SetScript("OnUpdate",function(f)
            for _=1,100 do
                local id=npcIds[n]
                if not id then f:SetScript("OnUpdate",nil); self.questieNpcIndexReady=true; return end
                local name=read(npc.name,id)
                local sub=read(npc.subName,id)
                if type(name)=="string" and not FG.IsSecret(name) then
                    local subtitle=type(sub)=="string" and not FG.IsSecret(sub) and sub or ""
                    local entry={id=id,name=name,normalized=FG.Normalize(name),sub=subtitle,canonicalName=FG.Canonical(name),canonicalSub=FG.Canonical(subtitle)}
                    self.questieNpcIndex[#self.questieNpcIndex+1]=entry
                    if #entry.normalized>=3 and #entry.normalized<=120 then
                        local bucket=self.questieNpcNames[entry.normalized] or {}
                        if #bucket<12 then bucket[#bucket+1]=entry end
                        self.questieNpcNames[entry.normalized]=bucket
                    end
                end
                n=n+1
            end
        end)
        self.questieNpcIndexFrame=npcFrame
    end
    local item=db.Item
    local itemIds=item and read(item.GetAllIds)
    if type(itemIds)=="table" and type(item.name)=="function" then
        self.questieItemNames={}
        local n=1
        local itemFrame=CreateFrame("Frame")
        itemFrame:SetScript("OnUpdate",function(f)
            for _=1,100 do
                local id=itemIds[n]
                if not id then f:SetScript("OnUpdate",nil);self.questieItemIndexReady=true;return end
                local name=read(item.name,id)
                if type(name)=="string" and not FG.IsSecret(name) then
                    local key=FG.Normalize(name)
                    if #key>=5 and #key<=120 and not genericItemNames[key] then
                        local bucket=self.questieItemNames[key] or {}
                        if #bucket<8 then bucket[#bucket+1]={id=id,name=FG.Clean(name,120)} end
                        self.questieItemNames[key]=bucket
                    end
                end
                n=n+1
            end
        end)
        self.questieItemIndexFrame=itemFrame
    end
end

-- Lookup exact item names through a bounded set of question phrases, rather
-- than scanning every database entry during a chat submission.
function FG:QuestieIndexedNames(index,question)
    if type(index)~="table" then return {} end
    local words={}
    for word in FG.Normalize(question or ""):gmatch("%S+") do if #words<24 then words[#words+1]=word end end
    local matches,best={},0
    for first=1,#words do
        local phrase=""
        for last=first,math.min(#words,first+9) do
            phrase=phrase=="" and words[last] or phrase.." "..words[last]
            local bucket=index[phrase]
            if bucket then
                if #phrase>best then matches={};best=#phrase end
                if #phrase==best then for _,entry in ipairs(bucket) do if #matches<8 then matches[#matches+1]=entry end end end
            end
        end
    end
    return matches
end

function FG:QuestieItemMatches(question)
    return self:QuestieIndexedNames(self.questieItemNames,question)
end

function FG:QuestieItemResults(question)
    local db=_G.LibQuestieDB
    local items=db and db.Item
    if not items then return {},{} end
    local matches=self:QuestieItemMatches(question)
    local rows={}
    for _,item in ipairs(matches) do
        for _,pair in ipairs({{"npcDrops","Npc"},{"objectDrops","Object"},{"vendors","Npc"}}) do
            local ids=read(items[pair[1]],item.id)
            if type(ids)=="table" then
                for i,id in ipairs(ids) do
                    if i>10 or #rows>=16 then break end
                    local entity=db[pair[2]]
                    local name=entity and read(entity.name,id)
                    local spawns=entity and read(entity.spawns,id)
                    if type(name)=="string" and not FG.IsSecret(name) and type(spawns)=="table" then
                        local best,player=nil,FG.Safe(C_Map and C_Map.GetBestMapForUnit,"player")
                        for area,points in pairs(spawns) do
                            local map=self.KnownAreaMap and self.KnownAreaMap[area]
                            if map and FG.Safe(C_Map and C_Map.GetMapInfo,map) and type(points)=="table" then
                                for _,xy in ipairs(points) do
                                    if type(xy)=="table" and FG.IsNumber(xy[1]) and FG.IsNumber(xy[2]) and xy[1]>=0 and xy[1]<=100 and xy[2]>=0 and xy[2]<=100 then
                                        local score=map==player and 1 or 0
                                        if not best or score>best.score then best={mapID=map,x=xy[1]/100,y=xy[2]/100,score=score} end
                                    end
                                end
                            end
                        end
                        if best then
                            local relation=pair[1]=="vendors" and (self.locale=="deDE" and "Händler" or "Vendor") or (self.locale=="deDE" and "Möglicher Fund" or "Possible drop")
                            local label=FG.Clean(name,80)
                            local detail=relation.." · QuestieDB · "..item.name.." · "..(self.locale=="deDE" and "ungeprüft" or "unverified")
                            rows[#rows+1]={key="item:"..item.id..":"..pair[1]..":"..id,name=label,detail=detail,source="QuestieDB",
                                route={name=item.name.." — "..label,kind="waypoint",points={{mapID=best.mapID,x=best.x,y=best.y,label=label,note=detail}}}}
                        end
                    end
                end
            end
        end
    end
    return matches,rows
end

function FG:AnswerQuestieItems(question)
    local matches=self:QuestieItemMatches(question)
    if #matches==0 then return false end
    local db=_G.LibQuestieDB
    for _,item in ipairs(matches) do
        local level=db and db.Item and read(db.Item.itemLevel,item.id)
        local min=db and db.Item and read(db.Item.requiredLevel,item.id)
        local details="QuestieDB #"..item.id
        if FG.IsNumber(level) then details=details.." · Item Level "..level end
        if FG.IsNumber(min) and min>0 then details=details.." · "..(self.locale=="deDE" and "benötigt Level " or "requires level ")..min end
        self:Say(item.name.." · "..details)
    end
    local _,rows=self:QuestieItemResults(question)
    if #rows>0 then
        self:Say(self.locale=="deDE" and "Mögliche Fundorte/Händler aus QuestieDB (Community-Daten, ungeprüft):" or "Possible drops/vendors from QuestieDB (unverified community data):")
        for i=1,math.min(#rows,6) do self:Say(rows[i].name.." · "..rows[i].detail) end
        if self.AddChatTargets then self:AddChatTargets(rows) end
    else
        self:Say(self.locale=="deDE" and "Keine verwendbare Fundortposition in QuestieDB gefunden." or "No usable location was found in QuestieDB.")
    end
    return true
end

-- Data provided by the client and explicitly installed, separately sourced
-- databases. Only records relevant to the current question are returned.
function FG:GameEvidence(question)
    local query=FG.Normalize(question or "")
    if #query<4 then return "" end
    local parts={}
    local function add(s) if type(s)=="string" and s~="" then parts[#parts+1]=s end end
    local questIntent=query:find("quest",1,true) or query:find("aufgabe",1,true) or query:find("mission",1,true)
    if type(self.GetQuests)=="function" then
        local quests=FG.Safe(self.GetQuests,self)
        if type(quests)=="table" then
            local matched={}
            for _,q in ipairs(quests) do
                local title=type(q.title)=="string" and FG.Normalize(q.title) or ""
                if #title>=4 and query:find(title,1,true) then matched[#matched+1]=q end
            end
            if #matched==0 and questIntent and #quests==1 then matched[1]=quests[1] end
            if #matched==0 and questIntent then
                local names={}
                for i=1,math.min(#quests,3) do names[#names+1]=FG.Clean(quests[i].title,70).." (#"..tostring(quests[i].id)..")" end
                if #names>0 then add("WoW client active quests (partial): "..table.concat(names,", ")) end
            end
            for i=1,math.min(#matched,2) do
                local q=matched[i]
                local row="WoW client active quest #"..tostring(q.id)..": "..FG.Clean(q.title,100)
                local objectives=FG.Safe(C_QuestLog and C_QuestLog.GetQuestObjectives,q.id)
                if type(objectives)=="table" and not FG.IsSecret(objectives) then
                    for j=1,math.min(#objectives,2) do
                        local objective=objectives[j]
                        if type(objective)=="table" and type(objective.text)=="string" and not FG.IsSecret(objective.text) then
                            row=row.."; "..FG.Clean(objective.text,100)
                            if objective.finished==true then row=row.." (complete)" end
                        end
                    end
                end
                add(row)
            end
        end
    end
    for _,entry in ipairs(self.questieNpcIndex or {}) do
        local name=entry.normalized or FG.Normalize(entry.name)
        if #name>=4 and query:find(name,1,true) then
            local row="QuestieDB community NPC #"..tostring(entry.id)..": "..FG.Clean(entry.name,90)
            if entry.sub and entry.sub~="" then row=row.." ("..FG.Clean(entry.sub,50)..")" end
            local npc=_G.LibQuestieDB and _G.LibQuestieDB.Npc
            local spawns=npc and read(npc.spawns,entry.id)
            if type(spawns)=="table" then
                for area,locations in pairs(spawns) do
                    local map=self.KnownAreaMap and self.KnownAreaMap[area]
                    local point=type(locations)=="table" and locations[1]
                    if map and type(point)=="table" and FG.IsNumber(point[1]) and FG.IsNumber(point[2]) and point[1]>=0 and point[1]<=100 and point[2]>=0 and point[2]<=100 then
                        row=row..string.format("; community spawn map=%d x=%.1f y=%.1f (unverified)",map,point[1],point[2]);break
                    end
                end
            end
            add(row);break
        end
    end
    local data=self.SyncData
    if type(data)=="table" and data.schema==1 then
        for _,d in ipairs(data.dungeons or {}) do
            local name=type(d.name)=="string" and FG.Normalize(d.name) or ""
            local matching=#name>=4 and query:find(name,1,true)
            local pin=d.pinKey and self.LocateDungeonByKey and self:LocateDungeonByKey(d.pinKey)
            if not matching and pin then
                local de=FG.Normalize(pin.de or "");local en=FG.Normalize(pin.en or "")
                matching=(#de>=4 and query:find(de,1,true)) or (#en>=4 and query:find(en,1,true))
            end
            if matching then
                local row="Forever Companion community dungeon: "..FG.Clean(d.name,90)
                if type(d.zone)=="string" and d.zone~="" then row=row.."; zone="..FG.Clean(d.zone,60) end
                if type(d.entrance)=="string" and d.entrance~="" then row=row.."; entrance="..FG.Clean(d.entrance,100) end
                if FG.IsNumber(d.min) and FG.IsNumber(d.max) then row=row.."; recommended levels="..d.min.."-"..d.max end
                add(row.." (community data, not live verified)");break
            end
        end
        for _,item in ipairs(data.items or {}) do
            local name=type(item.name)=="string" and FG.Normalize(item.name) or ""
            if #name>=5 and query:find(name,1,true) then
                local row="Forever Companion community item: "..FG.Clean(item.name,90)
                if FG.IsNumber(item.id) then row=row.." #"..item.id end
                if FG.IsNumber(item.level) then row=row.."; required level="..item.level end
                if FG.IsNumber(item.itemLevel) then row=row.."; item level="..item.itemLevel end
                add(row.." (community data, not live verified)");break
            end
        end
    end
    return FG.Clean(table.concat(parts," | "),650)
end

function FG:QuestieEvidence(question)
    local db=_G.LibQuestieDB
    local q=db and db.Quest
    if not q or not self.questieNames then return "" end
    local query=FG.Normalize(question or "")
    local rows={}
    for _,entry in ipairs(self.questieNames) do
        if #entry.normalized>=4 and query:find(entry.normalized,1,true) then
            local parts={"QuestieDB quest #"..entry.id..": "..FG.Clean(entry.name,100)}
            local level=read(q.questLevel,entry.id)
            local required=read(q.requiredLevel,entry.id)
            if type(level)=="number" then parts[#parts+1]="level="..level end
            if type(required)=="number" then parts[#parts+1]="minLevel="..required end
            local objectives=read(q.objectivesText,entry.id)
            if type(objectives)=="table" then
                for _,line in ipairs(objectives) do if type(line)=="string" then parts[#parts+1]=FG.Clean(line,140) end end
            end
            for _,field in ipairs({"preQuestSingle","preQuestGroup"}) do
                local value=read(q[field],entry.id)
                if type(value)=="table" then
                    local ids={}
                    local function collect(t,depth)
                        if depth>2 then return end
                        for _,v in ipairs(t) do
                            if type(v)=="number" and v>0 and #ids<8 then ids[#ids+1]=tostring(v)
                            elseif type(v)=="table" then collect(v,depth+1) end
                        end
                    end
                    collect(value,0)
                    if #ids>0 then parts[#parts+1]=field.." IDs="..table.concat(ids,",") end
                end
            end
            for _,field in ipairs({"startedBy","finishedBy","objectives"}) do
                local groups=read(q[field],entry.id)
                if type(groups)=="table" then
                    for index,kind in ipairs({"Npc","Object","Item"}) do
                        local group=groups[index]
                        local entity=db[kind]
                        if type(group)=="table" then
                            for j,value in ipairs(group) do
                                if j>2 then break end
                                local id=type(value)=="table" and value[1] or value
                                if type(id)=="number" and id>0 then
                                    local name=entity and read(entity.name,id)
                                    local text=field.." "..kind.." #"..id
                                    if type(name)=="string" and not FG.IsSecret(name) then text=text.." "..FG.Clean(name,70) end
                                    parts[#parts+1]=text
                                end
                            end
                        end
                    end
                end
            end
            rows[#rows+1]=table.concat(parts,"; ")
            if #rows>=2 then break end
        end
    end
    return FG.Clean(table.concat(rows,"\n"),550)
end

function FG:QuestieQuestResults(question)
    local db=_G.LibQuestieDB
    local quest=db and db.Quest
    if not quest or not self.questieNames then return {} end
    local query=FG.Normalize(question or "")
    local rows={}
    for _,entry in ipairs(self.questieNames) do
        if #entry.normalized>=4 and (query:find(entry.normalized,1,true) or entry.normalized==query) then
            local level=read(quest.questLevel,entry.id)
            local detail="QuestieDB #"..entry.id..(type(level)=="number" and " · Level "..level or "")
            local objectives=read(quest.objectivesText,entry.id)
            if type(objectives)=="table" and type(objectives[1])=="string" then detail=detail.." · "..FG.Clean(objectives[1],100) end
            local route=self.QuestRoute and self:QuestRoute(entry.id)
            if not route and self.QuestieObjectiveResults then
                local starters=self:QuestieObjectiveResults(entry.id,entry.name,"starter")
                if #starters==1 then route=starters[1].route;detail=detail.." · "..(self.locale=="deDE" and "möglicher Questgeber" or "possible quest giver") end
            end
            rows[#rows+1]={key="quest:"..entry.id,name=entry.name,detail=detail,source="QuestieDB",route=route}
            if #rows>=8 then break end
        end
    end
    return rows
end

-- Objective and item-drop positions are community spawn points, not proof of
-- the NPC's current position or an accessible route. Never guess AreaIDs.
function FG:QuestieObjectiveResults(id,title,finisher)
    local db=_G.LibQuestieDB
    local getter=db and db.Quest and (finisher=="starter" and db.Quest.startedBy or finisher and db.Quest.finishedBy or db.Quest.objectives)
    local groups=read(getter,id)
    if type(groups)~="table" or not self.KnownAreaMap then return {} end
    local rows,seen={},{}
    local player=FG.Safe(C_Map and C_Map.GetBestMapForUnit,"player")
    local function add(kind,entityID,objectiveName)
        local entity=db[kind]
        local spawns=entity and read(entity.spawns,entityID)
        local name=entity and read(entity.name,entityID)
        if type(spawns)~="table" then return end
        if type(name)~="string" or FG.IsSecret(name) then name=kind.." #"..entityID end
        local best
        for area,points in pairs(spawns) do
            local mapID=self.KnownAreaMap[area]
            if mapID and FG.Safe(C_Map and C_Map.GetMapInfo,mapID) and type(points)=="table" then
                for _,xy in ipairs(points) do
                    if type(xy)=="table" and FG.IsNumber(xy[1]) and FG.IsNumber(xy[2]) and xy[1]>=0 and xy[1]<=100 and xy[2]>=0 and xy[2]<=100 then
                        local score=mapID==player and 1 or 0
                        if not best or score>best.score then best={mapID=mapID,x=xy[1]/100,y=xy[2]/100,score=score} end
                    end
                end
            end
        end
        local key=kind..":"..entityID
        if best and not seen[key] and #rows<12 then
            seen[key]=true
            local label=FG.Clean(name,80)
            local detail=finisher=="starter" and (self.locale=="deDE" and "Questgeber · QuestieDB-Standort, ungeprüft" or "Quest giver · QuestieDB spawn, unverified") or finisher and (self.locale=="deDE" and "Questabgabe · QuestieDB-Standort, ungeprüft" or "Quest turn-in · QuestieDB spawn, unverified") or (self.locale=="deDE" and "Questziel · QuestieDB-Standort, ungeprüft" or "Quest objective · QuestieDB spawn, unverified")
            if objectiveName then detail=detail.." · "..FG.Clean(objectiveName,60) end
            rows[#rows+1]={name=label,detail=detail,source="QuestieDB",route={name=title.." — "..label,kind="waypoint",points={{mapID=best.mapID,x=best.x,y=best.y,label=label,note=detail}}}}
        end
    end
    for index,kind in ipairs({"Npc","Object"}) do
        for _,entry in ipairs(type(groups[index])=="table" and groups[index] or {}) do
            local entityID=type(entry)=="table" and entry[1] or entry
            if type(entityID)=="number" and entityID>0 then add(kind,entityID) end
        end
    end
    local items=db.Item
    for _,entry in ipairs(not finisher and type(groups[3])=="table" and groups[3] or {}) do
        local itemID=type(entry)=="table" and entry[1] or entry
        if items and type(itemID)=="number" and itemID>0 then
            local itemName=read(items.name,itemID)
            for _,pair in ipairs({{"npcDrops","Npc"},{"objectDrops","Object"}}) do
                local drops=read(items[pair[1]],itemID)
                if type(drops)=="table" then for _,entityID in ipairs(drops) do if type(entityID)=="number" and entityID>0 then add(pair[2],entityID,itemName) end end end
            end
        end
    end
    return rows
end

function FG:QuestieFinisherResults(id,title)
    return self:QuestieObjectiveResults(id,title,true)
end
