local _, ns = ...

local defaults = {
  shown = true,
  locked = false,
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = -200,
  windowSeconds = 8,
  growth = "RIGHT", -- LEFT, RIGHT, UP, DOWN
  iconSize = 32,
  maxIcons = 30,
  alpha = 1.0,
  showBaseGCD = true,
  showHastedGCD = true,
  showSpellNames = false,
  background = true,
  strata = "HIGH",
}

ns.DB = {}

function ns.DB:Init()
  -- one-time migration from CastHistoryDB
  if not CastTimelineDB and CastHistoryDB and CastHistoryDB.profile then
    CastTimelineDB = { profile = {} }
    for k, v in pairs(CastHistoryDB.profile) do
      CastTimelineDB.profile[k] = v
    end
  end
  CastTimelineDB = CastTimelineDB or {}
  CastTimelineDB.profile = CastTimelineDB.profile or {}
  for k, v in pairs(defaults) do
    if CastTimelineDB.profile[k] == nil then
      CastTimelineDB.profile[k] = v
    end
  end
  CastTimelineDB.debug = CastTimelineDB.debug or false
  CastTimelineDB.log = CastTimelineDB.log or {}
  self.profile = CastTimelineDB.profile
  self.defaults = defaults
end
