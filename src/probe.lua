local _, ns = ...

-- Diagnostic scaffolding, not part of the addon's normal operation. `/ch probe`
-- walks every spell the debug log has seen and records what the API says about
-- it, so a filter for the internal/phantom spells that fire on the player
-- (e.g. "Disable ALL Mounts", "NoCho") can be designed against real data rather
-- than guessed at. Results land in CastHistoryDB.probe for reading out of
-- SavedVariables after a /reload. Remove once the filter is settled.

ns.Probe = {}

-- Every accessor is pcall'd: some of these APIs don't exist on every client
-- build, and as of 12.0 any of them may hand back a Secret Value that throws
-- when touched. A field simply goes missing rather than breaking the sweep.
local function try(out, key, fn)
  local ok, a = pcall(fn)
  if ok and a ~= nil then out[key] = a end
end

local function probeSpell(id)
  local r = {}
  try(r, "name", function() local i = C_Spell.GetSpellInfo(id); return i and i.name end)
  try(r, "icon", function() local i = C_Spell.GetSpellInfo(id); return i and i.iconID end)
  try(r, "castTime", function() local i = C_Spell.GetSpellInfo(id); return i and i.castTime end)
  try(r, "baseCD", function() local a = GetSpellBaseCooldown(id); return a end)
  try(r, "baseGCD", function() local _, b = GetSpellBaseCooldown(id); return b end)

  -- "Can the player actually cast this?" — the candidate signals for the filter.
  try(r, "isPlayerSpell", function() return IsPlayerSpell(id) end)
  try(r, "knownOrOverride", function() return IsSpellKnownOrOverridesKnown(id) end)
  try(r, "bookKnown", function() return C_SpellBook.IsSpellKnown(id) end)
  try(r, "bookSlot", function()
    local s = C_SpellBook.FindSpellBookSlotForSpell(id)
    return s
  end)
  try(r, "passive", function() return C_Spell.IsSpellPassive(id) end)
  try(r, "actionSlots", function()
    local slots = C_ActionBar.FindSpellActionButtons(id)
    return slots and #slots or 0
  end)
  try(r, "mountID", function() return C_MountJournal.GetMountFromSpell(id) end)
  try(r, "descLen", function() return #(C_Spell.GetSpellDescription(id) or "") end)
  try(r, "harmful", function() return C_Spell.IsSpellHarmful(id) end)
  try(r, "helpful", function() return C_Spell.IsSpellHelpful(id) end)
  try(r, "inRangeAPI", function() return C_Spell.SpellHasRange(id) end)
  return r
end

function ns.Probe:Run()
  local log = CastHistoryDB and CastHistoryDB.log
  if not log or #log == 0 then
    return 0, "debug log is empty — run `/ch debug on`, play, then probe"
  end

  -- Collect both the spell each event reported and the spell embedded in its
  -- cast GUID (the button actually pressed). They differ constantly — Slam
  -- procs "Heroic Strike", Whirlwind reports "Cleave" — and the GUID's spell is
  -- the one worth testing for castability.
  local seen, order = {}, {}
  local function note(id, how, name, castType)
    if not id then return end
    id = tonumber(id)
    if not id then return end
    if not seen[id] then
      seen[id] = { spellID = id, sources = {}, castTypes = {} }
      order[#order + 1] = id
    end
    seen[id].sources[how] = (seen[id].sources[how] or 0) + 1
    if name then seen[id].loggedName = name end
    if castType then seen[id].castTypes[castType] = (seen[id].castTypes[castType] or 0) + 1 end
  end

  for _, e in ipairs(log) do
    local castType, guidSpell
    if e.castGUID then
      castType, guidSpell = e.castGUID:match("^Cast%-(%d+)%-%d+%-%d+%-%d+%-(%d+)%-")
    end
    note(e.spellID, "event", e.name, castType)
    if guidSpell and tonumber(guidSpell) ~= e.spellID then
      note(guidSpell, "guid", nil, castType)
    end
  end

  local out = {}
  for _, id in ipairs(order) do
    local rec = seen[id]
    local info = probeSpell(id)
    for k, v in pairs(info) do rec[k] = v end
    out[#out + 1] = rec
  end
  CastHistoryDB.probe = out
  return #out
end
