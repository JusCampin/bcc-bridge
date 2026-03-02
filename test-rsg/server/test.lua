-------------------------------------------------------------------
-- bcc-bridge RSG  –  Server-side test suite
--
-- HOW TO USE
--   In the server console:
--       rsg_test_all <playerId>       – runs every test for that player
--       rsg_test_economy <playerId>   – money / inventory only
--       rsg_test_character <playerId> – identity + job + gang
--       rsg_test_meta <playerId>      – metadata / licenses / skills
--
-- Each test prints PASS / FAIL with the returned value so you can
-- verify behaviour without needing a UI.
-------------------------------------------------------------------

local Bridge = exports['bcc-bridge']

-- Colour helpers for server console output
local function pass(label, val)
    local display = type(val) == 'table' and json.encode(val) or tostring(val)
    print(('[^2PASS^0] %-30s → %s'):format(label, display))
end

local function fail(label, err)
    print(('[^1FAIL^0] %-30s → %s'):format(label, tostring(err)))
end

local function header(title)
    print(('\n^5═══ %s ═══^0'):format(title))
end

-- Run a test: fn() must not throw; return value is displayed
local function run(label, fn)
    local ok, result = pcall(fn)
    if not ok then
        fail(label, result)
    else
        pass(label, result)
    end
    return result
end

---------------------------------------------------------------------------
-- Individual test groups
---------------------------------------------------------------------------

local function testFramework()
    header('FRAMEWORK')
    run('GetFramework', function()
        local fw = Bridge:GetFramework()
        assert(fw == 'rsg', 'Expected rsg, got ' .. tostring(fw))
        return fw
    end)
end

