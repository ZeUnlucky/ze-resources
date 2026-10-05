-- Server only. Nothing in this file is ever sent to a player, so keys and tokens belong here and not in config.lua.

ConfigServer = {}

-- Where camera photos are uploaded. Pick one:
--   'webhook'   a Discord webhook URL. The player's game uploads straight to it through screenshot-basic, so the URL
--               is visible to clients: use a webhook of a private channel made for this, never one you care about.
--   'fivemerr'  https://fivemerr.com/. The photo goes client -> server -> Fivemerr, so the token stays on the server.
--   'custom'    any image host with an API (Fivemanage and similar). Uploaded by the player's game, so the key in
--               `Headers` is visible to clients, as with every client side uploader.
--   'none'      the camera is disabled (the Camera app says so).
ConfigServer.Camera = {
    Provider = 'none',

    Webhook = '',

    Fivemerr = {
        Token = '',
        Url = 'https://api.fivemerr.com/v1/media/images',
    },

    Custom = {
        Url = '',                -- e.g. 'https://api.fivemanage.com/api/image'
        Field = 'file',          -- name of the form field the image is sent in
        Headers = {},            -- e.g. { Authorization = 'your key' }
        UrlPath = 'url',         -- where the image link is in the JSON answer, dotted: 'url', 'data.url', 'attachments.1.proxy_url'
    },
}

-- Optional Discord log of invoices that were paid through the phone ('' to turn off).
ConfigServer.InvoiceLogWebhook = ''
