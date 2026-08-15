local _, ns = ...

-- Cast intake: turns the noisy stream of spellcast events the client fires at
-- the player into the list of casts the timeline draws. Every rule for "which
-- raw events are one cast" lives here -- channel ticks, periodic ticks, extra
-- strikes of one press, internal system spells, the login replay flood.
--
-- Everything outside those rules arrives through `env`, so the same rules run
-- against the live client or against a recorded event log (see replay.lua).
-- Two adapters, one seam.

ns.Intake = {}

local Intake = {}
Intake.__index = Intake

-- How long after a button press its extra strikes can still arrive.
local STRIKE_WINDOW = 1.5
-- How far back to look for an entry to merge into. Only bounds the scan; the
-- per-entry age checks decide what actually merges.
local MERGE_SCAN = 10
-- After PLAYER_ENTERING_WORLD, WoW replays UNIT_SPELLCAST_SUCCEEDED for every
-- passive/equipment/tabard spell on the player. Drop that flood.
local LOGIN_SUPPRESS = 1.5

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

-- A cast GUID looks like "Cast-3-4221-2813-20669-12294-001D7FB33E". The leading
-- field separates a cast the player pressed from one the game triggered on their
-- behalf: every press in testing reports 3, while Bladestorm's periodic ticks
-- report 13 and Execute's secondary event reports 15. This only ever decides
-- *how* an event merges, never whether it's discarded, so a spell that reports
-- some other type for a genuine press still gets its icon.
local function isPress(castGUID)
  if not castGUID then return true end
  local t = castGUID:match("^Cast%-(%d+)%-")
  return t == nil or t == "3"
end

-- The spell the GUID says was actually pressed, which is often not the spell
-- the event reports: pressing Slam reports "Heroic Strike".
local function buttonSpell(castGUID)
  local id = castGUID and castGUID:match("^Cast%-%d+%-%d+%-%d+%-%d+%-(%d+)%-")
  return id and tonumber(id) or nil
end

function ns.Intake.New(env)
  return setmetatable({
    env = env,
    casts = {},
    suppressUntil = 0,
    channelName = nil,
    channelValidUntil = 0,
  }, Intake)
end

-- Zones, quests and scenarios constantly fire UNIT_SPELLCAST_SUCCEEDED on the
-- player for spells nobody cast: "[DNT] Player Inside WMO", "Disable ALL
-- Mounts", "NoCho", "Med'jai's Protection". Probing every spell seen across two
-- play sessions, the separation is exact -- every real ability carries a tooltip
-- description and every internal spell has none at all.
--
-- Deliberately NOT filtered on castability. Rogue's "Coup de Grace" fires from
-- a hero talent proc and reports isPlayerSpell = false, no spellbook slot and no
-- action bar slot, yet it's a real ability that belongs on the timeline. The
-- same is true of any proc-granted or item-granted cast.
function Intake:HasDescription(spellID)
  local desc = self.env.description(spellID)
  -- nil means the client hasn't cached this spell's data yet. Treat unknown as
  -- "show it" so a spell's first cast of the session is never eaten.
  return desc == nil or desc ~= ""
end

function Intake:IsInternal(spellID, castGUID)
  if self:HasDescription(spellID) then return false end
  local button = buttonSpell(castGUID)
  if button and button ~= spellID and self:HasDescription(button) then return false end
  return true
end

-- Ticks of an active channel fire as SUCCEEDED under the channel's own name.
-- Spells cast alongside a channel (e.g. Vivify during Soothing Mist) have a
-- different name and pass through normally.
function Intake:IsChannelTick(spellID)
  if not self.channelName then return false end
  if self.env.now() >= self.channelValidUntil then return false end
  local info = self.env.spellInfo(spellID)
  return info ~= nil and info.name == self.channelName
end

