fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-inventory: custom inventory UI and server, drop-in replacement for qb-inventory'
version '1.0'

dependencies {
    'qb-core',
    'oxmysql',
    'qb-weapons',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/images/*.png',
}

shared_scripts {
    'config.lua',
    'shared.lua',
}

client_scripts {
    'client/main.lua',
    'client/drops.lua',
    'client/vehicles.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/functions.lua',
    'server/moves.lua',
    'server/commands.lua',
    'server/compat.lua',
}
