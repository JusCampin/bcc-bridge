-------------------------------------------------------------------
-- Fallback – Server-side bridge implementation (no framework)
-- Uses in-memory storage only. Data resets on resource/server restart.
-- Useful for testing or servers running without a supported framework.
-------------------------------------------------------------------

---@class FallbackServerBridge
FallbackServerBridge = {}

-- In-memory store keyed by source/player-net-id
local store = {}

local function getStore(source)
    if not store[source] then
        store[source] = {
            money    = { cash = 0, gold = 0 },
            items    = {},
            metadata = {},
            job      = 'unemployed',
            jobGrade = 0,
            gang     = 'none',
            gangGrade = 0,
        }
    end
    return store[source]
end

-- Clean up on player drop to prevent memory leaks
AddEventHandler('playerDropped', function()
    store[source] = nil -- luacheck: ignore (source is implicit in AddEventHandler)
end)

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

function FallbackServerBridge.GetPlayer(source)
    return getStore(source)
end

function FallbackServerBridge.IsPlayerLoaded(source)
    return source ~= nil and tonumber(source) ~= 0
end

function FallbackServerBridge.GetPlayerIdentifier(source)
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if ident and ident:find('license:') then return ident end
    end
    return tostring(source)
end

function FallbackServerBridge.GetCharacter(source)
    local s = getStore(source)
    return BridgeUtils.makeCharacter(
        source,
        GetPlayerName(source) or 'Unknown',
        '',
        BridgeUtils.makeJob(s.job, s.jobGrade),
        BridgeUtils.makeGang(s.gang, s.gangGrade),
        s.metadata or {}
    )
end

---------------------------------------------------------------------------
-- Economy helpers
---------------------------------------------------------------------------

function FallbackServerBridge.GetMoney(source, moneyType)
    return getStore(source).money[moneyType or 'cash'] or 0
end

function FallbackServerBridge.AddMoney(source, moneyType, amount, _reason)
    local s = getStore(source)
    local t = moneyType or 'cash'
    s.money[t] = (s.money[t] or 0) + (tonumber(amount) or 0)
    return true
end

function FallbackServerBridge.RemoveMoney(source, moneyType, amount, _reason)
    local amt = tonumber(amount) or 0
    local s   = getStore(source)
    local t   = moneyType or 'cash'
    if (s.money[t] or 0) < amt then return false end
    s.money[t] = s.money[t] - amt
    return true
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------

function FallbackServerBridge.GetItem(source, itemName)
    return getStore(source).items[itemName] or 0
end

function FallbackServerBridge.AddItem(source, itemName, amount, _metadata)
    local s = getStore(source)
    s.items[itemName] = (s.items[itemName] or 0) + (tonumber(amount) or 1)
    return true
end

function FallbackServerBridge.RemoveItem(source, itemName, amount)
    local amt = tonumber(amount) or 1
    local s   = getStore(source)
    if (s.items[itemName] or 0) < amt then return false end
    s.items[itemName] = s.items[itemName] - amt
    return true
end

function FallbackServerBridge.GetItemWithMeta(_source, _itemName)
    return nil
end

function FallbackServerBridge.AddItemWithMeta(source, itemName, amount, _metadata)
    return FallbackServerBridge.AddItem(source, itemName, amount)
end

function FallbackServerBridge.RemoveItemWithMeta(source, itemName, amount, _metadata)
    return FallbackServerBridge.RemoveItem(source, itemName, amount)
end

function FallbackServerBridge.CanCarryItem(_source, _itemName, _amount)
    return true
end

function FallbackServerBridge.RegisterUsableItem(_itemName, _cb) end
function FallbackServerBridge.CloseInventory(_source) end
function FallbackServerBridge.IsCustomInventoryRegistered(_id) return false end
function FallbackServerBridge.RegisterInventory(_data) end
function FallbackServerBridge.OpenInventory(_source, _id) end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

function FallbackServerBridge.Notify(source, message, notifyType, duration)
    TriggerClientEvent('bcc-bridge:notify', source, message, notifyType, duration or Config.NotifyDuration)
end

function FallbackServerBridge.RegisterCallback(name, cb)
    RegisterNetEvent('bcc-bridge:cb:' .. name)
    AddEventHandler('bcc-bridge:cb:' .. name, function(args)
        local _source = source -- luacheck: ignore
        cb(_source, args, function(result)
            TriggerClientEvent('bcc-bridge:cbres:' .. name, _source, result)
        end)
    end)
end

---------------------------------------------------------------------------
-- Job helpers  (in-memory store)
---------------------------------------------------------------------------

function FallbackServerBridge.GetJob(source)
    return BridgeUtils.makeJob(getStore(source).job, getStore(source).jobGrade)
end

function FallbackServerBridge.SetJob(source, jobName, grade)
    local s = getStore(source)
    s.job      = jobName or 'unemployed'
    s.jobGrade = tonumber(grade) or 0
    return true
end

function FallbackServerBridge.GetAllJobs()
    return {}
end

---------------------------------------------------------------------------
-- Gang helpers  (in-memory store)
---------------------------------------------------------------------------

function FallbackServerBridge.GetGang(source)
    local s = getStore(source)
    return BridgeUtils.makeGang(s.gang, s.gangGrade)
end

function FallbackServerBridge.SetGang(source, gangName, grade, isBoss)
    local s = getStore(source)
    s.gang      = gangName or 'none'
    s.gangGrade = tonumber(grade) or 0
    s.gangBoss  = isBoss or false
    return true
end

function FallbackServerBridge.GetAllGangs()
    return {}
end

---------------------------------------------------------------------------
-- Metadata helpers
---------------------------------------------------------------------------

function FallbackServerBridge.GetMetadata(source, key)
    return getStore(source).metadata and getStore(source).metadata[key]
end

function FallbackServerBridge.SetMetadata(source, key, value, _drop)
    local s = getStore(source)
    if not s.metadata then s.metadata = {} end
    s.metadata[key] = value
    return true
end

---------------------------------------------------------------------------
-- License helpers
---------------------------------------------------------------------------

local function _fbLicenses(source)
    local v = FallbackServerBridge.GetMetadata(source, 'licenses')
    return type(v) == 'table' and v or {}
end

function FallbackServerBridge.GetLicenses(source)
    return _fbLicenses(source)
end

function FallbackServerBridge.HasLicense(source, license)
    return _fbLicenses(source)[license] == true
end

function FallbackServerBridge.AddLicense(source, license)
    local tbl = _fbLicenses(source)
    tbl[license] = true
    return FallbackServerBridge.SetMetadata(source, 'licenses', tbl)
end

function FallbackServerBridge.RemoveLicense(source, license)
    local tbl = _fbLicenses(source)
    tbl[license] = nil
    return FallbackServerBridge.SetMetadata(source, 'licenses', tbl)
end

---------------------------------------------------------------------------
-- Skill helpers
---------------------------------------------------------------------------

local function _fbSkills(source)
    local v = FallbackServerBridge.GetMetadata(source, 'skills')
    return type(v) == 'table' and v or {}
end

function FallbackServerBridge.GetSkill(source, skill)
    return tonumber(_fbSkills(source)[skill]) or 0
end

function FallbackServerBridge.SetSkill(source, skill, value)
    local tbl = _fbSkills(source)
    tbl[skill] = tonumber(value) or 0
    return FallbackServerBridge.SetMetadata(source, 'skills', tbl)
end

function FallbackServerBridge.AddSkillXP(source, skill, amount)
    local cur = FallbackServerBridge.GetSkill(source, skill)
    return FallbackServerBridge.SetSkill(source, skill, cur + (tonumber(amount) or 0))
end
