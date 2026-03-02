-------------------------------------------------------------------
-- bcc-bridge VORP  –  Client-side test suite
--
-- HOW TO USE  (in-game chat commands, requires ace permission or open perms)
--   /vorp_test_client_all      – runs every instant + async test
--   /vorp_test_client_instant  – instant / cached exports only
--   /vorp_test_client_async    – Server* async exports only
--
-- Results are printed to the client's F8 console.
-------------------------------------------------------------------

local Bridge = exports['bcc-bridge']

-- Console helpers
local function pass(label, val)
    local display = type(val) == 'table' and json.encode(val) or tostring(val)
    print(('[^2PASS^0] %-34s → %s'):format(label, display))
end

local function fail(label, err)
    print(('[^1FAIL^0] %-34s → %s'):format(label, tostring(err)))
end

local function header(title)
    print(('\n^5═══ %s ═══^0'):format(title))
end

local function run(label, fn)
    local ok, result = pcall(fn)
    if not ok then fail(label, result) else pass(label, result) end
    return result
end

-- Async wrapper: calls fn(done) and waits via Citizen.Await
local function runAsync(label, fn)
    local p = promise.new()
    local ok, err = pcall(fn, function(result, assertFn)
        local aok, aerr = pcall(assertFn or function() end, result)
        if aok then
            pass(label, result)
        else
            fail(label, aerr)
        end
        p:resolve(result)
    end)
    if not ok then fail(label, err); return end
    return Citizen.Await(p)
end

---------------------------------------------------------------------------
-- Instant export tests
---------------------------------------------------------------------------

local function testInstant()
    print('\n^3── Instant (cached) exports ──^0')

    run('GetFramework', function()
        local fw = Bridge:GetFramework()
        assert(fw == 'vorp', 'Expected vorp, got ' .. tostring(fw))
        return fw
    end)

    run('IsPlayerLoaded', function()
        local v = Bridge:IsPlayerLoaded()
        assert(type(v) == 'boolean', 'Expected boolean')
        return v
    end)

    run('GetPlayerData', function()
        local d = Bridge:GetPlayerData()
        if not d then return 'nil (spawn pending — expected before vorp:playerSpawn)' end
        return 'object returned'
    end)

    run('GetCharacterData (shape)', function()
        local c = Bridge:GetCharacterData()
        if not c then return 'not loaded yet (spawn pending)' end
        assert(type(c.firstname) == 'string', 'missing firstname')
        assert(type(c.jobData)   == 'table',  'missing jobData')
        assert(type(c.gangData)  == 'table',  'missing gangData')
        return ('%s %s'):format(c.firstname, c.lastname)
    end)

    run('GetJob (shape)', function()
        local j = Bridge:GetJob()
        assert(type(j.name)  == 'string', 'missing name')
        assert(type(j.grade) == 'number', 'missing grade')
        return ('%s / grade %d'):format(j.name, j.grade)
    end)

    run('GetGang (shape)', function()
        local g = Bridge:GetGang()
        assert(type(g.name)  == 'string', 'missing name')
        assert(type(g.grade) == 'number', 'missing grade')
        return ('%s / grade %d'):format(g.name, g.grade)
    end)

    run('GetMetadata (no crash)', function()
        local v = Bridge:GetMetadata('bcc_test_nonexistent_key')
        return tostring(v)  -- nil is fine
    end)

    run('GetLicenses (table)', function()
        local tbl = Bridge:GetLicenses()
        assert(type(tbl) == 'table', 'Not a table')
        return json.encode(tbl)
    end)

    run('HasLicense (boolean)', function()
        local v = Bridge:HasLicense('nonexistent_lic')
        assert(type(v) == 'boolean', 'Expected boolean')
        return v
    end)

    run('GetSkill (number)', function()
        local v = Bridge:GetSkill('dead_eye')
        assert(type(v) == 'number', 'Expected number')
        return v
    end)

    run('GetMoney cash (number)', function()
        local v = Bridge:GetMoney('cash')
        assert(type(v) == 'number', 'Expected number')
        return v
    end)

    run('GetMoney gold (number)', function()
        local v = Bridge:GetMoney('gold')
        assert(type(v) == 'number', 'Expected number')
        return v
    end)

    run('GetItem water (number)', function()
        local v = Bridge:GetItem('water')
        assert(type(v) == 'number', 'Expected number')
        return v
    end)

    run('Notify (primary)', function()
        Bridge:Notify('[bcc-bridge vorp client test] primary', 'primary', 3000)
        return 'sent'
    end)

    run('Notify (success)', function()
        Bridge:Notify('[bcc-bridge vorp client test] success', 'success', 3000)
        return 'sent'
    end)

    run('Notify (error)', function()
        Bridge:Notify('[bcc-bridge vorp client test] error', 'error', 3000)
        return 'sent'
    end)

    run('Notify (warning)', function()
        Bridge:Notify('[bcc-bridge vorp client test] warning', 'warning', 3000)
        return 'sent'
    end)

    -- TriggerCallback test against the 'vorp_test_cb' registered in server/test.lua
    run('TriggerCallback (vorp_test_cb)', function()
        Bridge:TriggerCallback('vorp_test_cb', function(result)
            if result then
                pass('TriggerCallback → response', result)
            else
                fail('TriggerCallback → response', 'nil result')
            end
        end, { msg = 'hello from client' })
        return 'triggered (response async)'
    end)
