local _, ns = ...

ns.Tracker = {
  casts = {},
}

-- Spells the DBC flags as off-GCD but that visually belong on the main row.
-- Skyriding skills don't share the player GCD but they're the player's
-- primary active inputs while mounted.
local FORCE_ON_GCD = {
  [372610] = true, -- Skyward Ascent
  [361584] = true, -- Surge Forward
  [361585] = true, -- Whirling Surge
  [368896] = true, -- Take to the Skies
  [374990] = true, -- Bronze Timelock
  [425951] = true, -- Land
}

-- Strip the " Off-Hand" suffix WoW appends to the off-hand swing of a
-- dual-wield strike (e.g. "Odyn's Fury Off-Hand") so it collapses into the
-- main-hand cast from the same button press.
local function baseName(name)
  if not name then return name end
  return (name:gsub(" Off%-Hand$", ""))
end

function ns.Tracker:Add(spellID)
  -- After PLAYER_ENTERING_WORLD, WoW replays UNIT_SPELLCAST_SUCCEEDED for
  -- every passive/equipment/tabard spell on the player. Drop that flood.
  if GetTime() < (self.suppressUntil or 0) then return end
  local info = C_Spell.GetSpellInfo(spellID)
  if not info then return end
  -- Skip Blizzard's internal placeholder spells. "DNT" ("do not translate")
  -- marks system/environment spells that fire as UNIT_SPELLCAST_SUCCEEDED on
  -- the player but aren't player-initiated casts. Marker appears as either
  -- "[DNT]" prefix or "(DNT)" suffix depending on the spell.
  if info.name and (info.name:find("%(DNT%)") or info.name:sub(1, 5) == "[DNT]") then
    return
  end
  local now = GetTime()
  local bname = baseName(info.name)

  -- Multi-strike collapse. A single button press of many melee abilities — Fury
  -- warrior most visibly (Rampage and Odyn's Fury each fire five strikes,
  -- Whirlwind/Raging Blow/Execute several), plus off-GCD ones like Charge and
  -- Heroic Leap — produces several UNIT_SPELLCAST_SUCCEEDED events: main- and
  -- off-hand swings and multi-hit strikes, each a *distinct* spellID but sharing
  -- one display name, arriving across the ability's animation (up to ~1.3s).
  --
  -- These can't be separated from a genuine re-press by timing alone: the strike
  -- span is about one GCD, the same spacing as pressing the spell again. The
  -- reliable signal is the spellID. The spell the action button actually casts —
  -- the "primary" — fires first and is the SAME spellID every press; the extra
  -- strikes carry other spellIDs. So within a short window we fold a same-named
  -- cast into the most recent same-named cast when its spellID differs (an extra
  -- strike), but keep it when the spellID matches (a real re-press), with a tight
  -- same-spellID guard for the occasional instant duplicate SUCCEEDED.
  for i = #self.casts, 1, -1 do
    local c = self.casts[i]
    local age = now - (c.t or 0)
    -- Casts are time-ordered; nothing older than a strike window can belong to
    -- the current press, so stop scanning.
    if age > 1.5 then break end
    if c.baseName == bname then
      if c.spellID ~= spellID then
        return            -- extra strike of the same press
      elseif age < 0.25 then
        return            -- instant duplicate SUCCEEDED of the same spell
      end
      break               -- genuine re-press of the same button → keep it
    end
  end

  -- Classify on/off-GCD using the spell DB. GetSpellBaseCooldown's second
  -- return is the spell's template GCD in ms (typically 1500 for on-GCD
  -- spells, 0 for off-GCD). This is static DBC data, so it doesn't depend
  -- on haste, latency, cast time, or whether the GCD is currently rolling.
  -- Cast-time spells (mounts, hardcasts) are forced on-GCD: mounts flag as
  -- off-GCD in DBC (they use a shared mount cooldown), but visually anything
  -- with a cast bar belongs on the main row.
  local _, gcdMS = GetSpellBaseCooldown(spellID)
  local onGCD = (gcdMS or 0) > 0 or (info.castTime or 0) > 0 or FORCE_ON_GCD[spellID] == true

  table.insert(self.casts, {
    spellID = spellID,
    name = info.name,
    baseName = bname,
    icon = info.iconID,
    t = now,
    onGCD = onGCD,
  })
  local max = ns.DB.profile.maxIcons + 5
  while #self.casts > max do
    table.remove(self.casts, 1)
  end
end

function ns.Tracker:Prune(windowSeconds)
  local cutoff = GetTime() - windowSeconds - 1
  while self.casts[1] and self.casts[1].t < cutoff do
    table.remove(self.casts, 1)
  end
end

function ns.Tracker:Clear()
  wipe(self.casts)
end

ns.Tracker.cachedHastedGCD = 1.5

-- Computed in isolation so we can pcall it: as of Patch 12.0 ("Midnight"),
-- UnitSpellHaste returns a Secret Value once our execution is tainted, and any
-- arithmetic on a Secret throws a Lua error. pcall is the sanctioned way to
-- detect that (a thrown error == Secret).
local function computeHastedGCD()
  local haste = UnitSpellHaste("player") or 0
  local gcd = 1.5 / (1 + haste / 100)
  if gcd < 0.75 then gcd = 0.75 end
  return gcd
end

function ns.Tracker:RefreshHastedGCD()
  if InCombatLockdown() then return end
  -- When haste is Secret we can't read it, so keep the last good GCD. The
  -- markers are cosmetic, so a slightly stale spacing is an acceptable
  -- fallback and far better than erroring on every UNIT_AURA.
  local ok, gcd = pcall(computeHastedGCD)
  if not ok then return end
  self.cachedHastedGCD = gcd
  -- The hasted-GCD marker spacing depends on this value, so re-place the
  -- markers now rather than recomputing them every frame in UI:Refresh.
  if ns.UI and ns.UI.frame then ns.UI:LayoutGCDMarkers() end
end

function ns.Tracker:GetHastedGCD()
  return self.cachedHastedGCD
end
