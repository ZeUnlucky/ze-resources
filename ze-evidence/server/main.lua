local QBCore = exports['qb-core']:GetCoreObject()

Casings = {}
Splatters = {}

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
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items["pdfingerprinttape"], 'remove')
            local info = {}
            if fingerprint then info.fingerprint = fingerprint end
            exports['qb-inventory']:AddItem(source, "usedfingerprinttape", 1, false, info, 'ze-evidence:useTape')
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
        exports['qb-inventory']:AddItem(source, "blood_vial", 1, false, info, 'ze-evidence:takeDNA')
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
                    TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items["pdfingerprinttape"], 'remove')
                    local info = {}
                    info.fingerprint = prints
                    exports['qb-inventory']:AddItem(source, "usedfingerprinttape", 1, false, info, 'ze-evidence:useTape')
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
    TriggerClientEvent("ze-evidence:RemoveCasingMenu", -1, casing)
    local info = {}
    info.ammoType = Casings[casing].ammoType
    info.serialNumber = Casings[casing].serialNumber
    exports['qb-inventory']:AddItem(source, "casing", 1, false, info, 'ze-evidence:gatherCasing')
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
        exports['qb-inventory']:AddItem(source, "blood_vial", 1, false, info, 'ze-evidence:collectSplatter')
    end
    Splatters[splatter] = nil
    TriggerClientEvent("ze-evidence:DeleteSplatterMenu", -1, splatter)
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    TriggerClientEvent("ze-evidence:PlayerJoined", Player.PlayerData.source, Splatters, Casings)
end)

RegisterServerEvent("ze-evidence:SubmitCasing", function(label)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player and label then
        local firstnumber, lastnumber = 0, 0
        while Player.Functions.HasItem("casing") do
            local item = Player.Functions.GetItemByName("casing")
            if item.info and item.info.serialNumber then
                exports['oxmysql']:insert('INSERT INTO `ze_casings` (label, gunSerial, submittedBy) VALUES (?, ?, ?)', {label, item.info.serialNumber, Player.Functions.GetName()}, function(id)
                    if id then
                        lastnumber = id
                        if firstnumber == 0 then firstnumber = id end
                    end
                end)
                Player.Functions.RemoveItem("casing", 1, item.slot)
            end
        end
        QBCore.Functions.Notify(source, "Your casing IDs are " .. firstnumber .. "-" .. lastnumber, "success", 15000)
    end
end)

RegisterServerEvent("ze-evidence:server:GetCasingByID", function(cid)
    local src = source
    if cid then
        exports['oxmysql']:query('select * from `ze_casings` where `id` = ?', {cid}, function(response)
            if response then
                TriggerClientEvent("ze-evidence:client:GetCasingByID", src, response)
            else
                QBCore.Functions.Notify(src, "Couldn't find casing.", "error", 10000)
            end
        end)
    end
end)

RegisterServerEvent("ze-evidence:server:GetCasingsBySerial", function(gserial)
    local src = source
    if gserial then
        exports['oxmysql']:query('select * from `ze_casings` where `gunSerial` = ?', {gserial}, function(response)
            if response then
                TriggerClientEvent("ze-evidence:client:GetCasingsBySerial", src, response)
            else
                QBCore.Functions.Notify(src, "Couldn't find casings.", "error", 10000)
            end
        end)
    end
end)

RegisterServerEvent("ze-evidence:SubmitDNA", function(label)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player and label then
        local firstnumber, lastnumber = 0
        while Player.Functions.HasItem("blood_vial") do
            local item = Player.Functions.GetItemByName("blood_vial")
            if item.info and item.info.DNA then
                exports['oxmysql']:insert('INSERT INTO `ze_dnas` (label, dnaString, submittedBy) VALUES (?, ?, ?)', {label, item.info.DNA, Player.Functions.GetName()}, function(id)
                    if firstnumber == 0 then firstnumber = id end
                    lastnumber = id
                end)
                Player.Functions.RemoveItem("blood_vial", 1, item.slot)
            end
        end
        QBCore.Functions.Notify(src, "Your DNA IDs are " .. firstnumber .. "-" .. lastnumber, "success", 10000)
    end
end)


RegisterServerEvent("ze-evidence:server:GetDNAByID", function(did)
    local src = source
    if did then
        exports['oxmysql']:query('select * from `ze_dnas` where `id` = ?', {did}, function(response)
            if response then
                TriggerClientEvent("ze-evidence:client:GetDNAByID", src, response)
            else
                QBCore.Functions.Notify(src, "Couldn't find DNA.", "error", 5000)
            end
        end)
    end
end)

RegisterServerEvent("ze-evidence:server:GetDNABySerial", function(dserial)
    local src = source
    if dserial then
        exports['oxmysql']:query('select * from `ze_dnas` where `dnaString` = ?', {dserial}, function(response)
            if response then
                TriggerClientEvent("ze-evidence:client:GetDNABySerial", src, response)
            else
                QBCore.Functions.Notify(src, "Couldn't find DNA.", "error", 10000)
            end
        end)
    end
end)