end

---------------------------------------------------------------------------
-- Async (Server*) export tests
---------------------------------------------------------------------------

local function testAsync()
    print('\n^3── Server-authoritative (async) exports ──^0')

    runAsync('ServerGetCharacter', function(done)
        Bridge:ServerGetCharacter(function(c)
            done(c, function(v)
                assert(v ~= nil, 'nil character')
                assert(type(v.firstname) == 'string', 'missing firstname')
            end)
        end)
    end)

    runAsync('ServerGetJob', function(done)
        Bridge:ServerGetJob(function(j)
            done(j, function(v)
                assert(v ~= nil, 'nil job')
                assert(type(v.name) == 'string', 'missing name')
            end)
        end)
    end)

    runAsync('ServerSetJob (unemployed/0)', function(done)
        Bridge:ServerSetJob('unemployed', 0, function(result)
            done(result, function() end)  -- result may be nil/true depending on bridge
        end)
    end)

    runAsync('ServerGetAllJobs', function(done)
        Bridge:ServerGetAllJobs(function(all)
            done(all, function(v)
                assert(type(v) == 'table', 'Not a table')
            end)
        end)
    end)

    runAsync('ServerGetGang', function(done)
        Bridge:ServerGetGang(function(g)
            done(g, function(v)
                assert(v ~= nil, 'nil gang')
                assert(type(v.name) == 'string', 'missing name')
            end)
        end)
    end)

    runAsync('ServerSetGang (none/0)', function(done)
        Bridge:ServerSetGang('none', 0, false, function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerGetAllGangs', function(done)
        Bridge:ServerGetAllGangs(function(all)
            done(all, function(v)
                assert(type(v) == 'table', 'Not a table')
            end)
        end)
    end)

    runAsync('ServerSetMetadata (bcc_async_test)', function(done)
        Bridge:ServerSetMetadata('bcc_async_test', { x = 99 }, function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerGetMetadata (bcc_async_test)', function(done)
        Bridge:ServerGetMetadata('bcc_async_test', function(v)
            done(v, function(val)
                assert(type(val) == 'table' and val.x == 99,
                    'Expected {x=99}, got ' .. tostring(json.encode(val)))
            end)
        end)
    end)

    runAsync('ServerAddLicense (hunting)', function(done)
        Bridge:ServerAddLicense('hunting', function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerHasLicense (hunting=true)', function(done)
        Bridge:ServerHasLicense('hunting', function(has)
            done(has, function(v)
                assert(v == true, 'Expected true after add')
            end)
        end)
    end)

    runAsync('ServerGetLicenses (contains hunting)', function(done)
        Bridge:ServerGetLicenses(function(tbl)
            done(tbl, function(v)
                assert(type(v) == 'table', 'Not a table')
                assert(v['hunting'] == true, 'hunting missing')
            end)
        end)
    end)

    runAsync('ServerRemoveLicense (hunting)', function(done)
        Bridge:ServerRemoveLicense('hunting', function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerHasLicense (hunting=false after remove)', function(done)
        Bridge:ServerHasLicense('hunting', function(has)
            done(has, function(v)
                assert(v == false, 'Expected false after remove')
            end)
        end)
    end)

    runAsync('ServerSetSkill (dead_eye=200)', function(done)
        Bridge:ServerSetSkill('dead_eye', 200, function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerGetSkill (dead_eye=200)', function(done)
        Bridge:ServerGetSkill('dead_eye', function(v)
            done(v, function(val)
                assert(tonumber(val) == 200, 'Expected 200, got ' .. tostring(val))
            end)
        end)
    end)

    runAsync('ServerAddSkillXP (dead_eye +25)', function(done)
        Bridge:ServerAddSkillXP('dead_eye', 25, function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerGetSkill (dead_eye=225 after XP)', function(done)
        Bridge:ServerGetSkill('dead_eye', function(v)
            done(v, function(val)
                assert(tonumber(val) == 225, 'Expected 225, got ' .. tostring(val))
            end)
        end)
    end)

    -- Reset skill
    Bridge:ServerSetSkill('dead_eye', 0, function() end)

    runAsync('ServerGetMoney (cash)', function(done)
        Bridge:ServerGetMoney('cash', function(v)
            done(v, function(val)
                assert(type(tonumber(val)) == 'number', 'Not a number')
            end)
        end)
    end)

    runAsync('ServerAddMoney (cash +100)', function(done)
        Bridge:ServerAddMoney('cash', 100, 'bcc-bridge vorp async test', function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerRemoveMoney (cash -100)', function(done)
        Bridge:ServerRemoveMoney('cash', 100, 'bcc-bridge vorp async test', function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerGetItem (water)', function(done)
        Bridge:ServerGetItem('water', function(v)
            done(v, function(val)
                assert(type(tonumber(val)) == 'number', 'Not a number')
            end)
        end)
    end)

    runAsync('ServerAddItem (water x2)', function(done)
        Bridge:ServerAddItem('water', 2, nil, function(result)
            done(result, function() end)
        end)
    end)

    runAsync('ServerRemoveItem (water x2)', function(done)
        Bridge:ServerRemoveItem('water', 2, function(result)
            done(result, function() end)
        end)
    end)

    Bridge:ServerNotify('[bcc-bridge vorp async test] ServerNotify sent', 'success', 3000)
    pass('ServerNotify', 'fire-and-forget sent')
end

---------------------------------------------------------------------------
-- Chat commands (must be spawned in a thread for Citizen.Await to work)
---------------------------------------------------------------------------

RegisterCommand('vorp_test_client_all', function()
    Citizen.CreateThread(function()
        print('\n^3╔═══════════════════════════════════════╗^0')
        print('^3║ bcc-bridge VORP TEST SUITE (client)   ║^0')
        print('^3╚═══════════════════════════════════════╝^0')
        header('INSTANT EXPORTS')
        testInstant()
        header('ASYNC EXPORTS')
        testAsync()
        print('\n^2All client tests complete.^0\n')
    end)
end, false)

RegisterCommand('vorp_test_client_instant', function()
    Citizen.CreateThread(function()
        header('INSTANT EXPORTS')
        testInstant()
        print('^2Done.^0')
    end)
end, false)

RegisterCommand('vorp_test_client_async', function()
    Citizen.CreateThread(function()
        header('ASYNC EXPORTS')
        testAsync()
        print('^2Done.^0')
    end)
end, false)
