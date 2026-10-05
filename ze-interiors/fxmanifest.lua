fx_version 'adamant'

game 'gta5'

author 'ZeUnlucky'
description ''
version '1.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js'
}

client_scripts {
    'client/client.lua',
    'client/menu.lua',
    'client/lobby.lua'
}

dependencies {
    'qb-core',
    'oxmysql'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/buildings.lua',
    'server/houses.lua',
    'server/server.lua',
    'server/menu.lua',
    'server/lobby.lua',
    'server/keys.lua'
}

shared_scripts {
    'shared/config.lua',
    'shared/shared.lua'
}
