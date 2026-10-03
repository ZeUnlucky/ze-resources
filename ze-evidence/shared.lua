Shared = {}

Shared.ConvertCitizenIdToFingerprint = function(citizenId)
    local fingerprint = ""
    for i = 1, #citizenId do
        local charActual = citizenId:sub(i,i)
        local charVal = string.byte(charActual) + 15
        if charVal > 58 and charVal < 64 then
            charVal = charVal + 15
        elseif charVal > 90 then
            charVal = charVal - 30
        end
        fingerprint = fingerprint .. string.char(charVal)
       
    end
    return fingerprint
end

Shared.ConvertCitizenIdToDNA = function(citizenId)
    local DNA = ""
    for i = 1, #citizenId do
        local charActual = citizenId:sub(i,i)
        local charVal = string.byte(charActual) + 4
        if charVal > 58 and charVal < 64 then
            charVal = charVal + 4
        elseif charVal > 90 then
            charVal = charVal - 8
        end
        DNA = DNA .. string.char(charVal)
    end
    return DNA
end

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

Shared.WeaponVelocity = {
    [GetHashKey("WEAPON_UNARMED")] = -1,
    [GetHashKey("WEAPON_KNIFE")] = 1,
    [GetHashKey("WEAPON_NIGHTSTICK")] = -1,
    [GetHashKey("WEAPON_HAMMER")] = -1,
    [GetHashKey("WEAPON_BAT")] = -1,
    [GetHashKey("WEAPON_GOLFCLUB")] = -1,
    [GetHashKey("WEAPON_CROWBAR")] = -1,
    [GetHashKey("WEAPON_BOTTLE")] = 1,
    [GetHashKey("WEAPON_DAGGER")] = 1,
    [GetHashKey("WEAPON_HATCHET")] = 1,
    [GetHashKey("WEAPON_KNUCKLE")] = -1,
    [GetHashKey("WEAPON_MACHETE")] = 1,
    [GetHashKey("WEAPON_FLASHLIGHT")] = -1,
    [GetHashKey("WEAPON_SWITCHBLADE")] = 1,
    [GetHashKey("WEAPON_POOLCUE")] = -1,
    [GetHashKey("WEAPON_WRENCH")] = -1,
    [GetHashKey("WEAPON_PISTOL")] = 2,
    [GetHashKey("WEAPON_COMBATPISTOL")] = 2,
    [GetHashKey("WEAPON_APPISTOL")] = 2,
    [GetHashKey("WEAPON_PISTOL50")] = 2,
    [GetHashKey("WEAPON_MICROSMG")] = 2,
    [GetHashKey("WEAPON_SMG")] = 2,
    [GetHashKey("WEAPON_ASSAULTSMG")] = 2,
    [GetHashKey("WEAPON_ASSAULTRIFLE")] = 2,
    [GetHashKey("WEAPON_CARBINERIFLE")] = 2,
    [GetHashKey("WEAPON_ADVANCEDRIFLE")] = 2,
    [GetHashKey("WEAPON_MG")] = 2,
    [GetHashKey("WEAPON_COMBATMG")] = 2,
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 2,
    [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 2,
    [GetHashKey("WEAPON_ASSAULTSHOTGUN")] = 2,
    [GetHashKey("WEAPON_BULLPUPSHOTGUN")] = 2,
    [GetHashKey("WEAPON_STUNGUN")] = -1,
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 2,
    [GetHashKey("WEAPON_HEAVYSNIPER")] = 2,
    [GetHashKey("WEAPON_GRENADELAUNCHER")] = 2,
    [GetHashKey("WEAPON_RPG")] = 2,
    [GetHashKey("WEAPON_MINIGUN")] = 2,
    [GetHashKey("WEAPON_GRENADE")] = 2,
    [GetHashKey("WEAPON_STICKYBOMB")] = 2,
    [GetHashKey("WEAPON_SMOKEGRENADE")] = -1,
    [GetHashKey("WEAPON_BZGAS")] = -1,
    [GetHashKey("WEAPON_MOLOTOV")] = -1,
    [GetHashKey("WEAPON_FIREEXTINGUISHER")] = -1,
    [GetHashKey("WEAPON_PETROLCAN")] = -1,
    [GetHashKey("WEAPON_FLARE")] = -1,
    [GetHashKey("WEAPON_BALL")] = -1,
    [GetHashKey("WEAPON_SNSPISTOL")] = 2,
    [GetHashKey("WEAPON_SPECIALCARBINE")] = 2,
    [GetHashKey("WEAPON_HEAVYPISTOL")] = 2,
    [GetHashKey("WEAPON_BULLPUPRIFLE")] = 2,
    [GetHashKey("WEAPON_HOMINGLAUNCHER")] = 2,
    [GetHashKey("WEAPON_PROXMINE")] = 2,
    [GetHashKey("WEAPON_SNOWBALL")] = -1,
    [GetHashKey("WEAPON_VINTAGEPISTOL")] = 2,
    [GetHashKey("WEAPON_FIREWORK")] = 2,
    [GetHashKey("WEAPON_MUSKET")] = 2,
    [GetHashKey("WEAPON_MARKSMANRIFLE")] = 2,
    [GetHashKey("WEAPON_HEAVYSHOTGUN")] = 2,
    [GetHashKey("WEAPON_GUSENBERG_MK2")] = 2,
    [GetHashKey("WEAPON_COMBATMG_MK2")] = 2,
    [GetHashKey("WEAPON_ASSAULTRIFLE_MK2")] = 2,
    [GetHashKey("WEAPON_CARBINERIFLE_MK2")] = 2,
    [GetHashKey("WEAPON_PISTOL_MK2")] = 2,
    [GetHashKey("WEAPON_SMG_MK2")] = 2,
    [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 2,
    [GetHashKey("WEAPON_REVOLVER")] = 2,
};
