local _, ns = ...

ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

function ns.Events:Register()
  f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "PLAYER_ENTERING_WORLD" then
      -- Suppress the flood of passive/equipment UNIT_SPELLCAST_SUCCEEDED
      -- events the client replays right after entering the world.
      ns.Tracker.suppressUntil = GetTime() + 1.5
      return
    end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
      -- Channels are logged once at start; per-tick SUCCEEDED is filtered.
      ns.Tracker:Add(spellID)
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      -- Channels fire UNIT_SPELLCAST_SUCCEEDED for every tick (and once for
      -- the initial cast). If the player is currently channeling, skip the
      -- SUCCEEDED entirely — CHANNEL_START already logged the cast.
      if UnitChannelInfo("player") then return end
      ns.Tracker:Add(spellID)
      if CastHistoryDB.debug then
        local info = C_Spell.GetSpellInfo(spellID)
        local last = ns.Tracker.casts[#ns.Tracker.casts]
        local onGCD = last and last.spellID == spellID and last.onGCD or nil
        local gcd = C_Spell.GetSpellCooldown(61304)
        table.insert(CastHistoryDB.log, {
          t = GetTime(), event = event, unit = unit, spellID = spellID,
          name = info and info.name or "?", castGUID = castGUID,
          onGCD = onGCD,
          gcdElapsed = gcd and gcd.startTime and (GetTime() - gcd.startTime) or nil,
          gcdDur = gcd and gcd.duration or nil,
        })
        if #CastHistoryDB.log > 500 then table.remove(CastHistoryDB.log, 1) end
      end
    else
      ns.Tracker:RefreshHastedGCD()
    end
  end)

  ns.Tracker:RefreshHastedGCD()
  self.frame = f
end
