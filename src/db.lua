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
  CastHistoryDB = CastHistoryDB or {}
  CastHistoryDB.profile = CastHistoryDB.profile or {}
  for k, v in pairs(defaults) do
    if CastHistoryDB.profile[k] == nil then
      CastHistoryDB.profile[k] = v
    end
  end
  CastHistoryDB.debug = CastHistoryDB.debug or false
  CastHistoryDB.log = CastHistoryDB.log or {}
  self.profile = CastHistoryDB.profile
  self.defaults = defaults
end
