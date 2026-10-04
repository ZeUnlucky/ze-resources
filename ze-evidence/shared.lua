Shared = {}

-- Fingerprints and DNA are derived from the citizen id with a keyed 64-bit hash (FNV-1a, then splitmix64 to
-- spread the bits), so the same person always gets the same value but it cannot be read back into the id.
-- Integer wrap-around and the ~ / >> operators behave the same in Lua 5.3 and 5.4.
local function hash64(text)
    local h = 0xcbf29ce484222325
    for i = 1, #text do
        h = (h ~ text:byte(i)) * 0x100000001b3
    end
    return h
end

local function mix64(z)
    z = (z ~ (z >> 30)) * 0xbf58476d1ce4e5b9
    z = (z ~ (z >> 27)) * 0x94d049bb133111eb
    return z ~ (z >> 31)
end

-- Builds `groups` groups of `size` characters from `alphabet`, joined with dashes.
local function derive(kind, citizenId, alphabet, groups, size)
    local secret = tostring(Config and Config.EvidenceSecret or 'ze-evidence')
    local state = hash64(secret .. ':' .. kind .. ':' .. tostring(citizenId):upper())
    local parts = {}
    for g = 1, groups do
        local chars = {}
        for c = 1, size do
            state = state + 0x9e3779b97f4a7c15
            local pick = (mix64(state) >> 33) % #alphabet + 1
            chars[c] = alphabet:sub(pick, pick)
        end
        parts[g] = table.concat(chars)
    end
    return table.concat(parts, '-')
end

-- e.g. K7QM-2XHD-9TPA (no 0/O/1/I so it is easy to read out over the radio)
Shared.ConvertCitizenIdToFingerprint = function(citizenId)
    return derive('fingerprint', citizenId, 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789', 3, 4)
end

-- e.g. GATTAC-CGTAAG-TCAGCT-AACGTG-CTAGGA (30 bases; fits the ze_dnas.dnaString column)
Shared.ConvertCitizenIdToDNA = function(citizenId)
    return derive('dna', citizenId, 'ACGT', 5, 6)
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


Shared.ArmsWithoutGloves = {
    male = {
        [0] = true,
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true,
        [7] = true,
        [8] = true,
        [9] = true,
        [10] = true,
        [11] = true,
        [12] = true,
        [13] = true,
        [14] = true,
        [15] = true,
        [18] = true,
        [26] = true,
        [52] = true,
        [53] = true,
        [54] = true,
        [55] = true,
        [56] = true,
        [57] = true,
        [58] = true,
        [59] = true,
        [60] = true,
        [61] = true,
        [62] = true,
        [112] = true,
        [113] = true,
        [114] = true,
        [118] = true,
        [125] = true,
        [132] = true
    },

    female = {
        [0] = true,
        [1] = true,
        [2] = true,
        [3] = true,
        [4] = true,
        [5] = true,
        [6] = true,
        [7] = true,
        [8] = true,
        [9] = true,
        [10] = true,
        [11] = true,
        [12] = true,
        [13] = true,
        [14] = true,
        [15] = true,
        [19] = true,
        [59] = true,
        [60] = true,
        [61] = true,
        [62] = true,
        [63] = true,
        [64] = true,
        [65] = true,
        [66] = true,
        [67] = true,
        [68] = true,
        [69] = true,
        [70] = true,
        [71] = true,
        [129] = true,
        [130] = true,
        [131] = true,
        [135] = true,
        [142] = true,
        [149] = true,
        [153] = true,
        [157] = true,
        [161] = true,
        [165] = true
    },
}

Shared.GetUniqueValuesFromTable = function(t)
    local unique = {}
    local result = {}
    if t == nil then return result end
    for _, value in ipairs(t) do
        if not unique[value] then
            unique[value] = true
            table.insert(result, value)
        end
    end
    
    return result
end