-------------------------------------------------------------------
-- Fallback – Client-side bridge implementation (no framework)
-- Minimal stubs so dependent scripts don't hard-crash;
-- most data operations are proxied to the server-side fallback store.
-------------------------------------------------------------------

---@class FallbackClientBridge
FallbackClientBridge = {}

local _loaded = false

AddEventHandler('onClientResourceStart', function(res)
    if res == GetCurrentResourceName() then
        _loaded = true
        TriggerEvent('bcc-bridge:playerLoaded', 0)
    end
end)

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

function FallbackClientBridge.IsPlayerLoaded()
    return _loaded
end

function FallbackClientBridge.GetPlayerData()
    return { name = GetPlayerName(PlayerId()) }
end

function FallbackClientBridge.GetCharacterData()
    return BridgeUtils.makeCharacter(
        nil,
        GetPlayerName(PlayerId()) or 'Unknown',
        '',
        BridgeUtils.makeJob(),
        BridgeUtils.makeGang(),
        {}
    )
end

---------------------------------------------------------------------------
-- Economy / inventory helpers (server-backed; use Server* exports for real values)
---------------------------------------------------------------------------

function FallbackClientBridge.GetMoney(_moneyType)
    return 0
end

function FallbackClientBridge.GetItem(_itemName)
    return 0
end

---------------------------------------------------------------------------
-- Job / gang / metadata / license / skill stubs
---------------------------------------------------------------------------

function FallbackClientBridge.GetJob()
    return BridgeUtils.makeJob()
end

function FallbackClientBridge.GetGang()
    return BridgeUtils.makeGang()
end

function FallbackClientBridge.GetMetadata(_key)
    return nil
end

function FallbackClientBridge.GetLicenses()
    return {}
end

function FallbackClientBridge.HasLicense(_license)
    return false
end

function FallbackClientBridge.GetSkill(_skill)
    return 0
end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

function FallbackClientBridge.Notify(message, _notifyType, duration)
    AddTextEntry('bcc_bridge_tip', message)
    BeginTextCommandDisplayHelp('bcc_bridge_tip')
    EndTextCommandDisplayHelp(0, false, true, duration or Config.NotifyDuration)
end

-- Generic callback using the fallback net-event pattern registered in the server bridge
function FallbackClientBridge.TriggerCallback(name, cb, args)
    local cbEvent = 'bcc-bridge:cbres:' .. name
    local handler
    handler = AddEventHandler(cbEvent, function(result)
        RemoveEventHandler(handler)
        if cb then cb(result) end
    end)
    TriggerServerEvent('bcc-bridge:cb:' .. name, args or {})
end

function FallbackClientBridge.TriggerCallbackAwait(name, args)
    local p = promise.new()
    FallbackClientBridge.TriggerCallback(name, function(result)
        p:resolve(result)
    end, args)
    return Citizen.Await(p)
end

-- Listen for generic fallback notifications from the server
RegisterNetEvent('bcc-bridge:notify')
AddEventHandler('bcc-bridge:notify', function(message, notifyType, duration)
    FallbackClientBridge.Notify(message, notifyType, duration)
end)