-- The whole intake interface: hand it a raw spellcast event and the cast list
-- updates, or doesn't. Callers need to know nothing else.
function Intake:Observe(event, castGUID, spellID)
  if self.env.log then self.env.log(self, event, castGUID, spellID) end

  if event == "PLAYER_ENTERING_WORLD" then
    self.suppressUntil = self.env.now() + LOGIN_SUPPRESS
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    local info = self.env.spellInfo(spellID)
    self.channelName = info and info.name
    self.channelValidUntil = math.huge
    self:Record(spellID, castGUID)
  elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    -- Keep the channel name remembered briefly: late ticks can fire SUCCEEDED
    -- after CHANNEL_STOP and would otherwise sneak through.
    self.channelValidUntil = self.env.now() + 0.5
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if self:IsChannelTick(spellID) then return end
    self:Record(spellID, castGUID)
  end
end

function Intake:Record(spellID, castGUID)
  local now = self.env.now()
  if now < self.suppressUntil then return end
  local info = self.env.spellInfo(spellID)
  if not info then return end
  -- Skip Blizzard's internal placeholder spells. "DNT" ("do not translate")
  -- marks system/environment spells that fire as UNIT_SPELLCAST_SUCCEEDED on
  -- the player but aren't player-initiated casts. Marker appears as either
  -- "[DNT]" prefix or "(DNT)" suffix depending on the spell.
  if info.name and (info.name:find("%(DNT%)") or info.name:sub(1, 5) == "[DNT]") then
    return
  end
  if ns.DB.profile.hideInternal and self:IsInternal(spellID, castGUID) then return end

  local bname = baseName(info.name)

  -- Multi-strike collapse. A single button press of many melee abilities -- Fury
  -- warrior most visibly (Rampage and Odyn's Fury each fire five strikes,
  -- Whirlwind/Raging Blow/Execute several), plus off-GCD ones like Charge and
  -- Heroic Leap -- produces several UNIT_SPELLCAST_SUCCEEDED events: main- and
  -- off-hand swings and multi-hit strikes, each a *distinct* spellID but sharing
  -- one display name, arriving across the ability's animation (up to ~1.3s).
  --
  -- These can't be separated from a genuine re-press by timing alone: the strike
  -- span is about one GCD, the same spacing as pressing the spell again. Two
  -- signals separate them. First, the spellID: the spell the action button
  -- actually casts -- the "primary" -- fires first and is the SAME spellID every
  -- press, while extra strikes carry other spellIDs. Second, the cast GUID's
  -- press/trigger flag (see isPress).
  --
  -- The spellID alone isn't enough for periodic effects. Bladestorm ticks ten
  -- times over ~5s, every tick firing the same spellID (50622) as the last, so
  -- an "identical spellID means re-press" rule draws ten icons for one press.
  -- But those ticks arrive faster than the GCD and are flagged as triggered, and
  -- neither is true of a real re-press.
  --
  -- Each entry therefore remembers every spellID folded into it and the last
  -- time it saw a press (lastPress) and any event at all (lastEffect), so a tick
  -- train keeps sliding its own window forward without extending the window a
  -- genuine re-press is measured against.
  local press = isPress(castGUID)
  -- An on-GCD spell can't be pressed again inside its own GCD, so a same-spellID
  -- repeat that fast is a tick, not a press. Off-GCD spells with charges can
  -- genuinely double-tap that fast, but only presses take the branch above.
  local tickWindow = math.min(STRIKE_WINDOW, self.env.hastedGCD() * 0.9)

  -- Classify on/off-GCD using the spell DB. The spell's template GCD in ms is
  -- typically 1500 for on-GCD spells, 0 for off-GCD. This is static DBC data, so
  -- it doesn't depend on haste, latency, cast time, or whether the GCD is
  -- currently rolling. Cast-time spells (mounts, hardcasts) are forced on-GCD:
  -- mounts flag as off-GCD in DBC (they use a shared mount cooldown), but
  -- visually anything with a cast bar belongs on the main row.
  local gcdMS = self.env.baseGCD(spellID)
  local onGCD = (gcdMS or 0) > 0 or (info.castTime or 0) > 0 or FORCE_ON_GCD[spellID] == true

  for i = #self.casts, 1, -1 do
    local c = self.casts[i]
    -- Casts are ordered by press time; nothing this far back can belong to the
    -- current press, so stop scanning.
    if now - (c.t or 0) > MERGE_SCAN then break end
    if c.baseName == bname then
      if press then
        local age = now - c.lastPress
        if not c.ids[spellID] and age <= STRIKE_WINDOW then
          -- Another strike of this press -- or the press itself, arriving after
          -- the effect it triggered (Bladestorm's first tick beats its cast to
          -- the event queue). When the entry was anchored by a triggered event,
          -- the press is the better thing to show, so take its identity over.
          c.ids[spellID] = true
          if not c.pressed then
            c.spellID, c.name, c.icon, c.onGCD, c.pressed = spellID, info.name, info.iconID, onGCD, true
          end
          c.lastPress, c.lastEffect = now, now
          return
        elseif c.ids[spellID] and age < 0.25 then
          c.lastPress, c.lastEffect = now, now
          return            -- instant duplicate SUCCEEDED of the same spell
        end
      else
        local age = now - c.lastEffect
        if (c.ids[spellID] and age <= tickWindow)
          or (not c.ids[spellID] and age <= STRIKE_WINDOW) then
          c.ids[spellID] = true
          c.lastEffect = now
          return            -- periodic tick or extra strike of an existing press
        end
      end
      break                 -- genuine re-press of the same button → keep it
    end
  end

  self.casts[#self.casts + 1] = {
    spellID = spellID,
    name = info.name,
    baseName = bname,
    icon = info.iconID,
    t = now,
    onGCD = onGCD,
    ids = { [spellID] = true },
    pressed = press,
    lastPress = now,
    lastEffect = now,
  }
  local max = ns.DB.profile.maxIcons + 5
  while #self.casts > max do
    table.remove(self.casts, 1)
  end
