-------------------------------------------------------------------
-- bcc-bridge  –  Shared utility functions
-- Available on both client and server (loaded via shared_scripts).
-------------------------------------------------------------------

BridgeUtils = {}

--- Safe pcall wrapper; returns value or fallback on error
function BridgeUtils.try(fn, fallback)
    local ok, result = pcall(fn)
    if ok then return result end
    return fallback
end

--- Clamp a number between min and max
function BridgeUtils.clamp(value, min, max)
    return math.max(min, math.min(max, tonumber(value) or 0))
end

--- Returns true when a resource is currently started
function BridgeUtils.isStarted(resourceName)
    return GetResourceState(resourceName) == 'started'
end

--- Deep-copy a table (shallow one level)
function BridgeUtils.shallowCopy(t)
    if type(t) ~= 'table' then return t end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

--- Merge table `src` into table `dst` (top-level keys only)
function BridgeUtils.merge(dst, src)
    if type(src) ~= 'table' then return dst end
    for k, v in pairs(src) do dst[k] = v end
    return dst
end

--- Build a unified Job table from raw pieces
function BridgeUtils.makeJob(name, grade, label, gradeLabel, isBoss)
    return {
        name       = name       or 'unemployed',
        grade      = tonumber(grade) or 0,
        label      = label      or '',
        gradeLabel = gradeLabel or '',
        isBoss     = isBoss     or false,
    }
end

--- Build a unified Gang table from raw pieces
function BridgeUtils.makeGang(name, grade, label, gradeLabel, isBoss)
    return {
        name       = name       or 'none',
        grade      = tonumber(grade) or 0,
        label      = label      or '',
        gradeLabel = gradeLabel or '',
        isBoss     = isBoss     or false,
    }
end

--- Build a unified Character table
function BridgeUtils.makeCharacter(source, firstname, lastname, jobData, gangData, metadata)
    local job  = jobData  or BridgeUtils.makeJob()
    local gang = gangData or BridgeUtils.makeGang()
    return {
        source    = source,
        firstname = firstname or '',
        lastname  = lastname  or '',
        -- Flat compat fields (legacy)
        job       = job.name,
        jobGrade  = job.grade,
        -- Rich sub-tables
        jobData   = job,
        gangData  = gang,
        metadata  = metadata or {},
    }
end
