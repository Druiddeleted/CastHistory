local _, ns = ...

-- Internal state that isn't a user-facing setting, so it has no schema entry.
local defaults = {
  locked = false,
  point = "CENTER",
  relPoint = "CENTER",
  x = 0,
  y = -200,
  -- Per Edit Mode layout position overrides, keyed by layout name. The
  -- top-level point/relPoint/x/y above stay as the baseline fallback for any
  -- layout not present here (see DB:GetPosition).
  layouts = {},
}

-- Every user-facing setting's default comes from the schema, so the value, its
-- label and its controls are declared in exactly one place. Merged in rather
-- than referenced so ns.DB.defaults stays a single flat table -- callers read
-- ns.DB.defaults.iconSize and ns.DB.defaults.point alike.
for key, value in pairs(ns.Settings:Defaults()) do
  defaults[key] = value
end

ns.DB = {}

function ns.DB:Init()
  CastHistoryDB = CastHistoryDB or {}
  CastHistoryDB.profile = CastHistoryDB.profile or {}
  for k, v in pairs(defaults) do
    if CastHistoryDB.profile[k] == nil then
      CastHistoryDB.profile[k] = v
    end
  end
  -- Assigned on its own line rather than via the defaults loop above: that loop
  -- would alias the single defaults.layouts table into the saved profile, so
  -- writes would leak across reloads/characters. This gives each profile its own.
  CastHistoryDB.profile.layouts = CastHistoryDB.profile.layouts or {}
  CastHistoryDB.debug = CastHistoryDB.debug or false
  CastHistoryDB.log = CastHistoryDB.log or {}
  self.profile = CastHistoryDB.profile
  self.defaults = defaults
end

-- Position is stored per Edit Mode layout so the frame respects the active HUD
-- profile. A layout with no saved entry falls back to the top-level
-- point/relPoint/x/y -- which is exactly what every existing user already has,
-- so upgrading moves nothing until they reposition the frame within a layout.
-- layoutName may be nil (LibEditMode absent, or the layout not yet known at
-- login); in that case we read/write the top-level baseline directly.
function ns.DB:GetPosition(layoutName)
  local p = self.profile
  local entry = layoutName and p.layouts[layoutName]
  if entry then
    return entry.point, entry.relPoint, entry.x, entry.y
  end
  return p.point, p.relPoint, p.x, p.y
end

function ns.DB:SetPosition(layoutName, point, relPoint, x, y)
  local p = self.profile
  if not layoutName then
    p.point, p.relPoint, p.x, p.y = point, relPoint, x, y
    return
  end
  local entry = p.layouts[layoutName]
  if not entry then
    entry = {}
    p.layouts[layoutName] = entry
  end
  entry.point, entry.relPoint, entry.x, entry.y = point, relPoint, x, y
end

-- Migrate a layout's saved position when its Edit Mode layout is renamed, so
-- the frame keeps its place. Drop an entry when its layout is deleted.
function ns.DB:RenameLayout(oldName, newName)
  local layouts = self.profile.layouts
  if oldName and newName and layouts[oldName] and not layouts[newName] then
    layouts[newName] = layouts[oldName]
    layouts[oldName] = nil
  end
end

function ns.DB:DeleteLayout(name)
  if name then self.profile.layouts[name] = nil end
end
