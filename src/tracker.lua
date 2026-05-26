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
  local last = self.casts[#self.casts]
  if last and last.name == info.name and (GetTime() - last.t) < 0.25 then
    return
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
    icon = info.iconID,
    t = GetTime(),
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

function ns.Tracker:RefreshHastedGCD()
  if InCombatLockdown() then return end
  local haste = UnitSpellHaste("player") or 0
  local gcd = 1.5 / (1 + haste / 100)
  if gcd < 0.75 then gcd = 0.75 end
  self.cachedHastedGCD = gcd
end

function ns.Tracker:GetHastedGCD()
  return self.cachedHastedGCD
end
