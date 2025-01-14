fx_version 'cerulean'
game 'gta5'

author 'Dexty'
description 'A server logging system with Discord Webhooks made by Dexty'
version '1.0.0'

server_scripts {
    'server.lua', 
    'config.lua',  
    'dextys_log.lua'
}

client_scripts {
    --
}

dependencies {
    'qb-core', -- Tämä skripti käyttää qb-corea (tarkista että se on asennettu serverillesi)
}