local function testPlayer(src)
    header('PLAYER')

    run('IsPlayerLoaded', function()
        local v = Bridge:IsPlayerLoaded(src)
        assert(v == true, 'Player not loaded')
        return v
    end)

    run('GetPlayer (not nil)', function()
        local p = Bridge:GetPlayer(src)
        assert(p ~= nil, 'Got nil')
        return 'object returned'
    end)

    run('GetPlayerIdentifier', function()
        local id = Bridge:GetPlayerIdentifier(src)
        assert(type(id) == 'string' and #id > 0, 'Empty identifier')
        return id
    end)
end

local function testCharacter(src)
    header('CHARACTER')

    run('GetCharacter (shape)', function()
        local c = Bridge:GetCharacter(src)
        assert(c ~= nil,                       'nil character')
        assert(type(c.firstname) == 'string',  'missing firstname')
        assert(type(c.lastname)  == 'string',  'missing lastname')
        assert(type(c.jobData)   == 'table',   'missing jobData')
        assert(type(c.gangData)  == 'table',   'missing gangData')
        assert(type(c.metadata)  == 'table',   'missing metadata')
        return ('%s %s'):format(c.firstname, c.lastname)
    end)
end

local function testJobs(src)
    header('JOBS')

    run('GetJob (initial)', function()
        local j = Bridge:GetJob(src)
        assert(type(j.name)  == 'string', 'missing name')
        assert(type(j.grade) == 'number', 'missing grade')
        return ('%s / grade %d'):format(j.name, j.grade)
    end)

    run('SetJob → unemployed / 0', function()
        local ok = Bridge:SetJob(src, 'unemployed', 0)
        assert(ok ~= false, 'SetJob returned false')
        return ok
    end)

    run('GetJob (after set)', function()
        local j = Bridge:GetJob(src)
        return ('%s / grade %d'):format(j.name, j.grade)
    end)

    run('GetAllJobs (table)', function()
        local all = Bridge:GetAllJobs()
        assert(type(all) == 'table', 'Not a table')
        local count = 0
        for _ in pairs(all) do count = count + 1 end
        return ('keys: %d'):format(count)
    end)
end

local function testGangs(src)
    header('GANGS')

    run('SetGang → outlaws / 1', function()
        local ok = Bridge:SetGang(src, 'outlaws', 1)
        assert(ok ~= false, 'SetGang returned false')
        return ok
    end)

    run('GetGang (after set)', function()
        local g = Bridge:GetGang(src)
        assert(type(g.name)  == 'string', 'missing name')
        assert(type(g.grade) == 'number', 'missing grade')
        return ('%s / grade %d'):format(g.name, g.grade)
    end)

    run('GetAllGangs (table)', function()
        local all = Bridge:GetAllGangs()
        assert(type(all) == 'table', 'Not a table')
        local count = 0
        for _ in pairs(all) do count = count + 1 end
        return ('keys: %d'):format(count)
    end)

    -- Reset
    Bridge:SetGang(src, 'none', 0)
end

local function testMetadata(src)
    header('METADATA')

    run('SetMetadata (bcc_test_key)', function()
        local ok = Bridge:SetMetadata(src, 'bcc_test_key', { value = 42 })
        assert(ok ~= false, 'SetMetadata returned false')
        return ok
    end)

    run('GetMetadata (bcc_test_key = {value=42})', function()
        local v = Bridge:GetMetadata(src, 'bcc_test_key')
        assert(type(v) == 'table' and v.value == 42, 'Value mismatch: ' .. tostring(v))
        return json.encode(v)
    end)

    -- Cleanup
    Bridge:SetMetadata(src, 'bcc_test_key', nil)
end

local function testLicenses(src)
    header('LICENSES')

    run('AddLicense (hunting)', function()
        local ok = Bridge:AddLicense(src, 'hunting')
        assert(ok ~= false, 'AddLicense returned false')
        return ok
    end)

    run('HasLicense (hunting = true)', function()
        local has = Bridge:HasLicense(src, 'hunting')
        assert(has == true, 'License not found after add')
        return has
    end)

    run('GetLicenses (contains hunting)', function()
        local tbl = Bridge:GetLicenses(src)
        assert(type(tbl) == 'table', 'Not a table')
        assert(tbl['hunting'] == true, 'hunting missing from table')
        return json.encode(tbl)
    end)

    run('RemoveLicense (hunting)', function()
        local ok = Bridge:RemoveLicense(src, 'hunting')
        assert(ok ~= false, 'RemoveLicense returned false')
        return ok
    end)

    run('HasLicense (hunting = false after remove)', function()
        local has = Bridge:HasLicense(src, 'hunting')
        assert(has == false, 'License still present after remove')
        return has
    end)
end

local function testSkills(src)
    header('SKILLS')

    run('SetSkill (dead_eye = 100)', function()
        local ok = Bridge:SetSkill(src, 'dead_eye', 100)
        assert(ok ~= false, 'SetSkill returned false')
        return ok
    end)

    run('GetSkill (dead_eye = 100)', function()
        local v = Bridge:GetSkill(src, 'dead_eye')
        assert(tonumber(v) == 100, 'Expected 100, got ' .. tostring(v))
        return v
    end)

    run('AddSkillXP (dead_eye +50)', function()
        local ok = Bridge:AddSkillXP(src, 'dead_eye', 50)
        assert(ok ~= false, 'AddSkillXP returned false')
        return ok
    end)

    run('GetSkill (dead_eye = 150 after XP)', function()
        local v = Bridge:GetSkill(src, 'dead_eye')
        assert(tonumber(v) == 150, 'Expected 150, got ' .. tostring(v))
        return v
    end)

    -- Cleanup
    Bridge:SetSkill(src, 'dead_eye', 0)
end

local function testEconomy(src)
    header('ECONOMY')

    local startCash = Bridge:GetMoney(src, 'cash')
    run('GetMoney (cash, initial)', function() return startCash end)

    run('AddMoney (cash +500)', function()
        local ok = Bridge:AddMoney(src, 'cash', 500, 'bcc-bridge rsg test')
        assert(ok ~= false, 'AddMoney returned false')
        return ok
    end)

    run('GetMoney (cash = start+500)', function()
        local v = Bridge:GetMoney(src, 'cash')
        assert(tonumber(v) == tonumber(startCash) + 500,
            ('Expected %d, got %d'):format(startCash + 500, v))
        return v
    end)

    run('RemoveMoney (cash -500)', function()
        local ok = Bridge:RemoveMoney(src, 'cash', 500, 'bcc-bridge rsg test')
        assert(ok ~= false, 'RemoveMoney returned false')
        return ok
    end)

    run('RemoveMoney insufficient (cash -99999999)', function()
        local ok = Bridge:RemoveMoney(src, 'cash', 99999999, 'bcc-bridge rsg test')
        assert(ok == false, 'Expected false for insufficient funds, got ' .. tostring(ok))
        return 'correctly refused'
    end)

    local startGold = Bridge:GetMoney(src, 'gold')
    run('GetMoney (gold, initial)', function() return startGold end)

    run('AddMoney (gold +2)', function()
        local ok = Bridge:AddMoney(src, 'gold', 2, 'bcc-bridge rsg test')
        assert(ok ~= false, 'AddMoney gold returned false')
        return ok
    end)

    run('RemoveMoney (gold -2)', function()
        local ok = Bridge:RemoveMoney(src, 'gold', 2, 'bcc-bridge rsg test')
        assert(ok ~= false, 'RemoveMoney gold returned false')
        return ok
    end)
end

local function testInventory(src)
    header('INVENTORY')

    run('AddItem (water x3)', function()
        local ok = Bridge:AddItem(src, 'water', 3)
        assert(ok ~= false, 'AddItem returned false')
        return ok
    end)

    run('GetItem (water ≥ 3)', function()
        local v = Bridge:GetItem(src, 'water')
        assert(tonumber(v) >= 3, 'Expected ≥3, got ' .. tostring(v))
        return v
    end)

    run('RemoveItem (water -3)', function()
        local ok = Bridge:RemoveItem(src, 'water', 3)
        assert(ok ~= false, 'RemoveItem returned false')
        return ok
    end)

    run('RemoveItem insufficient (water -999)', function()
        local ok = Bridge:RemoveItem(src, 'water', 999)
        assert(ok == false, 'Expected false for insufficient, got ' .. tostring(ok))
        return 'correctly refused'
    end)
end

local function testNotify(src)
    header('NOTIFICATIONS')
    run('Notify (primary)',  function() Bridge:Notify(src, '[bcc-bridge rsg test] primary',  'primary',  3000); return 'sent' end)
    run('Notify (success)',  function() Bridge:Notify(src, '[bcc-bridge rsg test] success',  'success',  3000); return 'sent' end)
    run('Notify (error)',    function() Bridge:Notify(src, '[bcc-bridge rsg test] error',    'error',    3000); return 'sent' end)
    run('Notify (warning)',  function() Bridge:Notify(src, '[bcc-bridge rsg test] warning',  'warning',  3000); return 'sent' end)
end

local function testCallback()
    header('CALLBACKS')
    run('RegisterCallback (rsg_test_cb)', function()
        Bridge:RegisterCallback('rsg_test_cb', function(src, args, ret)
            ret({ echo = args.msg, source = src })
        end)
        return 'registered'
    end)
end

---------------------------------------------------------------------------
-- Aggregated runners
---------------------------------------------------------------------------

local function runAll(src)
    print('\n^3╔══════════════════════════════════════╗^0')
    print('^3║  bcc-bridge RSG TEST SUITE (server)  ║^0')
    print('^3╚══════════════════════════════════════╝^0')
    testFramework()
    testPlayer(src)
    testCharacter(src)
    testJobs(src)
    testGangs(src)
    testMetadata(src)
    testLicenses(src)
    testSkills(src)
    testEconomy(src)
    testInventory(src)
    testNotify(src)
    testCallback()
    print('\n^2All RSG server tests complete.^0\n')
end

---------------------------------------------------------------------------
-- Console commands
---------------------------------------------------------------------------

RegisterCommand('rsg_test_all', function(_src, args)
    local target = tonumber(args[1])
    if not target then print('[bcc-bridge rsg test] Usage: rsg_test_all <playerId>'); return end
    runAll(target)
end, true)

RegisterCommand('rsg_test_economy', function(_src, args)
    local target = tonumber(args[1])
    if not target then print('[bcc-bridge rsg test] Usage: rsg_test_economy <playerId>'); return end
    testEconomy(target)
    testInventory(target)
end, true)

RegisterCommand('rsg_test_character', function(_src, args)
    local target = tonumber(args[1])
    if not target then print('[bcc-bridge rsg test] Usage: rsg_test_character <playerId>'); return end
    testPlayer(target)
    testCharacter(target)
    testJobs(target)
    testGangs(target)
end, true)

RegisterCommand('rsg_test_meta', function(_src, args)
    local target = tonumber(args[1])
    if not target then print('[bcc-bridge rsg test] Usage: rsg_test_meta <playerId>'); return end
    testMetadata(target)
    testLicenses(target)
    testSkills(target)
end, true)
