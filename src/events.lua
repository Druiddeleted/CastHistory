local _, ns = ...

-- Event registration only. Every rule about what an event *means* lives behind
-- the interface it's forwarded to: spellcast events go to cast intake, haste
-- events to the GCD reference.
ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
-- Cast lifecycle. Intake has no rules for these yet -- they're forwarded so the
-- debug log records them, as groundwork for drawing hardcasts as bars with
-- pushback, interrupts and failures marked.
f:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_FAILED_QUIET", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_AURA", "player")

local CAST_EVENTS = {
  UNIT_SPELLCAST_SUCCEEDED = true,
  UNIT_SPELLCAST_CHANNEL_START = true,
  UNIT_SPELLCAST_CHANNEL_STOP = true,
  UNIT_SPELLCAST_SENT = true,
  UNIT_SPELLCAST_START = true,
  UNIT_SPELLCAST_DELAYED = true,
  UNIT_SPELLCAST_STOP = true,
  UNIT_SPELLCAST_INTERRUPTED = true,
  UNIT_SPELLCAST_FAILED = true,
  UNIT_SPELLCAST_FAILED_QUIET = true,
  UNIT_SPELLCAST_CHANNEL_UPDATE = true,
  PLAYER_ENTERING_WORLD = true,
}

function ns.Events:Register()
  f:SetScript("OnEvent", function(_, event, ...)
    if CAST_EVENTS[event] then
      local castGUID, spellID
      if event == "UNIT_SPELLCAST_SENT" then
        -- SENT is the odd one out: (unit, target, castGUID, spellID).
        castGUID, spellID = select(3, ...)
      else
        castGUID, spellID = select(2, ...)
      end
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
