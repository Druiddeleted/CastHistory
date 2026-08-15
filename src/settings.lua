local _, ns = ...

-- The single declaration of every user-facing setting. Three surfaces render
-- from this list: DB derives its defaults from it, UI maps it into the Edit
-- Mode selection dialog, and Options renders it as a config panel. Adding a
-- setting means adding one entry here and nothing else.
--
-- kind      slider | toggle | choice
-- apply     what to run after a change: see APPLY below. nil = nothing to
--           repaint (the setting only affects casts recorded from now on).
-- editMode  appears in the Edit Mode selection dialog
-- panel     appears in the /ch config panel
ns.Settings = {}

local APPLY = {
  layout = function()
    ns.UI:ApplyLayout()
  end,
  visibility = function()
    if ns.DB.profile.shown then ns.UI.frame:Show() else ns.UI.frame:Hide() end
  end,
}

-- Ordered: the render order on both surfaces.
ns.Settings.schema = {
  {
    key = "shown", kind = "toggle", label = "Show frame",
    default = true, apply = "visibility",
    -- Edit Mode has its own per-frame show/hide, so this would be a duplicate
    -- control there.
    editMode = false, panel = true,
  },
  {
    key = "windowSeconds", kind = "slider", label = "Time window (s)",
    default = 8, min = 3, max = 30, step = 1, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "iconSize", kind = "slider", label = "Icon size",
    default = 32, min = 16, max = 64, step = 1, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "maxIcons", kind = "slider", label = "Max icons",
    default = 30, min = 5, max = 60, step = 1, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "alpha", kind = "slider", label = "Alpha",
    default = 1.0, min = 0.1, max = 1.0, step = 0.05, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "growth", kind = "choice", label = "Growth direction",
    default = "RIGHT", apply = "layout", width = 120,
    values = {
      { text = "Right", value = "RIGHT" },
      { text = "Left",  value = "LEFT" },
      { text = "Up",    value = "UP" },
      { text = "Down",  value = "DOWN" },
    },
    editMode = true, panel = true,
  },
  {
    key = "strata", kind = "choice", label = "Frame strata",
    default = "HIGH", apply = "layout", width = 160,
    values = {
      { text = "Background",        value = "BACKGROUND" },
      { text = "Low",               value = "LOW" },
      { text = "Medium",            value = "MEDIUM" },
      { text = "High",              value = "HIGH" },
      { text = "Dialog",            value = "DIALOG" },
      { text = "Fullscreen",        value = "FULLSCREEN" },
      { text = "Fullscreen Dialog", value = "FULLSCREEN_DIALOG" },
      { text = "Tooltip",           value = "TOOLTIP" },
    },
    editMode = true, panel = true,
  },
  {
    key = "background", kind = "toggle", label = "Show background",
    default = true, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "showBaseGCD", kind = "toggle", label = "Show base 1.5s GCD markers",
    default = true, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "showHastedGCD", kind = "toggle", label = "Show haste-adjusted GCD markers",
    default = true, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "showSpellNames", kind = "toggle", label = "Show spell names under icons",
    default = false, apply = "layout",
    editMode = true, panel = true,
  },
  {
    key = "hideInternal", kind = "toggle", label = "Hide internal/system spells you didn't cast",
    default = true,
    editMode = true, panel = true,
  },
}

-- Run a setting's side effect after its value changes.
function ns.Settings:Apply(entry)
  local fn = entry.apply and APPLY[entry.apply]
  if fn then fn() end
end

-- Write a value and run its side effect. The single write path for every
-- surface, so a setting can never be changed without its repaint.
function ns.Settings:Set(entry, value)
  ns.DB.profile[entry.key] = value
  self:Apply(entry)
end

function ns.Settings:Get(entry)
  return ns.DB.profile[entry.key]
end

-- Every schema default, keyed by setting. DB merges these into its own
-- internal (non-user-facing) defaults such as the frame position.
function ns.Settings:Defaults()
  local d = {}
  for _, entry in ipairs(self.schema) do
    d[entry.key] = entry.default
  end
  return d
end

function ns.Settings:Each(surface)
  local i = 0
  return function()
    repeat
      i = i + 1
      local entry = self.schema[i]
      if not entry then return nil end
      if entry[surface] then return entry end
    until false
  end
end
