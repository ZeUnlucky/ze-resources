Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if IsPedShooting(PlayerPedId()) then
            Citizen.Wait(50)
            RequestModel(Config.ShellProp)
            while not HasModelLoaded(Config.ShellProp) do
                Wait(500)                
            end
            local pCoords = GetEntityCoords(PlayerPedId())

            local created_object = CreateObjectNoOffset(Config.ShellProp, pCoords.x+math.random(-1,1), pCoords.y+math.random(-1,1), pCoords.z, true, 0, 1)
            PlaceObjectOnGroundProperly(created_object)
            SetEntityHeading(created_object, GetEntityHeading(PlayerPedId()))
            local forward, right, up, position = GetEntityMatrix(created_object)
			SetEntityMatrix(created_object, forward*1.75, right*1.75, up*1.75, position)
            FreezeEntityPosition(created_object, true)
            SetModelAsNoLongerNeeded(Config.ShellProp)
            NetworkRegisterEntityAsNetworked(created_object)
            Wait(1)
            local entID = NetworkGetNetworkIdFromEntity(created_object)
            Wait(1)
            TriggerServerEvent("ze-evidence:RegisterNewCasing", entID, GetSelectedPedWeapon(PlayerPedId()), GetEntityCoords(created_object), not Shared.ArmsWithoutGloves[GetEntityModel(PlayerPedId()) == `mp_m_freemode_01` and 'male' or 'female'][GetPedDrawableVariation(PlayerPedId(), 3)])
            Citizen.Wait(5000)
        end
    end
end)

function OpenCasingResultMenu(data)
    local options = {}
    for i, v in ipairs(data) do
        table.insert(options,  { 
            header = "Casing #"..v.id..' ['..v.gunSerial..']', 
            icon = "fas fa-gun", 
            txt = v.submittedBy .. ": " .. v.label,
            disabled = true,
        })
    end
    exports['qb-menu']:openMenu(
        options, true, false)
end

function SubmitCasing()
    local dialog = exports['qb-input']:ShowInput({
        header = "Submit Casing",
        submitText = "Submit",
        inputs = {
            {
                text = "Casing Label", 
                name = "label", 
                type = "text",
                isRequired = true, 
            }
        }
    })
    return dialog["label"]
end

function GetCasingID()
    local dialog = exports['qb-input']:ShowInput({
        header = "Find Casing by ID",
        submitText = "Fetch",
        inputs = {
            {
                text = "Casing ID", 
                name = "cid", 
                type = "number",
                isRequired = true, 
            }
        }
    })
    return dialog["cid"]
end

function GetCasingSerial()
    local dialog = exports['qb-input']:ShowInput({
        header = "Find Casing by Serial",
        submitText = "Fetch",
        inputs = {
            {
                text = "Casing Serial", 
                name = "cserial", 
                type = "text",
                isRequired = true, 
            }
        }
    })
    return dialog["cserial"]
end

RegisterNetEvent("ze-evidence:RegisterNewCasingClient")
AddEventHandler("ze-evidence:RegisterNewCasingClient", function(casingId, serial)
    exports['qb-target']:AddEntityZone("casing"..casingId, NetworkGetEntityFromNetworkId(casingId), {
        name = "casing"..casingId,
    }, {
        options = {
            {
                num = 1,
                type = "client",
                label = "Collect Casing",
                action = function()
                    TriggerServerEvent("ze-evidence:CollectCasing", casingId)
                end,
                drawDistance = 10.0, 
                drawColor = {255, 0, 0, 0}, 
                successDrawColor = {30, 144, 255, 255},
            }
        },
        distance = 5.0
    })
end)


RegisterNetEvent("ze-evidence:RemoveCasingMenu")
AddEventHandler("ze-evidence:RemoveCasingMenu", function(casingId)
    exports['qb-target']:RemoveZone("casing".. casingId)
end)

RegisterNetEvent("ze-evidence:client:GetCasingByID", function(data)
    OpenCasingResultMenu(data)
end)

RegisterNetEvent("ze-evidence:client:GetCasingsBySerial", function(data)
    OpenCasingResultMenu(data)
end)

