fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-phone stand-in: lets other resources keep sending mail and alerts to a resource called qb-phone'
version '1.0'

-- This resource has no code. About 27 resources send events and exports to the name qb-phone;
-- ze-phone answers all of them (see ze-phone/server/compat.lua and client/main.lua).
dependency 'ze-phone'
