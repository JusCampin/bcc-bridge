-------------------------------------------------------------------
-- bcc-bridge  –  Server entrypoint
-- Detects (or reads from config) which framework is active,
-- wires the correct bridge table to the global `Bridge`, and
-- registers all exports so other resources can call them directly.
-------------------------------------------------------------------

--- Auto-detect the active framework by checking running resources
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
    Bridge = VORPServerBridge
elseif framework == 'rsg' then
    Bridge = RSGServerBridge
else
    Bridge = FallbackServerBridge
    framework = 'fallback'
end

print(('[^2bcc-bridge^0] Active framework: ^3%s^0'):format(framework))

---------------------------------------------------------------------------
-- Resource exports  (callable from other server resources)
---------------------------------------------------------------------------

exports('GetFramework',        function() return framework end)
exports('GetPlayer',           Bridge.GetPlayer)
exports('IsPlayerLoaded',      Bridge.IsPlayerLoaded)
exports('GetPlayerIdentifier', Bridge.GetPlayerIdentifier)
exports('GetCharacter',        Bridge.GetCharacter)
-- Jobs
exports('GetJob',              Bridge.GetJob)
exports('SetJob',              Bridge.SetJob)
exports('GetAllJobs',          Bridge.GetAllJobs)
-- Gangs
exports('GetGang',             Bridge.GetGang)
exports('SetGang',             Bridge.SetGang)
exports('GetAllGangs',         Bridge.GetAllGangs)
-- Metadata
exports('GetMetadata',         Bridge.GetMetadata)
exports('SetMetadata',         Bridge.SetMetadata)
-- Licenses
exports('GetLicenses',         Bridge.GetLicenses)
exports('HasLicense',          Bridge.HasLicense)
exports('AddLicense',          Bridge.AddLicense)
exports('RemoveLicense',       Bridge.RemoveLicense)
-- Skills
exports('GetSkill',            Bridge.GetSkill)
exports('SetSkill',            Bridge.SetSkill)
exports('AddSkillXP',          Bridge.AddSkillXP)
-- Economy
exports('GetMoney',            Bridge.GetMoney)
exports('AddMoney',            Bridge.AddMoney)
exports('RemoveMoney',         Bridge.RemoveMoney)
-- Inventory
exports('GetItem',                      Bridge.GetItem)
exports('AddItem',                      Bridge.AddItem)
exports('RemoveItem',                   Bridge.RemoveItem)
exports('GetItemWithMeta',              Bridge.GetItemWithMeta)
exports('AddItemWithMeta',              Bridge.AddItemWithMeta)
exports('RemoveItemWithMeta',           Bridge.RemoveItemWithMeta)
exports('CanCarryItem',                 Bridge.CanCarryItem)
exports('RegisterUsableItem',           Bridge.RegisterUsableItem)
exports('CloseInventory',               Bridge.CloseInventory)
exports('IsCustomInventoryRegistered',  Bridge.IsCustomInventoryRegistered)
exports('RegisterInventory',            Bridge.RegisterInventory)
exports('OpenInventory',                Bridge.OpenInventory)
-- Misc
exports('Notify',              Bridge.Notify)
exports('RegisterCallback',    Bridge.RegisterCallback)

---------------------------------------------------------------------------
-- Client-initiated server request handler
---------------------------------------------------------------------------

RegisterNetEvent('bcc-bridge:request')
AddEventHandler('bcc-bridge:request', function(req)
    local src = source -- luacheck: ignore
    if not req or not req.action or not req.id then return end
    local res = nil

    if     req.action == 'getCharacter'   then res = Bridge.GetCharacter(src)
    elseif req.action == 'getJob'         then res = Bridge.GetJob(src)
    elseif req.action == 'setJob'         then res = Bridge.SetJob(src, req.name, req.grade)
    elseif req.action == 'getAllJobs'     then res = Bridge.GetAllJobs()
    elseif req.action == 'getGang'        then res = Bridge.GetGang(src)
    elseif req.action == 'setGang'        then res = Bridge.SetGang(src, req.name, req.grade, req.isBoss)
    elseif req.action == 'getAllGangs'    then res = Bridge.GetAllGangs()
    elseif req.action == 'getMetadata'   then res = Bridge.GetMetadata(src, req.key)
    elseif req.action == 'setMetadata'   then res = Bridge.SetMetadata(src, req.key, req.value)
    elseif req.action == 'getLicenses'   then res = Bridge.GetLicenses(src)
    elseif req.action == 'hasLicense'    then res = Bridge.HasLicense(src, req.license)
    elseif req.action == 'addLicense'    then res = Bridge.AddLicense(src, req.license)
    elseif req.action == 'removeLicense' then res = Bridge.RemoveLicense(src, req.license)
    elseif req.action == 'getSkill'      then res = Bridge.GetSkill(src, req.skill)
    elseif req.action == 'setSkill'      then res = Bridge.SetSkill(src, req.skill, req.value)
    elseif req.action == 'addSkillXP'    then res = Bridge.AddSkillXP(src, req.skill, req.amount)
    elseif req.action == 'getMoney'      then res = Bridge.GetMoney(src, req.moneyType)
    elseif req.action == 'addMoney'      then res = Bridge.AddMoney(src, req.moneyType, req.amount, req.reason)
    elseif req.action == 'removeMoney'   then res = Bridge.RemoveMoney(src, req.moneyType, req.amount, req.reason)
    elseif req.action == 'getItem'       then res = Bridge.GetItem(src, req.itemName)
    elseif req.action == 'addItem'       then res = Bridge.AddItem(src, req.itemName, req.amount, req.metadata)
    elseif req.action == 'removeItem'    then res = Bridge.RemoveItem(src, req.itemName, req.amount)
    elseif req.action == 'notify'        then Bridge.Notify(src, req.message, req.notifyType, req.duration)
    end

    TriggerClientEvent('bcc-bridge:response', src, req.id, res)
end)
