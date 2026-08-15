local _, ns = ...

-- Event registration only. Every rule about what an event *means* lives behind
-- the interface it's forwarded to: spellcast events go to cast intake, haste
-- events to the GCD reference.
ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_AURA", "player")

local CAST_EVENTS = {
  UNIT_SPELLCAST_SUCCEEDED = true,
  UNIT_SPELLCAST_CHANNEL_START = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
  PLAYER_ENTERING_WORLD = true,
}

function ns.Events:Register()
  f:SetScript("OnEvent", function(_, event, _, castGUID, spellID)
    if CAST_EVENTS[event] then
      ns.Casts:Observe(event, castGUID, spellID)
    else
      -- PLAYER_REGEN_ENABLED, PLAYER_EQUIPMENT_CHANGED, UNIT_AURA: anything
      -- that can change haste.
      ns.GCD:Refresh()
    end
  end)

  ns.GCD:Refresh()
  self.frame = f
end
