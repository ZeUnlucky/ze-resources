QBCore.Commands.Add('giveitem', 'Give An Item (Admin Only)', { { name = 'id', help = 'Player ID' }, { name = 'item', help = 'Name of the item (not a label)' }, { name = 'amount', help = 'Amount of items' } }, false, function(source, args)
    local id = tonumber(args[1])
    local player = id and QBCore.Functions.GetPlayer(id)
    local amount = tonumber(args[3]) or 1
    local itemData = QBCore.Shared.Items[tostring(args[2]):lower()]
    if not player then
        QBCore.Functions.Notify(source, 'Player Is Not Online', 'error')
        return
    end
    if not itemData then
        QBCore.Functions.Notify(source, 'Item Does Not Exist', 'error')
        return
    end

    local charinfo = player.PlayerData.charinfo
    local info = {}
    if itemData['name'] == 'id_card' then
        info.citizenid = player.PlayerData.citizenid
        info.firstname = charinfo.firstname
        info.lastname = charinfo.lastname
        info.birthdate = charinfo.birthdate
        info.gender = charinfo.gender
        info.nationality = charinfo.nationality
    elseif itemData['name'] == 'driver_license' then
        info.firstname = charinfo.firstname
        info.lastname = charinfo.lastname
        info.birthdate = charinfo.birthdate
        info.type = 'Class C Driver License'
    elseif itemData['type'] == 'weapon' then
        amount = 1 -- AddItem fills in the serial number and quality
    elseif itemData['name'] == 'harness' then
        info.uses = 20
    elseif itemData['name'] == 'markedbills' then
        info.worth = math.random(5000, 10000)
    elseif itemData['name'] == 'printerdocument' then
        info.url = 'https://cdn.discordapp.com/attachments/870094209783308299/870104331142189126/Logo_-_Display_Picture_-_Stylized_-_Red.png'
    end

    if AddItem(id, itemData['name'], amount, false, info, 'give item command') then
        QBCore.Functions.Notify(source, 'You Have Given ' .. GetPlayerName(id) .. ' ' .. amount .. ' ' .. itemData['name'], 'success')
        TriggerClientEvent('qb-inventory:client:ItemBox', id, itemData, 'add', amount)
    else
        QBCore.Functions.Notify(source, "Can't give item!", 'error')
    end
end, 'admin')

QBCore.Commands.Add('randomitems', 'Receive random items', {}, false, function(source)
    local filtered = {}
    for _, v in pairs(QBCore.Shared.Items) do
        if v['type'] ~= 'weapon' then filtered[#filtered + 1] = v end
    end
    for _ = 1, 10 do
        local item = filtered[math.random(1, #filtered)]
        local amount = item['unique'] and 1 or math.random(1, 10)
        if AddItem(source, item.name, amount, false, false, 'random items command') then
            TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items[item.name], 'add', amount)
        end
        Wait(1000)
    end
end, 'god')

QBCore.Commands.Add('clearinv', 'Clear Inventory (Admin Only)', { { name = 'id', help = 'Player ID' } }, false, function(source, args)
    local id = tonumber(args[1])
    ClearInventory(id or source)
end, 'admin')

-- ---------- Key-bound commands (the client key mappings run these) ----------

RegisterCommand('closeInv', function(source)
    if source == 0 then return end
    CloseInventory(source)
end, false)

RegisterCommand('inventory', function(source)
    if source == 0 then return end
    OpenFromKey(source)
end, false)

RegisterCommand('hotbar', function(source)
    if source == 0 then return end
    TriggerClientEvent('qb-inventory:client:hotbar', source)
end, false)
