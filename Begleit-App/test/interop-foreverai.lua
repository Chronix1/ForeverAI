-- Cross-language conformance fixture: actual addon encoder with fixed session,
-- independent of simulated screenshots and external providers.
local FG={}
local f=assert(loadfile(arg[1].."/LiveBridge.lua"))
f("ForeverAI",FG)
local sentence="FAI1;65b2c04200abcdef;12;auto;auto;default;de;Welche%20Schwerter%20f%C3%BCr%20Krieger%3F;class%3DKrieger%3Blevel%3D25"
local cells=assert(FG.LiveEncodePacket(12,sentence))
print(table.concat(cells,","))
