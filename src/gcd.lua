local _, ns = ...

-- The player's current global cooldown, used to space the reference markers on
-- the timeline and to tell a periodic tick apart from a genuine re-press.
--
-- Owns the whole haste story: reading it, surviving Secret Values, caching the
-- last good value, and telling listeners when it changes. Nothing else needs to
-- know that haste is involved.
ns.GCD = {
  cached = 1.5,
  listeners = {},
}

-- Computed in isolation so we can pcall it: as of Patch 12.0 ("Midnight"),
-- UnitSpellHaste returns a Secret Value once our execution is tainted, and any
-- arithmetic on a Secret throws a Lua error. pcall is the sanctioned way to
-- detect that (a thrown error == Secret).
local function compute()
  local haste = UnitSpellHaste("player") or 0
  local gcd = 1.5 / (1 + haste / 100)
  if gcd < 0.75 then gcd = 0.75 end
  return gcd
end

function ns.GCD:Get()
  return self.cached
end

-- Register a function to run whenever the GCD changes. Two listeners today
-- would be one too many to justify this over a direct call, but it's what
-- breaks the cycle: the timeline no longer reaches into the display to repaint.
function ns.GCD:OnChange(fn)
  self.listeners[#self.listeners + 1] = fn
end

function ns.GCD:Refresh()
  if InCombatLockdown() then return end
  -- When haste is Secret we can't read it, so keep the last good GCD. The
  -- markers are cosmetic, so a slightly stale spacing is an acceptable
  -- fallback and far better than erroring on every UNIT_AURA.
  local ok, gcd = pcall(compute)
  if not ok then return end
  if gcd == self.cached then return end
  self.cached = gcd
  for _, fn in ipairs(self.listeners) do
    fn(gcd)
  end
end
