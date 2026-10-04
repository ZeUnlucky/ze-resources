local QBCore = exports['qb-core']:GetCoreObject()

Casings = {}
Splatters = {}

-- Shows the "+1 Item" / "-1 Item" notice. ze-inventory (like qb-inventory) listens for this event;
-- AddItem and RemoveItem never send it themselves.
function ShowItemBox(src, itemName, kind, amount)
    local itemData = QBCore.Shared.Items[itemName]
    if not itemData then return end
    TriggerClientEvent('qb-inventory:client:ItemBox', src, itemData, kind, amount or 1)
end

-- Adds an item and, only if it really went into the inventory, shows the notice.
local function GiveEvidenceItem(src, itemName, info, reason)
    if exports['qb-inventory']:AddItem(src, itemName, 1, false, info, reason) then
        ShowItemBox(src, itemName, 'add')
        return true
    end
    QBCore.Functions.Notify(src, "You can't carry that.", 'error', 5000)
    return false
end

local function GetGunPrints(serial)
    local raw = GetResourceKvpString("ze-evidence:prints:" .. serial)
    return raw and json.decode(raw) or {}
end

local function SaveGunPrints(serial, prints)
    if #prints == 0 then
        DeleteResourceKvp("ze-evidence:prints:" .. serial)
    else
        SetResourceKvp("ze-evidence:prints:" .. serial, json.encode(prints))
    end
end

local function AddGunPrint(serial, fingerprint)
    local prints = GetGunPrints(serial)
    for _, existing in ipairs(prints) do
        if existing == fingerprint then return end
    end
    table.insert(prints, fingerprint)
    SaveGunPrints(serial, prints)
end

RegisterServerEvent("ze-evidence:RegisterNewCasing")
AddEventHandler("ze-evidence:RegisterNewCasing", function(casingEntity, weapon, pos, isGloved)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local serieNumber = nil
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            if type(weaponItem.info) == 'table' then
                serieNumber = weaponItem.info.serie
                if serieNumber and not isGloved then
                    AddGunPrint(serieNumber, Shared.ConvertCitizenIdToFingerprint(Player.PlayerData.citizenid))
                end
            end
        end
    end
    Player.PlayerData.metadata["gunpowder"] = true
   
    Casings[casingEntity] = {ammoType = weaponInfo.ammotype, serialNumber = serieNumber, position = pos, id = casingEntity}
    TriggerClientEvent("ze-evidence:RegisterNewCasingClient", -1,  casingEntity, serieNumber)
end)

RegisterServerEvent("ze-evidence:GetFingerprintFromPlayer", function(pID)
    local Player = QBCore.Functions.GetPlayer(source)
    local Target = QBCore.Functions.GetPlayer(pID)
    if Target then
        if Player.Functions.HasItem("pdfingerprinttape", 1) then
            local fingerprint = Shared.ConvertCitizenIdToFingerprint(Target.PlayerData.citizenid)
            Player.Functions.RemoveItem("pdfingerprinttape", 1)
            ShowItemBox(source, "pdfingerprinttape", 'remove')
            local info = {}
            if fingerprint then info.fingerprint = fingerprint end
            GiveEvidenceItem(source, "usedfingerprinttape", info, 'ze-evidence:useTape')
        else
            QBCore.Functions.Notify(source, "You need fingerprint tape!", "error", 5000)
        end
    end
end)

RegisterServerEvent("ze-evidence:GetDNAFromPlayer", function(pID)
    local Player = QBCore.Functions.GetPlayer(source)
    local Target = QBCore.Functions.GetPlayer(pID)
    if Target then
        local dna = Shared.ConvertCitizenIdToDNA(Target.PlayerData.citizenid)
        local info = {}
        if dna then info.DNA = dna end
        GiveEvidenceItem(source, "blood_vial", info, 'ze-evidence:takeDNA')
    end
end)

QBCore.Commands.Add("checkfinger", "Checks held gun for a fingerprint", {}, false, function(source)
    local weapon = GetSelectedPedWeapon(GetPlayerPed(source))
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local Player = QBCore.Functions.GetPlayer(source)
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        if weaponItem then
            local serial = type(weaponItem.info) == 'table' and weaponItem.info.serie
            local prints = serial and GetGunPrints(serial) or {}
            if #prints > 0 then
                if Player.Functions.HasItem("pdfingerprinttape", 1) then
                    Player.Functions.RemoveItem("pdfingerprinttape", 1)
                    ShowItemBox(source, "pdfingerprinttape", 'remove')
                    local info = {}
                    info.fingerprint = prints
                    GiveEvidenceItem(source, "usedfingerprinttape", info, 'ze-evidence:useTape')
                else
                    QBCore.Functions.Notify(source, "You need fingerprint tape!", "error", 5000)
                end
            else
                QBCore.Functions.Notify(source, "No prints found on gun!", "error", 5000)
            end
        end
    end
end)

QBCore.Commands.Add("wipefinger", "Wipes fingerprint from held gun", {}, false, function(source)
    local weapon = GetSelectedPedWeapon(GetPlayerPed(source))
    local weaponInfo = QBCore.Shared.Weapons[weapon]
    local Player = QBCore.Functions.GetPlayer(source)
    if weaponInfo then
        local weaponItem = Player.Functions.GetItemByName(weaponInfo['name'])
        local serial = weaponItem and type(weaponItem.info) == 'table' and weaponItem.info.serie
        if serial and #GetGunPrints(serial) > 0 then
            SaveGunPrints(serial, {})
            QBCore.Functions.Notify(source, "Cleaned fingerprint from gun", "success", 5000)
        end
    end
end)

RegisterServerEvent("ze-evidence:CollectCasing")
AddEventHandler("ze-evidence:CollectCasing", function(casing)   
    if not Casings[casing] then return end
    local info = {}
    info.ammoType = Casings[casing].ammoType
    info.serialNumber = Casings[casing].serialNumber
    -- A full inventory leaves the casing on the ground instead of destroying the evidence.
    if not GiveEvidenceItem(source, "casing", info, 'ze-evidence:gatherCasing') then return end
    TriggerClientEvent("ze-evidence:RemoveCasingMenu", -1, casing)
    Casings[casing] = nil
    DeleteEntity(NetworkGetEntityFromNetworkId(casing))
   
end)

RegisterServerEvent("ze-evidence:CreateBloodSplatter")
AddEventHandler("ze-evidence:CreateBloodSplatter", function(victim, splatterID, newPitch, currentRoll, currentYaw)
    FreezeEntityPosition(splatterID, true)
    local player = QBCore.Functions.GetPlayer(source)
    player = not player and "JL;" or player.PlayerData.citizenid
    local dna = Shared.ConvertCitizenIdToDNA(player)
    Splatters[splatterID] = {
        DNA = dna,
        position = GetEntityCoords(splatterID),
        id = splatterID
    }
    TriggerClientEvent("ze-evidence:CreateSplatterMenu", -1, splatterID, dna, newPitch, currentRoll, currentYaw)
end)

RegisterServerEvent("ze-evidence:CollectSplatter", function(splatter, DNA, collectedAndNotDestroyed)
    if collectedAndNotDestroyed then
        local info = {}
        info.DNA = DNA
        GiveEvidenceItem(source, "blood_vial", info, 'ze-evidence:collectSplatter')
    end
    Splatters[splatter] = nil
    TriggerClientEvent("ze-evidence:DeleteSplatterMenu", -1, splatter)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    TriggerClientEvent("ze-evidence:PlayerJoined", Player.PlayerData.source, Splatters, Casings)
end)
