local QBCore = exports['qb-core']:GetCoreObject()

-- Column size of ze_casings.label / ze_dnas.label.
local MAX_LABEL_LENGTH = 255

-- Everything that differs between the two kinds of lab evidence lives here, so the
-- submit and search handlers below work for both.
local EvidenceTypes = {
    casing = {
        item = "casing",
        infoField = "serialNumber",
        insert = "INSERT INTO `ze_casings` (label, gunSerial, submittedBy) VALUES (?, ?, ?)",
        byId = "SELECT id, label, gunSerial AS value, submittedBy FROM `ze_casings` WHERE id = ?",
        byValue = "SELECT id, label, gunSerial AS value, submittedBy FROM `ze_casings` WHERE gunSerial = ? ORDER BY id DESC LIMIT %d",
    },
    dna = {
        item = "blood_vial",
        infoField = "DNA",
        insert = "INSERT INTO `ze_dnas` (label, dnaString, submittedBy) VALUES (?, ?, ?)",
        byId = "SELECT id, label, dnaString AS value, submittedBy FROM `ze_dnas` WHERE id = ?",
        byValue = "SELECT id, label, dnaString AS value, submittedBy FROM `ze_dnas` WHERE dnaString = ? ORDER BY id DESC LIMIT %d",
    },
}

local function InsertAwait(query, params)
    local p = promise.new()
    exports['oxmysql']:insert(query, params, function(id) p:resolve(id) end)
    return Citizen.Await(p)
end

local function QueryAwait(query, params)
    local p = promise.new()
    exports['oxmysql']:query(query, params, function(rows) p:resolve(rows) end)
    return Citizen.Await(p)
end

local function Fail(message)
    return { ok = false, error = message }
end

local function Trim(value)
    return type(value) == "string" and value:match("^%s*(.-)%s*$") or ""
end

local function IsLabAuthorized(Player)
    if not Player then return false end
    local job = Player.PlayerData.job
    local minGrade = job and Config.LabJobs[job.name]
    if minGrade == nil then return false end
    return (job.grade and job.grade.level or 0) >= minGrade
end

-- Splits the evidence a player is carrying into single loggable units (one entry per
-- item in the stack) and a count of items that carry no data the lab could log.
local function CollectEvidence(Player, evidence)
    local units, unusable = {}, 0
    for _, item in pairs(Player.PlayerData.items or {}) do
        if item.name == evidence.item then
            local amount = item.amount or 1
            local value = type(item.info) == "table" and item.info[evidence.infoField]
            if value then
                for _ = 1, amount do
                    units[#units + 1] = { slot = item.slot, value = value, info = item.info }
                end
            else
                unusable = unusable + amount
            end
        end
    end
    return units, unusable
end

local function BuildSummary(Player)
    local summary = {
        officer = Player.Functions.GetName(),
        maxLabel = MAX_LABEL_LENGTH,
    }
    for name, evidence in pairs(EvidenceTypes) do
        local units, unusable = CollectEvidence(Player, evidence)
        summary[name] = { ready = #units, unusable = unusable }
    end
    return summary
end

local LabHandlers = {}

LabHandlers.summary = function(Player)
    return { ok = true, data = BuildSummary(Player) }
end

LabHandlers.submit = function(Player, payload)
    local evidence = EvidenceTypes[payload.type]
    if not evidence then return Fail("Unknown evidence type.") end

    local label = Trim(payload.label)
    if label == "" then return Fail("Enter a label for this submission.") end
    local length = utf8.len(label)
    if not length then return Fail("The label contains invalid characters.") end
    if length > MAX_LABEL_LENGTH then return Fail("The label is too long.") end

    local units, unusable = CollectEvidence(Player, evidence)
    if #units == 0 then
        return Fail("You aren't carrying any evidence of this type that can be logged.")
    end

    local src = Player.PlayerData.source
    local submittedBy = Player.Functions.GetName()
    local ids, failed = {}, 0
    for _, unit in ipairs(units) do
        -- Take the item first so a failed removal can never log the same evidence twice.
        if Player.Functions.RemoveItem(evidence.item, 1, unit.slot) then
            local id = InsertAwait(evidence.insert, { label, unit.value, submittedBy })
            if id then
                ids[#ids + 1] = id
            else
                failed = failed + 1
                exports['qb-inventory']:AddItem(src, evidence.item, 1, false, unit.info, 'ze-evidence:labRefund')
            end
        else
            failed = failed + 1
        end
    end

    if #ids == 0 then return Fail("Couldn't log your evidence. Nothing was submitted.") end

    return {
        ok = true,
        data = {
            submitted = #ids,
            ids = ids,
            failed = failed,
            skipped = unusable,
            summary = BuildSummary(Player),
        },
    }
end

LabHandlers.search = function(Player, payload)
    local evidence = EvidenceTypes[payload.type]
    if not evidence then return Fail("Unknown evidence type.") end

    local query = Trim(payload.query)
    local limit = math.max(1, math.floor(tonumber(Config.LabMaxResults) or 100))
    local rows

    if payload.mode == "id" then
        if not query:match("^%d+$") or #query > 10 then return Fail("Enter a valid record ID.") end
        rows = QueryAwait(evidence.byId, { tonumber(query) })
    elseif payload.mode == "value" then
        if query == "" then return Fail("Enter something to search for.") end
        rows = QueryAwait(evidence.byValue:format(limit), { query })
    else
        return Fail("Unknown search mode.")
    end

    if not rows then return Fail("The records database did not respond.") end
    return { ok = true, data = { results = rows, limit = limit } }
end

-- Single entry point for the lab UI: the client sends { requestId, action, payload }
-- and always gets exactly one ze-evidence:client:LabResponse back.
RegisterNetEvent("ze-evidence:server:LabRequest", function(requestId, action, payload)
    local src = source
    local handler = type(action) == "string" and LabHandlers[action]
    local result

    if not handler then
        result = Fail("Unknown request.")
    else
        local Player = QBCore.Functions.GetPlayer(src)
        if not IsLabAuthorized(Player) then
            result = Fail("You are not authorized to use the forensic lab.")
        else
            local ok, response = pcall(handler, Player, type(payload) == "table" and payload or {})
            if ok then
                result = response
            else
                print(("[ze-evidence] lab '%s' failed for player %d: %s"):format(action, src, tostring(response)))
                result = Fail("The laboratory ran into an error. Try again.")
            end
        end
    end

    TriggerClientEvent("ze-evidence:client:LabResponse", src, requestId, result)
end)
