fx_version 'cerulean'
game 'gta5'

name 'fivem_exporter'
author 'elempius'
description 'Prometheus exporter for FiveM server resources.'
version '0.0.1'

dependency 'ox_lib'

shared_scripts {
    '@ox_lib/init.lua'
}

server_scripts {
    'config.lua',
    'server/util.lua',
    'server/validate.lua',
    'server/render.lua',
    'server/registry.lua',
    'server/http.lua',
    'server/main.lua'
}

server_exports {
    'PromRegisterCounter',
    'PromRegisterGauge',
    'PromRegisterHistogram',
    'PromIncCounter',
    'PromAddCounter',
    'PromSetGauge',
    'PromIncGauge',
    'PromDecGauge',
    'PromObserveHistogram'
}