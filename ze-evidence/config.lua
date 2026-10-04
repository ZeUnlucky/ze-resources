Config = {}
Config.ShellProp = "w_pi_singleshoth4_shell"
Config.LabLocations = {
    vector3(419.2, -985.5, 29.5)
}

-- Jobs allowed to use the forensic lab, mapped to the minimum grade required.
Config.LabJobs = {
    police = 0,
    sheriff = 0
}

-- Most records a single lab search will return.
Config.LabMaxResults = 100

-- Mixed into every fingerprint and DNA string. Change it to a private value of your own; changing it later
-- gives everyone new prints and DNA, so evidence logged under the old value will no longer match.
Config.EvidenceSecret = 'ze-evidence-change-me'
