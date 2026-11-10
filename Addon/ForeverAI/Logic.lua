-- ForeverAI: original source, MIT license. No network, tokens or executable imports.
local _, FG = ...
local T = FG.T
FG.VERSION = "0.9.0-alpha"
FG.INTERFACE = 16001
FG.MAX_POINTS = 100
FG.MAX_IMPORT = 24000
FG.messages = {}

function FG.IsSecret(v)
    return type(issecretvalue) == "function" and issecretvalue(v)
end

function FG.IsNumber(v)
    return not FG.IsSecret(v) and type(v) == "number" and v == v
        and v ~= math.huge and v ~= -math.huge
end

function FG.Trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function FG.Clean(s, maxBytes)
    s = tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    s = s:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", "")
    s = s:gsub("[|;%c]", " "):gsub("%s+", " ")
    s = FG.Trim(s)
    -- Avoid truncating a UTF-8 code point; use complete characters only.
    if #s > (maxBytes or 100) then
        local out, len = {}, 0
        for char in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            if len + #char > (maxBytes or 100) then break end
            out[#out + 1], len = char, len + #char
        end
        s = table.concat(out)
    end
    return s
end

function FG.Normalize(s)
    s = FG.Clean(s, 1024)
    local substitutions = { ["Ä"]="ae", ["Ö"]="oe", ["Ü"]="ue", ["ä"]="ae", ["ö"]="oe", ["ü"]="ue", ["ß"]="ss" }
    for from, to in pairs(substitutions) do s = s:gsub(from, to) end
    return FG.Trim(s:lower():gsub("[%p]", " "):gsub("%s+", " "))
end

function FG.Number(s)
    if type(s) == "string" then s = s:gsub(",", ".") end
    local n = tonumber(s)
    if FG.IsNumber(n) then return n end
end

function FG.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, a, b, c, d, e = pcall(fn, ...)
    if ok then return a, b, c, d, e end
end

function FG.XY(v)
    if not v or FG.IsSecret(v) then return nil end
    local x, y
    if type(v.GetXY) == "function" then
        x, y = FG.Safe(v.GetXY, v)
    else
        x, y = v.x, v.y
    end
    if FG.IsNumber(x) and FG.IsNumber(y) then return x, y end
end

function FG.ValidatePoint(p)
    if type(p) ~= "table" then return nil, T("Kein gültiger Wegpunkt.") end
    if not FG.IsNumber(p.mapID) or p.mapID < 1 or p.mapID % 1 ~= 0 or p.mapID > 1000000 then
        return nil, T("Die Karten-ID muss eine positive ganze Zahl sein.")
    end
    if not FG.IsNumber(p.x) or not FG.IsNumber(p.y) or p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1 then
        return nil, T("Koordinaten müssen zwischen 0 und 100 Prozent liegen.")
    end
    local clean={mapID=p.mapID,x=p.x,y=p.y,label=FG.Clean(p.label or T("Ziel"),100)}
    local kinds={waypoint=true,quest=true,trainer=true,dungeon=true,travel=true}
    if p.kind~=nil then
        if type(p.kind)~="string" or not kinds[p.kind] then return nil,T("Unbekannte Wegpunktart.") end
        clean.kind=p.kind
    end
    if type(p.note)=="string" then clean.note=FG.Clean(p.note,220) end
    clean.confirm=p.confirm==true or nil
    return clean
end

function FG.ParsePoint(text)
    local map, x, y, label = FG.Trim(text):match("^(%d+)%s+(%S+)%s+(%S+)%s*(.-)$")
    if not map then return nil, T("Format: ziel KARTEN-ID X Y Name (X/Y in Prozent).") end
    x, y = FG.Number(x), FG.Number(y)
    if not x or not y then return nil, T("X und Y müssen Zahlen sein.") end
    return FG.ValidatePoint({mapID=tonumber(map), x=x/100, y=y/100, label=(label ~= "" and label or T("Ziel"))})
end

function FG.ParseImport(text)
    if type(text) ~= "string" or #text > FG.MAX_IMPORT then
        return nil, T("Import zu groß (maximal ") .. FG.MAX_IMPORT .. T(" Zeichen/Bytes).")
    end
    local result, closed = nil, false
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = FG.Trim(line:gsub("\r", ""))
        if line ~= "" and line ~= "```" and line ~= "```text" then
            if closed then return nil, T("Nach END darf kein weiterer Inhalt stehen.") end
            if not result then
                local version,name = line:match("^FG([12]);(.-)$")
                if not name or name == "" then return nil, T("Der Block muss mit FG1;Routenname oder FG2;Routenname beginnen.") end
                if name:find(";", 1, true) then return nil, T("Kein Semikolon im Routennamen erlaubt.") end
                result = { name = FG.Clean(name, 100), points = {}, format=version }
                if result.name == "" then return nil, T("Der Routenname ist leer.") end
            elseif line == "END" then
                closed = true
            else
                local map,x,y,label,kind,note,confirm
                if result.format=="2" then
                    map,x,y,label,kind,note,confirm=line:match("^P;(%d+);([^;]+);([^;]+);([^;]+);([a-z]+);([^;]*);([01])$")
                else map,x,y,label=line:match("^P;(%d+);([^;]+);([^;]+);([^;]+)$") end
                if not map then return nil,T("Ungültige Wegpunktzeile für dieses Importformat.") end
                local p,err=FG.ParsePoint(map.." "..x.." "..y.." "..label)
                if not p then return nil,err end
                p.kind,p.note,p.confirm=kind,note,confirm=="1" or nil
                p,err=FG.ValidatePoint(p)
                if not p then return nil,err end
                result.points[#result.points+1] = p
                if #result.points > FG.MAX_POINTS then return nil, T("Maximal ") .. FG.MAX_POINTS .. T(" Punkte erlaubt.") end
            end
        end
    end
    if not result or not closed then return nil, T("Unvollständiger Block: FG1/FG2;Name und END werden benötigt.") end
    if #result.points == 0 then return nil, T("Der Block enthält keine Wegpunkte.") end
    return result
end

function FG.SerializeRoute(route)
    local extended=false
    for _,p in ipairs(route.points) do if p.kind or p.note or p.confirm then extended=true; break end end
    local lines={(extended and "FG2;" or "FG1;")..FG.Clean(route.name,100)}
    for _,p in ipairs(route.points) do
        local line=string.format("P;%d;%.4f;%.4f;%s",p.mapID,p.x*100,p.y*100,FG.Clean(p.label,100))
        if extended then line=line..";"..(p.kind or "waypoint")..";"..FG.Clean(p.note or "",220)..";"..(p.confirm and "1" or "0") end
        lines[#lines+1]=line
    end
    lines[#lines+1] = "END"
    return table.concat(lines, "\n")
end

-- WoW facing: 0 = north, pi/2 = west. All trigonometry here uses radians.
function FG.RelativeVector(east, north, facing)
    local right = east * math.cos(facing) + north * math.sin(facing)
    local forward = north * math.cos(facing) - east * math.sin(facing)
    local length = math.sqrt(right*right + forward*forward)
    if length < 0.001 then return 0, 1 end
    return right/length, forward/length
end

-- Bilingual matching is defined in Terms.lua; Normalize remains the stable storage key.

function FG:Say(text)
    text = tostring(text or "")
    self:AddChatMessage("local", text)
    -- Keep the private conversation out of the public chat UI while it is open.
    if DEFAULT_CHAT_FRAME and not self.chatSubmitting and (not self.window or not self.window:IsShown()) then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80c8ffForeverAI:|r " .. text)
    end
end
