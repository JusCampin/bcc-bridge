-------------------------------------------------------------------
-- VORP Core – Client-side bridge implementation
-------------------------------------------------------------------

---@class VORPClientBridge
VORPClientBridge = {}

local _core       = nil
local _playerData = nil -- cached User object after spawn

--- Lazy-load VORP core object
local function Core()
    if _core then return _core end
    local ok, c = pcall(function()
        return exports[Config.Resources.vorp]:GetCore()
    end)
    if ok and c then
        _core = c
        return _core
    end
    return nil
end

-- Cache the user object on player spawn
AddEventHandler('vorp:playerSpawn', function()
    local c = Core()
    if not c then return end
    local ok, user = pcall(function() return c.getUser() end)
    if ok and user then _playerData = user end
end)

-- Fire generic player-loaded event when character is selected
AddEventHandler('vorp:SelectedCharacter', function(charId)
    TriggerEvent('bcc-bridge:playerLoaded', charId)
end)

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

function VORPClientBridge.IsPlayerLoaded()
    return _playerData ~= nil
end

function VORPClientBridge.GetPlayerData()
    return _playerData
end

--- Returns a normalised character info table
function VORPClientBridge.GetCharacterData()
    if not _playerData then return nil end
    local char = _playerData.getUsedCharacter
    if not char then return nil end
    local jobData  = BridgeUtils.makeJob(char.job, char.jobGrade)
    local gangMeta = BridgeUtils.try(function() return char.getMetaData('gang') end)
    local gangData = type(gangMeta) == 'table'
        and BridgeUtils.makeGang(gangMeta.name, gangMeta.grade, gangMeta.label, gangMeta.gradeLabel, gangMeta.isBoss)
        or  BridgeUtils.makeGang()
    local meta = BridgeUtils.try(function() return char.metadata end) or {}
    local info = BridgeUtils.makeCharacter(nil, char.firstname, char.lastname, jobData, gangData, meta)
    info.identifier     = char.identifier
    info.charIdentifier = char.charIdentifier
    return info
end

---------------------------------------------------------------------------
-- Economy helpers (client-cached values)
---------------------------------------------------------------------------

function VORPClientBridge.GetMoney(moneyType)
    if not _playerData then return 0 end
    local char = _playerData.getUsedCharacter
    if not char then return 0 end
    if (moneyType or 'cash') == 'gold' then
        return tonumber(char.gold) or 0
    else
        return tonumber(char.money) or 0
    end
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------

function VORPClientBridge.GetItem(itemName)
    local p = promise.new()
    local ok = pcall(function()
        exports[Config.Resources.vorp_inv]:getItemCount(nil, function(count)
            p:resolve(tonumber(count) or 0)
        end, itemName, nil, 0)
    end)
    if not ok then return 0 end
    return Citizen.Await(p)
end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

--- notifyType: 'primary' | 'success' | 'error' | 'warning'
--- VORP only exposes TipRight (Core.NotifyRightTip); always use it regardless of type
function VORPClientBridge.Notify(message, notifyType, duration)
    local dur = duration or Config.NotifyDuration
    TriggerEvent('vorp:TipRight', message, dur)
end

function VORPClientBridge.TriggerCallback(name, cb, args)
    Core().Callback.TriggerAsync(name, function(result)
        if cb then cb(result) end
    end, args or {})
end

function VORPClientBridge.TriggerCallbackAwait(name, args)
    return Core().Callback.TriggerAwait(name, args or {})
end

---------------------------------------------------------------------------
-- Job helpers  (from cached character data)
---------------------------------------------------------------------------

function VORPClientBridge.GetJob()
    if not _playerData then return BridgeUtils.makeJob() end
    local char = _playerData.getUsedCharacter
    if not char then return BridgeUtils.makeJob() end
    return BridgeUtils.makeJob(char.job, char.jobGrade)
end

---------------------------------------------------------------------------
-- Gang helpers  (from character metadata)
---------------------------------------------------------------------------

function VORPClientBridge.GetGang()
    if not _playerData then return BridgeUtils.makeGang() end
    local char = _playerData.getUsedCharacter
    if not char then return BridgeUtils.makeGang() end
    local meta = BridgeUtils.try(function() return char.getMetaData('gang') end)
    if type(meta) == 'table' then
        return BridgeUtils.makeGang(meta.name, meta.grade, meta.label, meta.gradeLabel, meta.isBoss)
    end
    return BridgeUtils.makeGang()
end

---------------------------------------------------------------------------
-- Metadata helpers
---------------------------------------------------------------------------

function VORPClientBridge.GetMetadata(key)
    if not _playerData then return nil end
    local char = _playerData.getUsedCharacter
    if not char then return nil end
    return BridgeUtils.try(function() return char.getMetaData(key) end)
end

---------------------------------------------------------------------------
-- License helpers
---------------------------------------------------------------------------

function VORPClientBridge.GetLicenses()
    local v = VORPClientBridge.GetMetadata('licenses')
    return type(v) == 'table' and v or {}
end

function VORPClientBridge.HasLicense(license)
    return VORPClientBridge.GetLicenses()[license] == true
end

---------------------------------------------------------------------------
-- Skill helpers
---------------------------------------------------------------------------

function VORPClientBridge.GetSkill(skill)
    local v = VORPClientBridge.GetMetadata('skills')
    return (type(v) == 'table' and tonumber(v[skill])) or 0
end
