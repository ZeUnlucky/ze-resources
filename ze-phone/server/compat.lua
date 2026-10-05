-- Answers to the name qb-phone: about 27 resources on this server send mail, police alerts and race news to
-- `qb-phone`. Its exports are answered here, the events it handled are kept (client side in client/main.lua), and the
-- stand-in resource called qb-phone (the folder next to this one) keeps the name alive for everything that checks it.

local ownName = GetCurrentResourceName()
local asQbPhone = ownName ~= 'qb-phone'   -- if this folder is renamed qb-phone, no impersonation is needed

local API = {
    sendNewMailToOffline = Mail.Send,
}

for name, fn in pairs(API) do
    exports(name, fn)
    if asQbPhone then
        AddEventHandler(('__cfx_export_qb-phone_%s'):format(name), function(setCB)
            setCB(fn)
        end)
    end
end

-- Resources that called exports['qb-phone'] keep the function they were handed, and Cfx only drops it when a resource
-- named qb-phone stops. Announce a stop for the stand-in's name once the handlers above are in place, so a restart of
-- ze-phone alone does not leave qb-weapons, qb-cityhall and the others holding dead references.
if asQbPhone then
    CreateThread(function()
        TriggerEvent('onServerResourceStop', 'qb-phone')
    end)
end

-- qb-phone:server:sendNewMail: a mail for the player who triggered it (qb-drugs, qb-policejob, qb-cityhall, ...)
RegisterNetEvent('qb-phone:server:sendNewMail', function(mailData)
    local src = source
    local me = Core.Online(src)
    if not me or type(mailData) ~= 'table' then return end
    if not Core.RateOk(src, 'sendNewMail', 150) then return end
    Mail.Send(me.cid, mailData)
end)

-- a mail for any citizen id. Only other server scripts may use this one (qb-phone let every client mail everyone).
AddEventHandler('qb-phone:server:sendNewEventMail', function(citizenid, mailData)
    Mail.Send(citizenid, mailData)
end)

-- Check the setup a few seconds after start, once the other resources have had time to come up.
CreateThread(function()
    Wait(10000)
    local state = GetResourceState('qb-phone')
    local description = GetResourceMetadata('qb-phone', 'description', 0) or ''
    if asQbPhone and state == 'missing' then
        print('^1[ze-phone] Other resources send mail and alerts to a resource called "qb-phone".')
        print('^1[ze-phone] Add the stand-in resource (the "qb-phone" folder next to ze-phone) and ensure it, or rename this folder to qb-phone.^7')
    elseif asQbPhone and state == 'started' and not description:find('ze-phone stand-in', 1, true) then
        print('^1[ze-phone] The original qb-phone is running as well. Two phones will fight over the same events and tables.')
        print('^1[ze-phone] Stop it and remove it from the resources folder (move it outside, not just renamed inside [qb]).^7')
    end

    if GetResourceState('screenshot-basic') ~= 'started' and ConfigServer.Camera.Provider ~= 'none' then
        print('^3[ze-phone] The camera is set up in config.server.lua but screenshot-basic is not running.^7')
    end
end)
