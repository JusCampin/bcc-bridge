-------------------------------------------------------------------
-- RSG Framework – Server-side bridge implementation
-- Exposes a unified Bridge API backed by rsg-core.
-------------------------------------------------------------------

---@class RSGServerBridge
RSGServerBridge = {}

local _core = nil

--- Lazy-load RSG core object (cached after first call)
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

--- Internal: return the raw RSG Player object for a source, or nil
local function getRawPlayer(source)
    local c = Core()
    if not c then return nil end
    local ok, player = pcall(function() return c.Functions.GetPlayer(source) end)
    return (ok and player) or nil
end

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

--- Returns the raw RSG Player object
function RSGServerBridge.GetPlayer(source)
    return getRawPlayer(source)
end

--- Returns true when the player exists inside the framework
function RSGServerBridge.IsPlayerLoaded(source)
    return getRawPlayer(source) ~= nil
end

--- Returns the player's primary identifier
function RSGServerBridge.GetPlayerIdentifier(source)
    local player = getRawPlayer(source)
    if player and player.PlayerData then
        local pd = player.PlayerData
        if pd.license then return pd.license end
        if pd.citizenid then return pd.citizenid end
    end
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if ident and ident:find('license:') then return ident end
    end
    return tostring(source)
end

--- Returns a normalised character info table
function RSGServerBridge.GetCharacter(source)
    local player = getRawPlayer(source)
    if not player or not player.PlayerData then return nil end
    local pd    = player.PlayerData
    local ci    = pd.charinfo or {}
    local job   = pd.job      or {}
    local gang  = pd.gang     or {}
    local jg    = job.grade   or {}
    local gg    = gang.grade  or {}
    local jobData  = BridgeUtils.makeJob(job.name, jg.level, job.label, jg.label, job.isboss)
    local gangData = BridgeUtils.makeGang(gang.name, gg.level, gang.label, gg.label, gang.isboss)
    return BridgeUtils.makeCharacter(source, ci.firstname, ci.lastname, jobData, gangData, pd.metadata or {})
end

---------------------------------------------------------------------------
-- Economy helpers
---------------------------------------------------------------------------

--- Returns the player's balance for the given unified money type ('cash' | 'gold')
function RSGServerBridge.GetMoney(source, moneyType)
    local player = getRawPlayer(source)
    if not player then return 0 end
    local t = Config.MoneyTypes.rsg[moneyType or 'cash'] or 'cash'
    local ok, amt = pcall(function() return player.Functions.GetMoney(t) end)
    return (ok and tonumber(amt)) or 0
end

--- Adds money to the player; returns true on success
function RSGServerBridge.AddMoney(source, moneyType, amount, reason)
    local player = getRawPlayer(source)
    if not player then return false end
    local t = Config.MoneyTypes.rsg[moneyType or 'cash'] or 'cash'
    local ok = pcall(function()
        player.Functions.AddMoney(t, tonumber(amount) or 0, reason or 'bcc-bridge')
    end)
    return ok
end

--- Removes money from the player; returns false when funds are insufficient
function RSGServerBridge.RemoveMoney(source, moneyType, amount, reason)
    local player = getRawPlayer(source)
    if not player then return false end
    local t = Config.MoneyTypes.rsg[moneyType or 'cash'] or 'cash'
    local ok, result = pcall(function()
        return player.Functions.RemoveMoney(t, tonumber(amount) or 0, reason or 'bcc-bridge')
    end)
    return ok and (result ~= false)
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------

--- Returns the count of a named item in the player's inventory
function RSGServerBridge.GetItem(source, itemName)
    local player = getRawPlayer(source)
    if not player then return 0 end
    local ok, item = pcall(function()
        return player.Functions.GetItemByName(itemName)
    end)
    if ok and item then
        return tonumber(item.amount or item.count or 0)
    end
    return 0
end

--- Adds an item to the player's inventory; returns true on success
function RSGServerBridge.AddItem(source, itemName, amount, metadata)
    local player = getRawPlayer(source)
    if not player then return false end
    local ok = pcall(function()
        player.Functions.AddItem(itemName, tonumber(amount) or 1, nil, metadata)
    end)
    return ok
end

--- Removes an item from the player's inventory; returns false when insufficient
function RSGServerBridge.RemoveItem(source, itemName, amount)
    if RSGServerBridge.GetItem(source, itemName) < (tonumber(amount) or 1) then
        return false
    end
    local player = getRawPlayer(source)
    if not player then return false end
    local ok = pcall(function()
        player.Functions.RemoveItem(itemName, tonumber(amount) or 1)
    end)
    return ok
end

--- Returns the full item object (including metadata); nil if not found
function RSGServerBridge.GetItemWithMeta(source, itemName)
    local player = getRawPlayer(source)
    if not player then return nil end
    local ok, item = pcall(function()
        return player.Functions.GetItemByName(itemName)
    end)
    return (ok and item) and item or nil
end

function RSGServerBridge.AddItemWithMeta(source, itemName, amount, metadata)
    return RSGServerBridge.AddItem(source, itemName, amount, metadata)
end

function RSGServerBridge.RemoveItemWithMeta(source, itemName, amount, _metadata)
    return RSGServerBridge.RemoveItem(source, itemName, amount)
end

function RSGServerBridge.CanCarryItem(source, itemName, amount)
    local player = getRawPlayer(source)
    if not player then return false end
    local ok, result = pcall(function()
        return player.Functions.CanAddItem(itemName, tonumber(amount) or 1)
    end)
    return ok and result == true
end

