fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-phone: smartphone with calls, messages, social, bank, MDT and more, drop-in replacement for qb-phone'
version '1.0'

dependencies {
    'qb-core',
    'oxmysql',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/*.css',
    'html/js/*.js',
    'html/js/apps/*.js',
}

shared_scripts {
    'config.lua',
    '@qb-apartments/config.lua',
}

client_scripts {
    'client/main.lua',
    'client/anim.lua',
    'client/calls.lua',
    'client/camera.lua',
    'client/apps.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.server.lua',
    'server/db.lua',
    'server/core.lua',
    'server/phone.lua',
    'server/contacts.lua',
    'server/messages.lua',
    'server/calls.lua',
    'server/social.lua',
    'server/mail.lua',
    'server/bank.lua',
    'server/services.lua',
    'server/gallery.lua',
    'server/compat.lua',
}
