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
    'client/main.lua',
    'client/casings.lua',
    'client/fingerprints.lua',
    'client/blood.lua',
    'client/lab.lua',
    'config.lua',
    'shared.lua'
}

server_scripts {
    'server/main.lua',
    'server/lab.lua',
    'config.lua',
    'shared.lua'
}
