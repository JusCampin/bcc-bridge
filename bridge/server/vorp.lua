-------------------------------------------------------------------
-- VORP Core – Server-side bridge implementation
-- Exposes a unified Bridge API backed by vorp_core / vorp_inventory.
-------------------------------------------------------------------

---@class VORPServerBridge
VORPServerBridge = {}

local _core = nil

-- Ensure the custom metadata table exists on start
CreateThread(function()
    Wait(500) -- let oxmysql initialise
    exports.oxmysql:query([[
        CREATE TABLE IF NOT EXISTS `bcc_bridge_metadata` (
            `char_identifier` INT          NOT NULL,
            `meta_key`        VARCHAR(64)  NOT NULL,
            `meta_value`      LONGTEXT,
            PRIMARY KEY (`char_identifier`, `meta_key`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {})
end)

--- Lazy-load VORP core object (cached after first call)
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

--- Shorthand to the vorp_inventory export table
local function Inv()
    return exports[Config.Resources.vorp_inv]
end

--- Internal: return the raw VORP User object for a source, or nil
local function getRawUser(source)
    local c = Core()
    if not c then return nil end
    local ok, user = pcall(function() return c.getUser(source) end)
    return (ok and user) or nil
end

---------------------------------------------------------------------------
-- Player helpers
---------------------------------------------------------------------------

--- Returns the raw VORP User object
function VORPServerBridge.GetPlayer(source)
    return getRawUser(source)
end

--- Returns true when the player exists inside the framework
function VORPServerBridge.IsPlayerLoaded(source)
    return getRawUser(source) ~= nil
end

--- Returns the player's primary identifier via character.identifier
function VORPServerBridge.GetPlayerIdentifier(source)
    local user = getRawUser(source)
    if user then
        local char = user.getUsedCharacter
        if char and char.identifier then return char.identifier end
    end
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if ident and ident:find('license:') then return ident end
    end
    for i = 0, GetNumPlayerIdentifiers(source) - 1 do
        local ident = GetPlayerIdentifier(source, i)
        if ident and ident:find('steam:') then return ident end
    end
    return tostring(source)
end

--- Returns a normalised character info table
function VORPServerBridge.GetCharacter(source)
    local user = getRawUser(source)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char then return nil end
    local jobData  = BridgeUtils.makeJob(char.job, char.jobGrade)
    local gangMeta = BridgeUtils.try(function() return char.getMetaData('gang') end)
    local gangData = type(gangMeta) == 'table'
        and BridgeUtils.makeGang(gangMeta.name, gangMeta.grade, gangMeta.label, gangMeta.gradeLabel, gangMeta.isBoss)
        or  BridgeUtils.makeGang()
    local meta = BridgeUtils.try(function() return char.metadata end) or {}
    local info = BridgeUtils.makeCharacter(source, char.firstname, char.lastname, jobData, gangData, meta)
    info.identifier     = char.identifier
    info.charIdentifier = char.charIdentifier
    return info
end

---------------------------------------------------------------------------
-- Economy helpers
---------------------------------------------------------------------------

--- Returns the player's balance for the given unified money type ('cash' | 'gold')
function VORPServerBridge.GetMoney(source, moneyType)
    local user = getRawUser(source)
    if not user then return 0 end
    local char = user.getUsedCharacter
    if not char then return 0 end
    if (moneyType or 'cash') == 'gold' then
        return tonumber(char.gold) or 0
    else
        return tonumber(char.money) or 0
    end
end

--- Adds money to the player; returns true on success
function VORPServerBridge.AddMoney(source, moneyType, amount, _reason)
    local user = getRawUser(source)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char then return false end
    local t = Config.MoneyTypes.vorp[moneyType or 'cash'] or 0
    local ok = pcall(function() char.addCurrency(t, tonumber(amount) or 0) end)
    return ok
end

--- Removes money from the player; returns false when funds are insufficient
function VORPServerBridge.RemoveMoney(source, moneyType, amount, _reason)
    local amt = tonumber(amount) or 0
    if VORPServerBridge.GetMoney(source, moneyType) < amt then return false end
    local user = getRawUser(source)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char then return false end
    local t = Config.MoneyTypes.vorp[moneyType or 'cash'] or 0
    local ok = pcall(function() char.removeCurrency(t, amt) end)
    return ok
end

---------------------------------------------------------------------------
-- Inventory helpers
---------------------------------------------------------------------------

--- Returns the count of a named item in the player's inventory
function VORPServerBridge.GetItem(source, itemName)
    local p = promise.new()
    local ok = pcall(function()
        Inv():getItemCount(source, function(count)
            p:resolve(tonumber(count) or 0)
        end, itemName, nil, 0)
    end)
    if not ok then return 0 end
    return Citizen.Await(p)
end

--- Adds an item to the player's inventory; returns true on success
function VORPServerBridge.AddItem(source, itemName, amount, metadata)
    local ok = pcall(function()
        Inv():addItem(source, itemName, tonumber(amount) or 1, metadata)
    end)
    return ok
end

--- Removes an item from the player's inventory; returns false when insufficient
function VORPServerBridge.RemoveItem(source, itemName, amount)
    local amt = tonumber(amount) or 1
    if VORPServerBridge.GetItem(source, itemName) < amt then return false end
    local ok = pcall(function()
        Inv():subItem(source, itemName, amt)
    end)
    return ok
end

--- Returns the full item object (including metadata); nil if not found
function VORPServerBridge.GetItemWithMeta(source, itemName)
    local ok, result = pcall(function()
        return Inv():getItem(source, itemName)
    end)
    if ok then return result end
    return nil
end

--- Adds an item with explicit metadata
function VORPServerBridge.AddItemWithMeta(source, itemName, amount, metadata)
    local ok = pcall(function()
        Inv():addItem(source, itemName, tonumber(amount) or 1, metadata)
    end)
    return ok
end

--- Removes an item matching specific metadata
function VORPServerBridge.RemoveItemWithMeta(source, itemName, amount, metadata)
    local ok = pcall(function()
        Inv():subItem(source, itemName, tonumber(amount) or 1, metadata)
    end)
    return ok
end

--- Returns true if the player can carry the given amount of an item
function VORPServerBridge.CanCarryItem(source, itemName, amount)
    local ok, result = pcall(function()
        return Inv():canCarryItem(source, itemName, tonumber(amount) or 1)
    end)
    return ok and result == true
end

--- Registers a usable item handler
function VORPServerBridge.RegisterUsableItem(itemName, cb)
    pcall(function() Inv():registerUsableItem(itemName, cb) end)
end

--- Closes the player's inventory screen
function VORPServerBridge.CloseInventory(source)
    pcall(function() Inv():closeInventory(source) end)
end

--- Returns true if a custom inventory with the given id is already registered
function VORPServerBridge.IsCustomInventoryRegistered(id)
    local ok, result = pcall(function()
        return Inv():isCustomInventoryRegistered(id)
    end)
    return ok and result == true
end

--- Registers a custom inventory
function VORPServerBridge.RegisterInventory(data)
    pcall(function() Inv():registerInventory(data) end)
end

--- Opens a custom inventory for the player
function VORPServerBridge.OpenInventory(source, id)
    pcall(function() Inv():openInventory(source, id) end)
end

---------------------------------------------------------------------------
-- Notifications & callbacks
---------------------------------------------------------------------------

--- Sends a notification to the player.
--- notifyType: 'primary' | 'success' | 'error' | 'warning'
--- VORP only exposes TipRight (Core.NotifyRightTip); always use it regardless of type
function VORPServerBridge.Notify(source, message, notifyType, duration)
    local dur = duration or Config.NotifyDuration
    TriggerClientEvent('vorp:TipRight', source, message, dur)
end

--- Registers a named server-side callback accessible from client scripts
function VORPServerBridge.RegisterCallback(name, cb)
    Core().Callback.Register(name, function(source, callback, ...)
        -- VORP: callback = response fn, ... = args from client
        -- Bridge contract: cb(source, args, ret)
        local args = ... -- first vararg is the args table sent by TriggerAsync
        cb(source, args or {}, callback)
    end)
end

---------------------------------------------------------------------------
-- Job helpers
---------------------------------------------------------------------------

--- Returns a normalised Job table
function VORPServerBridge.GetJob(source)
    local user = getRawUser(source)
    if not user then return BridgeUtils.makeJob() end
    local char = user.getUsedCharacter
    if not char then return BridgeUtils.makeJob() end
    return BridgeUtils.makeJob(char.job, char.jobGrade)
end

--- Sets the player's job and grade; returns true on success
function VORPServerBridge.SetJob(source, jobName, grade)
    local user = getRawUser(source)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char then return false end
    return BridgeUtils.try(function() char.setJob(jobName, grade or 0); return true end, false)
end

--- VORP is config-driven; returns empty table (populate from your jobs config if needed)
function VORPServerBridge.GetAllJobs()
    return {}
end

---------------------------------------------------------------------------
-- Gang helpers  (VORP has no native gang system; stored in character metadata)
---------------------------------------------------------------------------

--- Returns a normalised Gang table
function VORPServerBridge.GetGang(source)
    local meta = VORPServerBridge.GetMetadata(source, 'gang')
    if type(meta) == 'table' then
        return BridgeUtils.makeGang(meta.name, meta.grade, meta.label, meta.gradeLabel, meta.isBoss)
    end
    return BridgeUtils.makeGang()
end

--- Sets the player's gang via character metadata
function VORPServerBridge.SetGang(source, gangName, grade, isBoss)
    return VORPServerBridge.SetMetadata(source, 'gang', {
        name   = gangName or 'none',
        grade  = tonumber(grade) or 0,
        isBoss = isBoss or false,
    }, true)
end

--- Returns empty table (gangs are user-defined in VORP)
function VORPServerBridge.GetAllGangs()
    return {}
end

---------------------------------------------------------------------------
-- Metadata helpers
---------------------------------------------------------------------------

--- Returns a character metadata value by key  (DB-backed: bcc_bridge_metadata)
function VORPServerBridge.GetMetadata(source, key)
    local user = getRawUser(source)
    if not user then return nil end
    local char = user.getUsedCharacter
    if not char then return nil end
    local charId = char.charIdentifier
    local rows = exports.oxmysql:executeSync(
        'SELECT meta_value FROM bcc_bridge_metadata WHERE char_identifier = ? AND meta_key = ?',
        { charId, key }
    )
    if rows and rows[1] and rows[1].meta_value then
        return json.decode(rows[1].meta_value)
    end
    return nil
end

--- Sets a character metadata value (DB-backed: bcc_bridge_metadata)
function VORPServerBridge.SetMetadata(source, key, value, _drop)
    local user = getRawUser(source)
    if not user then return false end
    local char = user.getUsedCharacter
    if not char then return false end
    local charId = char.charIdentifier
    local ok = pcall(function()
        exports.oxmysql:executeSync(
            [[ INSERT INTO bcc_bridge_metadata (char_identifier, meta_key, meta_value)
               VALUES (?, ?, ?)
               ON DUPLICATE KEY UPDATE meta_value = VALUES(meta_value) ]],
            { charId, key, json.encode(value) }
        )
    end)
    return ok
end

---------------------------------------------------------------------------
-- License helpers  (stored under metadata key 'licenses')
---------------------------------------------------------------------------

local function _vLicenses(source)
    local v = VORPServerBridge.GetMetadata(source, 'licenses')
    return type(v) == 'table' and v or {}
end

--- Returns the full licenses table  { [name] = true }
function VORPServerBridge.GetLicenses(source)
    return _vLicenses(source)
end

--- Returns true when the player holds the given license
function VORPServerBridge.HasLicense(source, license)
    return _vLicenses(source)[license] == true
end

--- Grants a license
function VORPServerBridge.AddLicense(source, license)
    local tbl = _vLicenses(source)
    tbl[license] = true
    return VORPServerBridge.SetMetadata(source, 'licenses', tbl, true)
end

--- Revokes a license
function VORPServerBridge.RemoveLicense(source, license)
    local tbl = _vLicenses(source)
    tbl[license] = nil
    return VORPServerBridge.SetMetadata(source, 'licenses', tbl, true)
end

---------------------------------------------------------------------------
-- Skill helpers  (stored under metadata key 'skills')
---------------------------------------------------------------------------

local function _vSkills(source)
    local v = VORPServerBridge.GetMetadata(source, 'skills')
    return type(v) == 'table' and v or {}
end

--- Returns the current value of a skill (0 if unset)
function VORPServerBridge.GetSkill(source, skill)
    return tonumber(_vSkills(source)[skill]) or 0
end

--- Sets a skill to an exact value
function VORPServerBridge.SetSkill(source, skill, value)
    local tbl = _vSkills(source)
    tbl[skill] = tonumber(value) or 0
    return VORPServerBridge.SetMetadata(source, 'skills', tbl, true)
end

--- Adds XP/points to a skill (negative amounts reduce it)
function VORPServerBridge.AddSkillXP(source, skill, amount)
    local cur = VORPServerBridge.GetSkill(source, skill)
    return VORPServerBridge.SetSkill(source, skill, cur + (tonumber(amount) or 0))
end
