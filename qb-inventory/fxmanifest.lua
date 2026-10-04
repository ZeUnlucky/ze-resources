fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-inventory stand-in: lets qb-core and other resources find an inventory under the name qb-inventory'
version '1.0'

-- This resource has no code. qb-core only loads, saves and uses inventories while GetResourceState('qb-inventory')
-- is not 'missing', so a resource with this name has to exist. ze-inventory answers all the actual calls.
dependency 'ze-inventory'
