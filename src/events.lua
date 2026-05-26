local _, ns = ...

ns.Events = {}

local f = CreateFrame("Frame", "CTSpellEvents")
f:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
f:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:RegisterUnitEvent("UNIT_AURA", "player")
f:RegisterEvent("PLAYER_ENTERING_WORLD")

local activeChannelName = nil
local channelNameValidUntil = 0

function ns.Events:Register()
  f:SetScript("OnEvent", function(_, event, unit, castGUID, spellID)
    if event == "PLAYER_ENTERING_WORLD" then
      -- Suppress the flood of passive/equipment UNIT_SPELLCAST_SUCCEEDED
      -- events the client replays right after entering the world.
      ns.Tracker.suppressUntil = GetTime() + 1.5
      return
    end
    if event == "UNIT_SPELLCAST_CHANNEL_START" then
      local info = C_Spell.GetSpellInfo(spellID)
      activeChannelName = info and info.name
      channelNameValidUntil = math.huge
      ns.Tracker:Add(spellID)
      return
    end
    if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
      -- Keep the channel name remembered briefly: late ticks can fire
      -- SUCCEEDED after CHANNEL_STOP (UnitChannelInfo is already nil) and
      -- would otherwise sneak through.
      channelNameValidUntil = GetTime() + 0.5
      return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
      -- Filter ticks of the active channel by name match. Spells cast
      -- alongside a channel (e.g. Vivify during Soothing Mist) have a
      -- different name and pass through normally.
      if activeChannelName and GetTime() < channelNameValidUntil then
        local info = C_Spell.GetSpellInfo(spellID)
        if info and info.name == activeChannelName then return end
      end
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
