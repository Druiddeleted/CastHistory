local _, ns = ...

ns.Tracker = {
  casts = {},
}

function ns.Tracker:Add(spellID)
  local info = C_Spell.GetSpellInfo(spellID)
  if not info then return end
  local last = self.casts[#self.casts]
  if last and last.name == info.name and (GetTime() - last.t) < 0.25 then
    return
  end
  table.insert(self.casts, {
    spellID = spellID,
    name = info.name,
    icon = info.iconID,
    t = GetTime(),
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
