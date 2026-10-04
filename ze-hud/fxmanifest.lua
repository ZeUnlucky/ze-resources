fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-hud: custom HUD, drop-in replacement for qb-hud'
version '1.0'

dependencies {
    'qb-core',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
}

shared_scripts {
    '@qb-core/shared/locale.lua',
    'locales/en.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/map.lua',
    'client/stress.lua',
}

server_scripts {
    'server/main.lua',
}

-- stream/ holds the square and circle minimap masks plus the minimap scaleform
-- (the same assets qb-hud ships). FiveM picks the folder up automatically.
