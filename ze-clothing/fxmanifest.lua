fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-clothing: clothing, barber and surgeon menu, drop-in replacement for qb-clothing'
version '1.0'

dependencies {
    'qb-core',
    'oxmysql',
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
    '@PolyZone/client.lua',
    '@PolyZone/BoxZone.lua',
    '@PolyZone/ComboZone.lua',
    'client/skin.lua',
    'client/main.lua',
    'client/stores.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}
