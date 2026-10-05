fx_version 'cerulean'

game 'gta5'
lua54 'yes'

author 'ZeUnlucky'
description 'ze-clothing stand-in: lets qb-houses, qb-apartments and other resources find clothing under the name qb-clothing'
version '1.0'

-- This resource has no code. qb-houses and qb-apartments list 'qb-clothing' in their dependencies, so a resource with
-- this name has to exist and be started. ze-clothing answers all the actual events and exports.
dependency 'ze-clothing'
