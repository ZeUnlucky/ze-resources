fx_version 'adamant'

game 'gta5'

author 'ZeUnlucky'
description ''
version '1.0'

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

shared_scripts {
    'shared.lua',
    'config.lua'
}

exports {
    'AddItem',
    'RemoveItem',
    'HasItem',
    'GetItemCount'
}