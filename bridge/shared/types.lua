-------------------------------------------------------------------
-- bcc-bridge  –  Type documentation & shared constants
-- This file is purely for annotations; no runtime logic.
-------------------------------------------------------------------

--[[
═══════════════════════════════════════════════════════════════════
  UNIFIED DATA STRUCTURES
  All functions in every bridge implementation must conform to
  these shapes so consuming resources are framework-agnostic.
═══════════════════════════════════════════════════════════════════

  Character  (returned by GetCharacter / GetCharacterData)
  ─────────────────────────────────────────────────────────
  {
      source    : number          -- server player source id
      firstname : string
      lastname  : string
      job       : string          -- flat compat – job name
      jobGrade  : number          -- flat compat – grade level
      jobData   : Job             -- full job table (see below)
      gangData  : Gang            -- full gang table (see below)
      metadata  : table<string,any>
  }

  Job  (returned by GetJob)
  ─────────────────────────
  {
      name       : string         -- internal key  e.g. 'sheriff'
      grade      : number         -- numeric grade level
      label      : string         -- human-readable job name
      gradeLabel : string         -- human-readable grade name
      isBoss     : boolean
  }

  Gang  (returned by GetGang)
  ────────────────────────────
  {
      name       : string         -- internal key  e.g. 'lemoyne_raiders'
      grade      : number
      label      : string
      gradeLabel : string
      isBoss     : boolean
  }

  Licenses  (returned by GetLicenses)
  ─────────────────────────────────────
  table<string, boolean>          -- e.g. { hunting = true, firearm = true }

  Skills  (returned by GetSkill / per-key)
  ─────────────────────────────────────────
  number                          -- raw xp / level value; 0 if unset

  Money types (used in Get/Add/RemoveMoney)
  ──────────────────────────────────────────
  'cash'  – paper money / dollars
  'gold'  – gold nuggets / premium currency

  Notification types (used in Notify)
  ─────────────────────────────────────
  'primary'   – neutral/info (default)
  'success'   – green
  'error'     – red
  'warning'   – orange/yellow

═══════════════════════════════════════════════════════════════════
  SERVER EXPORTS  (callable from other server scripts)
═══════════════════════════════════════════════════════════════════

  exports['bcc-bridge']:GetFramework()                 → string
  exports['bcc-bridge']:GetPlayer(src)                 → raw framework player object
  exports['bcc-bridge']:IsPlayerLoaded(src)            → boolean
  exports['bcc-bridge']:GetPlayerIdentifier(src)       → string
  exports['bcc-bridge']:GetCharacter(src)              → Character
  exports['bcc-bridge']:GetJob(src)                    → Job
  exports['bcc-bridge']:SetJob(src, name, grade)       → boolean
  exports['bcc-bridge']:GetAllJobs()                   → table
  exports['bcc-bridge']:GetGang(src)                   → Gang
  exports['bcc-bridge']:SetGang(src, name, grade)      → boolean
  exports['bcc-bridge']:GetAllGangs()                  → table
  exports['bcc-bridge']:GetMetadata(src, key)          → any
  exports['bcc-bridge']:SetMetadata(src, key, val)     → boolean
  exports['bcc-bridge']:GetLicenses(src)               → Licenses
  exports['bcc-bridge']:HasLicense(src, license)       → boolean
  exports['bcc-bridge']:AddLicense(src, license)       → boolean
  exports['bcc-bridge']:RemoveLicense(src, license)    → boolean
  exports['bcc-bridge']:GetSkill(src, skill)           → number
  exports['bcc-bridge']:SetSkill(src, skill, val)      → boolean
  exports['bcc-bridge']:AddSkillXP(src, skill, amt)    → boolean
  exports['bcc-bridge']:GetMoney(src, type)            → number
  exports['bcc-bridge']:AddMoney(src, type, amt)       → boolean
  exports['bcc-bridge']:RemoveMoney(src, type, amt)    → boolean
  exports['bcc-bridge']:GetItem(src, item)             → number
  exports['bcc-bridge']:AddItem(src, item, amt, meta)  → boolean
  exports['bcc-bridge']:RemoveItem(src, item, amt)     → boolean
  exports['bcc-bridge']:Notify(src, msg, type, dur)    → void
  exports['bcc-bridge']:RegisterCallback(name, cb)     → void

═══════════════════════════════════════════════════════════════════
  CLIENT EXPORTS  (callable from other client scripts)
═══════════════════════════════════════════════════════════════════

  -- Instant (uses locally cached framework data)
  exports['bcc-bridge']:GetFramework()                 → string
  exports['bcc-bridge']:IsPlayerLoaded()               → boolean
  exports['bcc-bridge']:GetPlayerData()                → raw framework player data
  exports['bcc-bridge']:GetCharacterData()             → Character
  exports['bcc-bridge']:GetJob()                       → Job
  exports['bcc-bridge']:GetGang()                      → Gang
  exports['bcc-bridge']:GetMetadata(key)               → any
  exports['bcc-bridge']:GetLicenses()                  → Licenses
  exports['bcc-bridge']:GetSkill(skill)                → number
  exports['bcc-bridge']:GetMoney(type)                 → number
  exports['bcc-bridge']:GetItem(item)                  → number
  exports['bcc-bridge']:Notify(msg, type, dur)         → void
  exports['bcc-bridge']:TriggerCallback(name, cb, ...) → void

  -- Server-authoritative (async – pass a callback to receive result)
  exports['bcc-bridge']:ServerGetCharacter(cb)
  exports['bcc-bridge']:ServerGetJob(cb)
  exports['bcc-bridge']:ServerSetJob(name, grade, cb)
  exports['bcc-bridge']:ServerGetGang(cb)
  exports['bcc-bridge']:ServerSetGang(name, grade, cb)
  exports['bcc-bridge']:ServerGetMetadata(key, cb)
  exports['bcc-bridge']:ServerSetMetadata(key, val, cb)
  exports['bcc-bridge']:ServerGetLicenses(cb)
  exports['bcc-bridge']:ServerHasLicense(license, cb)
  exports['bcc-bridge']:ServerAddLicense(license, cb)
  exports['bcc-bridge']:ServerRemoveLicense(license, cb)
  exports['bcc-bridge']:ServerGetSkill(skill, cb)
  exports['bcc-bridge']:ServerSetSkill(skill, val, cb)
  exports['bcc-bridge']:ServerAddSkillXP(skill, amt, cb)
  exports['bcc-bridge']:ServerGetMoney(type, cb)
  exports['bcc-bridge']:ServerAddMoney(type, amt, cb)
  exports['bcc-bridge']:ServerRemoveMoney(type, amt, cb)
  exports['bcc-bridge']:ServerGetItem(item, cb)
  exports['bcc-bridge']:ServerAddItem(item, amt, meta, cb)
  exports['bcc-bridge']:ServerRemoveItem(item, amt, cb)
  exports['bcc-bridge']:ServerNotify(msg, type, dur)

]]
