fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_customs'
-- Keep the legacy resource name resolvable for exports['qbcustoms'] callers.
provide 'qbcustoms'
author 'qbcore2'
version '0.1.0'
description 'Public self-service cosmetic vehicle customisation'

-- Satisfies resources which only declare the retired qb-customs dependency.
-- kora_customs deliberately does not reproduce qb-customs' unsafe purchase
-- events; its own checkout callback revalidates every client claim.
provide 'qb-customs'

dependencies {
    'kora_lib',
    'kora_core',
    'kora_target'
}

shared_script '@kora_lib/init.lua'
shared_scripts {
    'config.lua',
    'shared/catalog.lua',
    'shared/camera.lua',
    'shared/horn.lua'
}

client_script 'client/main.lua'
server_scripts {
    '@kora_sql/init.lua',
    'server/main.lua'
}
