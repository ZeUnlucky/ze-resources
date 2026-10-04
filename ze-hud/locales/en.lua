local Translations = {
    notify = {
        ['hud_restart'] = 'HUD is restarting!',
        ['hud_start'] = 'HUD is now started!',
        ['hud_reset'] = 'HUD settings reset to default!',
        ['map_square'] = 'Square map loaded!',
        ['map_circle'] = 'Circle map loaded!',
        ['cinematic_on'] = 'Cinematic mode on!',
        ['cinematic_off'] = 'Cinematic mode off!',
        ['low_fuel'] = 'Fuel level low!',
        ['stress_gain'] = 'Feeling more stressed!',
        ['stress_removed'] = 'Feeling more relaxed!',
    },
}

Lang = Lang or Locale:new({
    phrases = Translations,
    warnOnMissing = true,
})
