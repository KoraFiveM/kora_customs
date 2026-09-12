fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qbcustoms'
author 'qbcore2'
version '0.1.0'
description 'Public self-service cosmetic vehicle customisation'

-- Satisfies resources which only declare the retired qb-customs dependency.
-- qbcustoms deliberately does not reproduce qb-customs' unsafe purchase
-- events; its own checkout callback revalidates every client claim.
provide 'qb-customs'

dependencies {
    'qblib',
    'qbcore',
    'qbtarget'
}

shared_script '@qblib/init.lua'

shared_scripts {
    'config.lua',
    'shared/catalog.lua'
}

client_script 'client/main.lua'
server_script 'server/main.lua'
