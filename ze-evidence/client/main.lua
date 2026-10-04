local QBCore = exports['qb-core']:GetCoreObject()

Citizen.CreateThread(function()
    AddTargets()
end)

function AddTargets()
    exports['qb-target']:AddGlobalPlayer({
        options = {
          {
            icon = "fas fa-fingerprint",
            label = "Take Fingerprint",
            action = function(entity)
              TriggerServerEvent("ze-evidence:GetFingerprintFromPlayer", GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity)))
            end,
            canInteract = function(entity)
              return IsPedAPlayer(entity)
            end,
            job = { ["police"] = 0 },
            item = "pdfingerprinttape"
          },
          {
            icon = "fas fa-droplet",
            label = "Take DNA Sample",
            action = function(entity)
              TriggerServerEvent("ze-evidence:GetDNAFromPlayer", GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity)))
            end,
            canInteract = function(entity)
              return IsPedAPlayer(entity)
            end,
            job = { ["police"] = 0 }
          }
        },
        distance = 2.5
    })

    for i, position in ipairs(Config.LabLocations) do
        exports['qb-target']:AddCircleZone("forensicLab"..i, position, 3, {
            name = "forensicLab"..i,
            useZ = true
        }, {
            options = {
                {
                    icon = "fas fa-gun",
                    label = "Submit Casings",
                    targeticon = "fas fa-gun",
                    item = "casing",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:SubmitCasing", SubmitCasing())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-droplet",
                    label = "Submit DNA",
                    targeticon = "fas fa-droplet",
                    item = "blood_vial",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:SubmitDNA", SubmitDNA())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-gun",
                    label = "Get Casing by ID",
                    targeticon = "fas fa-gun",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:server:GetCasingByID", GetCasingID())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-gun",
                    label = "Get Casings by Serial",
                    targeticon = "fas fa-gun",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:server:GetCasingsBySerial", GetCasingSerial())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-droplet",
                    label = "Get DNA by ID",
                    targeticon = "fas fa-droplet",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:server:GetDNAByID", GetDNAID())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
                {
                    icon = "fas fa-droplet",
                    label = "Get DNA by Serial",
                    targeticon = "fas fa-droplet",
                    action = function(entity)
                        TriggerServerEvent("ze-evidence:server:GetDNABySerial", GetDNASerial())
                    end,
                    job = { ["police"] = 0, ["sheriff"] = 0 }, 
                    drawDistance = 10.0,
                    drawColor = {255, 255, 255, 255},
                    successDrawColor = {0, 255, 0, 255}
                },
            },
            distance = 2.5
        })
    end
end



RegisterNetEvent("ze-evidence:PlayerJoined", function(Splatters, Casings)
    Citizen.CreateThread(function()
        for i, v in ipairs(Splatters) do
            local hash = GetHashKey("p_bloodsplat_s")
            local splatterID = CreateObject(hash, v.position, false)
            FreezeEntityPosition(splatterID, true)
            Citizen.Wait(100)
            exports['qb-target']:AddEntityZone("blood_splatter_"..v.id, splatterID, {
                name = "blood_splatter_"..v.id
            }, {
                options = {
                    {
                        num = 1,
                        icon = "fas fa-droplet",
                        label = "Collect Blood",
                        action = function(entity)
                            TriggerServerEvent("ze-evidence:CollectSplatter", v.id, v.DNA, true)
                        end,                        
                        drawDistance = 10.0,
                        drawColor = {200, 0, 0, 255},
                        job = "police"
                    },
                    {
                        num = 2,
                        icon = "fas fa-toilet-paper",
                        label = "Clean Blood",
                        action = function(entity)
                            TriggerServerEvent("ze-evidence:CollectSplatter", v.id, v.DNA, false)
                        end,                        
                        drawDistance = 10.0,
                        drawColor = {200, 0, 0, 255}
                    }
                },
                distance = 3.0
            })
        end

        RequestModel(Config.ShellProp)
        while not HasModelLoaded(Config.ShellProp) do
            Wait(500)
        end
        for k, v in pairs(Casings) do
            local created_casing = CreateObjectNoOffset(Config.ShellProp, v.position, false)
            local forward, right, up, position = GetEntityMatrix(created_casing)
			SetEntityMatrix(created_casing, forward*1.75, right*1.75, up*1.75, position)
            FreezeEntityPosition(created_casing, true)
            exports['qb-target']:AddEntityZone("casing".. v.id, created_casing, {
                name = "casing"..v.id,
            }, {
                options = {
                    {
                        num = 1,
                        type = "client",
                        label = "Collect Casing",
                        action = function()
                            TriggerServerEvent("ze-evidence:CollectCasing", v.id)
                            DeleteEntity(created_casing)
                        end,
                        drawDistance = 10.0, 
                        drawColor = {255, 0, 0, 0}, 
                        successDrawColor = {30, 144, 255, 255},
                    }
                },
                distance = 5.0
            })
        end
        SetModelAsNoLongerNeeded(Config.ShellProp)
    end)
end)


