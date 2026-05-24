local _, ns = ...

ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_AURA", "player")

function ns.Events:Register()
  f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      if CastTimelineDB.debug then
        local info = C_Spell.GetSpellInfo(spellID)
        table.insert(CastTimelineDB.log, {
          t = GetTime(), event = event, unit = unit, spellID = spellID,
          name = info and info.name or "?", castGUID = castGUID,
        })
        if #CastTimelineDB.log > 500 then table.remove(CastTimelineDB.log, 1) end
      end
      ns.Tracker:Add(spellID)
    else
      ns.Tracker:RefreshHastedGCD()
    end
  end)

  ns.Tracker:RefreshHastedGCD()
  self.frame = f
end
