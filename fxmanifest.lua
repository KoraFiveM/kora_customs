fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'kora_customs'
author 'qbcore2'
version '0.2.1'
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
    'server/main.lua',
    -- Optional FFT hooks: returns immediately unless fft_kora_hooks is true.
    'fft_hooks_server.lua'
}

-- kora_qa: Gherkin test scenarios (converted legacy tests), see [kora]/kora_qa/README.md
qa_feature 'tests/*.feature'
