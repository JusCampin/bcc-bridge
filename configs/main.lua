Config = {}

--[[
    Framework selection.
    Options:
        'auto'  – Auto-detect from running resources (recommended)
        'vorp'  – Force VORP Core
        'rsg'   – Force RSG Framework
]]
Config.Framework = 'vorp'

--[[
    Resource names for each framework component.
    Adjust these if your server uses non-standard resource names.
]]
Config.Resources = {
    vorp     = 'vorp_core',
    vorp_inv = 'vorp_inventory',
    rsg      = 'rsg-core',
}

--[[
    Unified money type keys used across the bridge:
        'cash'  – paper money / dollars
        'gold'  – gold nuggets / premium currency

    These are mapped to each framework's internal representation below.
    VORP uses integers (0 = cash, 1 = gold).
    RSG  uses strings ('cash', 'gold_regular').
]]
Config.MoneyTypes = {
    vorp = {
        cash = 0,
        gold = 1,
    },
    rsg = {
        cash = 'cash',
        gold = 'gold_regular',
    },
}

-- Default on-screen notification duration in milliseconds
Config.NotifyDuration = 5000
