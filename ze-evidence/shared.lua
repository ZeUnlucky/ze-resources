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