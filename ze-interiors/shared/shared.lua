Shared = {}

Shared.Houses = {}

-- Shared.Buildings[id] = { name, entrance = vector4, floors = number of floors }. Filled by the server (server/buildings.lua).
Shared.Buildings = {}

Shared.DumpTable = function(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. Shared.DumpTable(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
end
