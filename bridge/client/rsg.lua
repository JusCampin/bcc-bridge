-------------------------------------------------------------------
-- RSG Framework – Client-side bridge implementation
-------------------------------------------------------------------

---@class RSGClientBridge
RSGClientBridge = {}

local _core       = nil
local _playerData = nil -- cached PlayerData table after load

--- Lazy-load RSG core object
local function Core()
    if _core then return _core end
    local ok, c = pcall(function()
        return exports[Config.Resources.rsg]:GetCoreObject()
    end)
    if ok and c then
        _core = c
        return _core
    end
    return nil
end

-- Keep player data up to date via framework events
AddEventHandler('rsg-core:onPlayerLoaded', function(pd)
    _playerData = pd
    local charId = pd and pd.charinfo and pd.charinfo.charidentifier or 0
    TriggerEvent('bcc-bridge:playerLoaded', charId)
end)

AddEventHandler('rsg-core:onPlayerUnload', function()
    _playerData = nil
end)

-- Sync PlayerData on any update push from the server
AddEventHandler('rsg-core:onPlayerData', function(pd)
    _playerData = pd
end)

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

function RSGClientBridge.IsPlayerLoaded()
    return _playerData ~= nil
end

function RSGClientBridge.GetPlayerData()
    return _playerData
end

--- Returns a normalised character info table
function RSGClientBridge.GetCharacterData()
    if not _playerData then return nil end
    local ci   = _playerData.charinfo or {}
    local job  = _playerData.job      or {}
    local gang = _playerData.gang     or {}
    local jg   = job.grade   or {}
    local gg   = gang.grade  or {}
    local jobData  = BridgeUtils.makeJob(job.name, jg.level, job.label, jg.label, job.isboss)
    local gangData = BridgeUtils.makeGang(gang.name, gg.level, gang.label, gg.label, gang.isboss)
    return BridgeUtils.makeCharacter(nil, ci.firstname, ci.lastname, jobData, gangData, _playerData.metadata or {})
end

---------------------------------------------------------------------------
-- Economy helpers (client-cached values)
---------------------------------------------------------------------------

function RSGClientBridge.GetMoney(moneyType)
    if not _playerData then return 0 end
    local t      = Config.MoneyTypes.rsg[moneyType or 'cash'] or 'cash'
    local money  = _playerData.money or {}
    return tonumber(money[t]) or 0
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------

function RSGClientBridge.GetItem(itemName)
    local c = Core()
    if not c then return 0 end
    local ok, item = pcall(function()
        return c.Functions.GetItemByName(itemName)
    end)
    if ok and item then
        return tonumber(item.amount or item.count or 0)
    end
    return 0
end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

--- notifyType: 'primary' | 'success' | 'error' | 'warning'
function RSGClientBridge.Notify(message, notifyType, duration)
    TriggerEvent('rsg-core:notify', message, notifyType or 'primary', duration or Config.NotifyDuration)
end

function RSGClientBridge.TriggerCallback(name, cb, ...)
    local args = { ... }
    Core().Functions.TriggerCallback(name, function(result)
        if cb then cb(result) end
    end, table.unpack(args))
end

function RSGClientBridge.TriggerCallbackAwait(name, args)
    local p = promise.new()
    RSGClientBridge.TriggerCallback(name, function(result)
        p:resolve(result)
    end, args)
    return Citizen.Await(p)
end

---------------------------------------------------------------------------
-- Job helpers  (from cached PlayerData)
---------------------------------------------------------------------------

function RSGClientBridge.GetJob()
    if not _playerData then return BridgeUtils.makeJob() end
    local job = _playerData.job or {}
    local g   = job.grade or {}
    return BridgeUtils.makeJob(job.name, g.level, job.label, g.label, job.isboss)
end

---------------------------------------------------------------------------
-- Gang helpers
---------------------------------------------------------------------------

function RSGClientBridge.GetGang()
    if not _playerData then return BridgeUtils.makeGang() end
    local gang = _playerData.gang or {}
    local g    = gang.grade or {}
    return BridgeUtils.makeGang(gang.name, g.level, gang.label, g.label, gang.isboss)
end

---------------------------------------------------------------------------
-- Metadata helpers
---------------------------------------------------------------------------

function RSGClientBridge.GetMetadata(key)
    if not _playerData then return nil end
    local meta = _playerData.metadata or {}
    return meta[key]
end

---------------------------------------------------------------------------
-- License helpers  (from metadata.licenses)
---------------------------------------------------------------------------

function RSGClientBridge.GetLicenses()
    local v = RSGClientBridge.GetMetadata('licenses')
    return type(v) == 'table' and v or {}
end

function RSGClientBridge.HasLicense(license)
    return RSGClientBridge.GetLicenses()[license] == true
end

---------------------------------------------------------------------------
-- Skill helpers  (from metadata.skills)
---------------------------------------------------------------------------

function RSGClientBridge.GetSkill(skill)
    local v = RSGClientBridge.GetMetadata('skills')
    return (type(v) == 'table' and tonumber(v[skill])) or 0
end