end

-- The casts inside the visible window, oldest first. Pruning happens here
-- rather than in the caller, so the list's invariants stay in one module. The
-- same table is returned every call -- this runs from OnUpdate, so it must not
-- allocate.
function Intake:Window(seconds)
  local cutoff = self.env.now() - seconds - 1
  while self.casts[1] and self.casts[1].t < cutoff do
    table.remove(self.casts, 1)
  end
  return self.casts
end

function Intake:Clear()
  wipe(self.casts)
end

-- The live adapter: the only place in intake that touches the WoW API.
local liveEnv = {
  now = function()
    return GetTime()
  end,
  hastedGCD = function()
    return ns.GCD:Get()
  end,
  spellInfo = function(spellID)
    return C_Spell.GetSpellInfo(spellID)
  end,
  baseGCD = function(spellID)
    local _, gcdMS = GetSpellBaseCooldown(spellID)
    return gcdMS
  end,
  -- nil when the client hasn't cached this spell yet; the load is requested so
  -- a later cast of the same spell can be judged properly.
  description = function(spellID)
    if C_Spell.IsSpellDataCached and not C_Spell.IsSpellDataCached(spellID) then
      if C_Spell.RequestLoadSpellData then C_Spell.RequestLoadSpellData(spellID) end
      return nil
    end
    return C_Spell.GetSpellDescription(spellID)
  end,
  -- Records the raw event stream, before any rule has run, so a log can be
  -- replayed through the rules later (see replay.lua). Diagnostics only.
  log = function(_, event, castGUID, spellID)
    if not CastHistoryDB.debug then return end
    -- PLAYER_ENTERING_WORLD carries no spell.
    local info = spellID and C_Spell.GetSpellInfo(spellID)
    local gcd = C_Spell.GetSpellCooldown(61304)
    table.insert(CastHistoryDB.log, {
      t = GetTime(), event = event, spellID = spellID,
      name = info and info.name or "?", castGUID = castGUID,
      icon = info and info.iconID,
      gcdElapsed = gcd and gcd.startTime and (GetTime() - gcd.startTime) or nil,
      gcdDur = gcd and gcd.duration or nil,
    })
    if #CastHistoryDB.log > 500 then table.remove(CastHistoryDB.log, 1) end
  end,
}

ns.Intake.liveEnv = liveEnv

-- The live cast list every other module reads.
ns.Casts = ns.Intake.New(liveEnv)
