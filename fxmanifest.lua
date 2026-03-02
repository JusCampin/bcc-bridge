---@diagnostic disable
fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

game 'rdr3'
lua54 'yes'
author 'BCC Team'
description 'Standalone VORP / RSG framework bridge for RedM'

dependencies {
    'oxmysql',
}

shared_scripts {
    'configs/*.lua',
    'shared/locales.lua',
    'shared/languages/*.lua',
    -- Shared bridge utilities and type documentation
    'bridge/shared/utils.lua',
    'bridge/shared/types.lua',
}

client_scripts {
    -- Framework bridge implementations (loaded before entrypoint)
    'bridge/client/vorp.lua',
    'bridge/client/rsg.lua',
    'bridge/client/fallback.lua',
    -- Entrypoint: selects the active bridge and registers exports
    'client/main.lua',
}

server_scripts {
    -- Framework bridge implementations (loaded before entrypoint)
    'bridge/server/vorp.lua',
    'bridge/server/rsg.lua',
    'bridge/server/fallback.lua',
    -- Entrypoint: selects the active bridge and registers exports
    'server/main.lua',
}

-- Server-side exports available to other resources via exports['bcc-bridge']:Fn(...)
server_exports {
    'GetFramework',
    'GetPlayer',
    'IsPlayerLoaded',
    'GetPlayerIdentifier',
    'GetCharacter',
    -- Jobs
    'GetJob', 'SetJob', 'GetAllJobs',
    -- Gangs
    'GetGang', 'SetGang', 'GetAllGangs',
    -- Metadata
    'GetMetadata', 'SetMetadata',
    -- Licenses
    'GetLicenses', 'HasLicense', 'AddLicense', 'RemoveLicense',
    -- Skills
    'GetSkill', 'SetSkill', 'AddSkillXP',
    -- Economy
    'GetMoney', 'AddMoney', 'RemoveMoney',
    -- Inventory
    'GetItem', 'AddItem', 'RemoveItem',
    -- Misc
    'Notify', 'RegisterCallback',
}

-- Client-side exports available to other resources via exports['bcc-bridge']:Fn(...)
exports {
    'GetFramework',
    'IsPlayerLoaded', 'GetPlayerData', 'GetCharacterData',
    -- Instant (cached)
    'GetJob', 'GetGang',
    'GetMetadata', 'GetLicenses', 'HasLicense', 'GetSkill',
    'GetMoney', 'GetItem',
    'Notify', 'TriggerCallback',
    -- Server-authoritative (async)
    'ServerGetCharacter',
    'ServerGetJob', 'ServerSetJob', 'ServerGetAllJobs',
    'ServerGetGang', 'ServerSetGang', 'ServerGetAllGangs',
    'ServerGetMetadata', 'ServerSetMetadata',
    'ServerGetLicenses', 'ServerHasLicense', 'ServerAddLicense', 'ServerRemoveLicense',
    'ServerGetSkill', 'ServerSetSkill', 'ServerAddSkillXP',
    'ServerGetMoney', 'ServerAddMoney', 'ServerRemoveMoney',
    'ServerGetItem', 'ServerAddItem', 'ServerRemoveItem',
    'ServerNotify',
}

version '1.0.0'
