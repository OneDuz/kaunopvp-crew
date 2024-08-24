fx_version 'cerulean'
game 'gta5'

lua54 "yes"

author "onecodes"
version "1.0.5"
description 'Crew system that was made for kaunopvp.lt but never saw the day of light'


server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'config.lua',
    'server.lua',
    'antidump/server.lua',
}

client_scripts {
    'config.lua',
    'client.lua',
}

shared_script '@ox_lib/init.lua'
