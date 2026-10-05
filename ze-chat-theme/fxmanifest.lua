fx_version 'cerulean'
game 'common'

name 'ze-chat-theme'
author 'ZeUnlucky'
description 'Glass-style theme for the built-in chat resource'
version '1.0.0'

file 'style.css'
file 'theme.js'

chat_theme 'ze' {
    styleSheet = 'style.css',
    script = 'theme.js',
    msgTemplates = {
        default = '<b>{0}</b><span>{1}</span>'
    }
}