function RSGServerBridge.RegisterUsableItem(itemName, cb)
    local c = Core()
    if not c then return end
    pcall(function() c.Functions.CreateUseableItem(itemName, cb) end)
end

function RSGServerBridge.CloseInventory(_source) end

function RSGServerBridge.IsCustomInventoryRegistered(_id)
    return false
end

function RSGServerBridge.RegisterInventory(_data) end

function RSGServerBridge.OpenInventory(_source, _id) end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

--- Sends a notification to the player.
--- notifyType: 'primary' | 'success' | 'error' | 'warning'
function RSGServerBridge.Notify(source, message, notifyType, duration)
    TriggerClientEvent('rsg-core:notify', source, message, notifyType or 'primary', duration or Config.NotifyDuration)
end

--- Registers a named server-side callback accessible from client scripts
function RSGServerBridge.RegisterCallback(name, cb)
    Core().Functions.CreateCallback(name, function(source, ret, ...)
        -- First vararg is the args table sent by TriggerCallback (matches VORP bridge contract)
        local args = ...
        cb(source, args or {}, ret)
    end)
end

---------------------------------------------------------------------------
-- Job helpers
---------------------------------------------------------------------------

--- Returns a normalised Job table
function RSGServerBridge.GetJob(source)
    local player = getRawPlayer(source)
    if not player or not player.PlayerData then return BridgeUtils.makeJob() end
    local job = player.PlayerData.job or {}
    local g   = job.grade or {}
    return BridgeUtils.makeJob(job.name, g.level, job.label, g.label, job.isboss)
end

--- Sets the player's job and grade
function RSGServerBridge.SetJob(source, jobName, grade)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function() player.Functions.SetJob(jobName, grade or 0); return true end, false)
end

--- Returns all registered jobs from rsg-core shared data
function RSGServerBridge.GetAllJobs()
    local c = Core()
    if not c then return {} end
    return BridgeUtils.try(function() return c.Shared.Jobs end) or {}
end

---------------------------------------------------------------------------
-- Gang helpers
---------------------------------------------------------------------------

--- Returns a normalised Gang table
function RSGServerBridge.GetGang(source)
    local player = getRawPlayer(source)
    if not player or not player.PlayerData then return BridgeUtils.makeGang() end
    local gang = player.PlayerData.gang or {}
    local g    = gang.grade or {}
    return BridgeUtils.makeGang(gang.name, g.level, gang.label, g.label, gang.isboss)
end

--- Sets the player's gang and grade
function RSGServerBridge.SetGang(source, gangName, grade, _isBoss)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function() player.Functions.SetGang(gangName, grade or 0); return true end, false)
end

--- Returns all registered gangs from rsg-core shared data
function RSGServerBridge.GetAllGangs()
    local c = Core()
    if not c then return {} end
    return BridgeUtils.try(function() return c.Shared.Gangs end) or {}
end

---------------------------------------------------------------------------
-- Metadata helpers
---------------------------------------------------------------------------

--- Returns a metadata value by key
function RSGServerBridge.GetMetadata(source, key)
    local player = getRawPlayer(source)
    if not player then return nil end
    return BridgeUtils.try(function() return player.Functions.GetMetaData(key) end)
end

--- Sets a metadata value
function RSGServerBridge.SetMetadata(source, key, value, _drop)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function() player.Functions.SetMetaData(key, value); return true end, false)
end

---------------------------------------------------------------------------
-- License helpers  (stored in metadata under key 'licenses')
---------------------------------------------------------------------------

local function _rLicenses(source)
    local v = RSGServerBridge.GetMetadata(source, 'licenses')
    return type(v) == 'table' and v or {}
end

--- Returns the full licenses table  { [name] = true }
function RSGServerBridge.GetLicenses(source)
    return _rLicenses(source)
end

--- Returns true when the player holds the given license
function RSGServerBridge.HasLicense(source, license)
    return _rLicenses(source)[license] == true
end

--- Grants a license
function RSGServerBridge.AddLicense(source, license)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function()
        local tbl = player.Functions.GetMetaData('licenses') or {}
        tbl[license] = true
        player.Functions.SetMetaData('licenses', tbl)
        return true
    end, false)
end

--- Revokes a license
function RSGServerBridge.RemoveLicense(source, license)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function()
        local tbl = player.Functions.GetMetaData('licenses') or {}
        tbl[license] = nil
        player.Functions.SetMetaData('licenses', tbl)
        return true
    end, false)
end

---------------------------------------------------------------------------
-- Skill helpers  (stored in metadata under key 'skills')
---------------------------------------------------------------------------

local function _rSkills(source)
    local v = RSGServerBridge.GetMetadata(source, 'skills')
    return type(v) == 'table' and v or {}
end

--- Returns the current value of a skill (0 if unset)
function RSGServerBridge.GetSkill(source, skill)
    return tonumber(_rSkills(source)[skill]) or 0
end

--- Sets a skill to an exact value
function RSGServerBridge.SetSkill(source, skill, value)
    local player = getRawPlayer(source)
    if not player then return false end
    return BridgeUtils.try(function()
        local tbl = player.Functions.GetMetaData('skills') or {}
        tbl[skill] = tonumber(value) or 0
        player.Functions.SetMetaData('skills', tbl)
        return true
    end, false)
end

--- Adds XP/points to a skill (negative amounts reduce it)
function RSGServerBridge.AddSkillXP(source, skill, amount)
    local cur = RSGServerBridge.GetSkill(source, skill)
    return RSGServerBridge.SetSkill(source, skill, cur + (tonumber(amount) or 0))
end
