local _, ns = ...

ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
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
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if CastHistoryDB.debug then
        local info = C_Spell.GetSpellInfo(spellID)
        table.insert(CastHistoryDB.log, {
          t = GetTime(), event = event, unit = unit, spellID = spellID,
          name = info and info.name or "?", castGUID = castGUID,
        })
        if #CastHistoryDB.log > 500 then table.remove(CastHistoryDB.log, 1) end
      end
      ns.Tracker:Add(spellID)
    else
      ns.Tracker:RefreshHastedGCD()
    end
  end)

  ns.Tracker:RefreshHastedGCD()
  self.frame = f
end
