-------------------------------------------------------------------
-- bcc-bridge  –  Client entrypoint
-- Detects (or reads from config) which framework is active,
-- wires the correct bridge table to the global `Bridge`, and
-- registers all client-side exports.
-------------------------------------------------------------------

--- Resolve the active framework  (mirrors server-side logic)
local function detectFramework()
    if Config.Framework ~= 'auto' then
        return Config.Framework
    end
    local order = {
        { id = 'vorp', resource = Config.Resources.vorp },
        { id = 'rsg',  resource = Config.Resources.rsg  },
    }
    for _, fw in ipairs(order) do
        if GetResourceState(fw.resource) == 'started' then
            return fw.id
        end
    end
    return 'fallback'
end

local framework = detectFramework()

if framework == 'vorp' then
    Bridge = VORPClientBridge
elseif framework == 'rsg' then
    Bridge = RSGClientBridge
else
    Bridge = FallbackClientBridge
    framework = 'fallback'
end

print(('[^2bcc-bridge^0] Client framework: ^3%s^0'):format(framework))

---------------------------------------------------------------------------
-- Server-request helper
-- Fires a net-event to the server bridge and delivers the reply via callback.
---------------------------------------------------------------------------

local _pending = {}
local _reqCounter = 0

RegisterNetEvent('bcc-bridge:response')
AddEventHandler('bcc-bridge:response', function(id, data)
    if _pending[id] then
        _pending[id](data)
        _pending[id] = nil
    end
end)

local function srv(action, payload, cb)
    _reqCounter = _reqCounter + 1
    local id = _reqCounter
    _pending[id]   = cb or function() end
    payload        = payload or {}
    payload.action = action
    payload.id     = id
    TriggerServerEvent('bcc-bridge:request', payload)
end

---------------------------------------------------------------------------
-- Instant exports  (use locally cached framework data – no round-trip)
---------------------------------------------------------------------------

exports('GetFramework',     function() return framework end)
exports('IsPlayerLoaded',   Bridge.IsPlayerLoaded)
exports('GetPlayerData',    Bridge.GetPlayerData)
exports('GetCharacterData', Bridge.GetCharacterData)
exports('GetJob',           Bridge.GetJob)
exports('GetGang',          Bridge.GetGang)
exports('GetMetadata',      Bridge.GetMetadata)
exports('GetLicenses',      Bridge.GetLicenses)
exports('HasLicense',       Bridge.HasLicense)
exports('GetSkill',         Bridge.GetSkill)
exports('GetMoney',         Bridge.GetMoney)
exports('GetItem',          Bridge.GetItem)
exports('Notify',           Bridge.Notify)
exports('TriggerCallback',      Bridge.TriggerCallback)
exports('TriggerCallbackAwait', Bridge.TriggerCallbackAwait)

---------------------------------------------------------------------------
-- Server-authoritative exports  (async – pass a callback to receive the result)
---------------------------------------------------------------------------

-- Character
exports('ServerGetCharacter', function(cb)
    srv('getCharacter', {}, cb)
end)

-- Jobs
exports('ServerGetJob', function(cb)
    srv('getJob', {}, cb)
end)
exports('ServerSetJob', function(name, grade, cb)
    srv('setJob', { name = name, grade = grade }, cb)
end)
exports('ServerGetAllJobs', function(cb)
    srv('getAllJobs', {}, cb)
end)

-- Gangs
exports('ServerGetGang', function(cb)
    srv('getGang', {}, cb)
end)
exports('ServerSetGang', function(name, grade, isBoss, cb)
    srv('setGang', { name = name, grade = grade, isBoss = isBoss }, cb)
end)
exports('ServerGetAllGangs', function(cb)
    srv('getAllGangs', {}, cb)
end)

-- Metadata
exports('ServerGetMetadata', function(key, cb)
    srv('getMetadata', { key = key }, cb)
end)
exports('ServerSetMetadata', function(key, value, cb)
    srv('setMetadata', { key = key, value = value }, cb)
end)

-- Licenses
exports('ServerGetLicenses', function(cb)
    srv('getLicenses', {}, cb)
end)
exports('ServerHasLicense', function(license, cb)
    srv('hasLicense', { license = license }, cb)
end)
exports('ServerAddLicense', function(license, cb)
    srv('addLicense', { license = license }, cb)
end)
exports('ServerRemoveLicense', function(license, cb)
    srv('removeLicense', { license = license }, cb)
end)

-- Skills
exports('ServerGetSkill', function(skill, cb)
    srv('getSkill', { skill = skill }, cb)
end)
exports('ServerSetSkill', function(skill, value, cb)
    srv('setSkill', { skill = skill, value = value }, cb)
end)
exports('ServerAddSkillXP', function(skill, amount, cb)
    srv('addSkillXP', { skill = skill, amount = amount }, cb)
end)

-- Economy
exports('ServerGetMoney', function(moneyType, cb)
    srv('getMoney', { moneyType = moneyType }, cb)
end)
exports('ServerAddMoney', function(moneyType, amount, reason, cb)
    srv('addMoney', { moneyType = moneyType, amount = amount, reason = reason }, cb)
end)
exports('ServerRemoveMoney', function(moneyType, amount, reason, cb)
    srv('removeMoney', { moneyType = moneyType, amount = amount, reason = reason }, cb)
end)

-- Inventory
exports('ServerGetItem', function(itemName, cb)
    srv('getItem', { itemName = itemName }, cb)
end)
exports('ServerAddItem', function(itemName, amount, metadata, cb)
    srv('addItem', { itemName = itemName, amount = amount, metadata = metadata }, cb)
end)
exports('ServerRemoveItem', function(itemName, amount, cb)
    srv('removeItem', { itemName = itemName, amount = amount }, cb)
end)

-- Notify (fire-and-forget)
exports('ServerNotify', function(message, notifyType, duration)
    srv('notify', { message = message, notifyType = notifyType, duration = duration })
end)
