local _, ns = ...

-- Replays a recorded event log through the intake rules and reports how many
-- casts came out. The rules can't tell it apart from the live client: it feeds
-- the same events through the same interface, with the clock and GCD taken from
-- the recording instead of from the game.
--
-- This is the regression check for cast collapse. After a rules change, replay
-- a log captured before it and compare the counts -- a fix that quietly eats
-- real casts shows up as a spell whose count dropped.

ns.Replay = {}

-- The replay adapter. Only time is faked; spell lookups stay live, because the
-- spell database is static data that a recording has no reason to duplicate.
local function makeEnv(clock)
  local live = ns.Intake.liveEnv
  return {
    now = function() return clock.t end,
    hastedGCD = function() return clock.gcd end,
    -- The recorded global cooldown, so "did this press start the GCD" replays
    -- the same way it was seen live.
    gcdState = function() return clock.gcdElapsed, clock.gcdDuration end,
    spellInfo = live.spellInfo,
    baseGCD = live.baseGCD,
    description = live.description,
    -- No log: a replay must never append to the log it is reading.
  }
end

-- Returns a tally of casts produced per spell name, the number of events read,
-- and the total casts produced.
function ns.Replay:Run(log)
  log = log or (CastHistoryDB and CastHistoryDB.log)
  if not log or #log == 0 then
    return nil, "debug log is empty -- run `/ch debug on`, play, then replay"
  end

  local clock = { t = 0, gcd = 1.5, gcdElapsed = 0, gcdDuration = 0 }
  local intake = ns.Intake.New(makeEnv(clock))

  local casts, events = {}, {}
  local total, last = 0, nil
  for _, e in ipairs(log) do
    if e.t then
      clock.t = e.t
      if e.gcdDur and e.gcdDur > 0 then clock.gcd = e.gcdDur end
      clock.gcdElapsed = e.gcdElapsed or 0
      clock.gcdDuration = e.gcdDur or 0
      events[e.name or "?"] = (events[e.name or "?"] or 0) + 1

      intake:Observe(e.event, e.castGUID, e.spellID)

      -- Record always appends on a new cast and never touches the tail on a
      -- fold, so a changed tail means exactly one cast was created.
      local top = intake.casts[#intake.casts]
      if top and top ~= last then
        last = top
        casts[top.name] = (casts[top.name] or 0) + 1
        total = total + 1
      end
    end
  end

  return { casts = casts, events = events, total = total, read = #log }
end

-- Formats the replay as lines of "events -> casts  name", worst collapse first,
-- so a spell firing many events for one press is easy to spot.
function ns.Replay:Report(limit)
  local result, err = self:Run()
  if not result then return nil, err end

  local rows = {}
  for name, count in pairs(result.events) do
    rows[#rows + 1] = { name = name, events = count, casts = result.casts[name] or 0 }
  end
  table.sort(rows, function(a, b)
    if a.events ~= b.events then return a.events > b.events end
    return a.name < b.name
  end)

  local lines = {}
  for i = 1, math.min(#rows, limit or 15) do
    local r = rows[i]
    lines[#lines + 1] = ("%4d -> %-4d %s"):format(r.events, r.casts, r.name)
  end
  return lines, nil, result
end
