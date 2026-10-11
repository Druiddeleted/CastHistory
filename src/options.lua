local _, ns = ...

ns.Options = {}

-- The /ch config page, built on Blizzard's native vertical settings layout
-- rather than controls hand-placed on a fixed canvas. Blizzard owns spacing and
-- scrolling, so the page can't overflow as settings are added, and every
-- setting is findable from the Options search box.
--
-- Controls are built from the settings schema through proxy settings: the
-- native control reads and writes through ns.Settings, so a change made here
-- runs the same side effects as one made in the Edit Mode dialog.

-- Settings.VarType names the storage type; it's the plain Lua type name on
-- the clients we target, but resolve it through the table when it exists.
local function varType(value)
  local t = type(value)
  local vt = Settings.VarType
  if vt then
    return ({ boolean = vt.Boolean, number = vt.Number, string = vt.String })[t] or t
  end
  return t
end

-- Variable names are global across every addon's settings, so prefix them.
local function proxy(category, key, label, default, get, set)
  return Settings.RegisterProxySetting(category, "CastHistory_" .. key,
    varType(default), label, default, get, set)
end

-- Blizzard renamed CheckBox/DropDown to Checkbox/Dropdown in 11.0. Resolved in
-- Register rather than at file load, when Settings is guaranteed to exist.
local createCheckbox, createDropdown

local function addToggle(category, entry)
  local setting = proxy(category, entry.key, entry.label, entry.default,
    function() return ns.Settings:Get(entry) end,
    function(value) ns.Settings:Set(entry, value) end)
  createCheckbox(category, setting, entry.tooltip)
end

local function addSlider(category, entry)
  local step = entry.step or 1
  local setting = proxy(category, entry.key, entry.label, entry.default,
    function() return ns.Settings:Get(entry) end,
    function(value)
      -- Integer settings stay integers even if the slider hands back drift.
      if step >= 1 then value = math.floor(value + 0.5) end
      ns.Settings:Set(entry, value)
    end)
  local options = Settings.CreateSliderOptions(entry.min, entry.max, step)
  if MinimalSliderWithSteppersMixin then
    options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(value)
      return step >= 1 and tostring(math.floor(value + 0.5)) or string.format("%.2f", value)
    end)
  end
  Settings.CreateSlider(category, setting, options, entry.tooltip)
end

local function addChoice(category, entry)
  local setting = proxy(category, entry.key, entry.label, entry.default,
    function() return ns.Settings:Get(entry) end,
    function(value) ns.Settings:Set(entry, value) end)
  local function values()
    local container = Settings.CreateControlTextContainer()
    for _, v in ipairs(entry.values) do
      container:Add(v.value, v.text)
    end
    return container:GetData()
  end
  createDropdown(category, setting, values, entry.tooltip)
end

local ADD = { toggle = addToggle, slider = addSlider, choice = addChoice }

local function addHeader(layout, text)
  if CreateSettingsListSectionHeaderInitializer then
    layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
  end
end

function ns.Options:Register()
  -- Both clients we ship to (retail and Forever) have the native settings UI;
  -- without it /ch config simply has nothing to open.
  if not (Settings and Settings.RegisterVerticalLayoutCategory) then return end
  createCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
  createDropdown = Settings.CreateDropdown or Settings.CreateDropDown

  local category, layout = Settings.RegisterVerticalLayoutCategory("CastHistory")

  for entry in ns.Settings:Each("panel") do
    ADD[entry.kind](category, entry)
  end

  addHeader(layout, "Position")
  if CreateSettingsButtonInitializer then
    layout:AddInitializer(CreateSettingsButtonInitializer(
      "Frame position", "Reset",
      function() ns.UI:ResetPosition() end,
      "Move the timeline back to its default spot in the active Edit Mode layout. Other layouts keep their positions.",
      true))
  end

  addHeader(layout, "Diagnostics")
  -- Not a profile setting: debug logging is account-wide diagnostic state.
  local debug = proxy(category, "debug", "Debug logging", false,
    function() return CastHistoryDB.debug == true end,
    function(value) CastHistoryDB.debug = value and true or false end)
  createCheckbox(category, debug,
    "Record raw spell events to SavedVariables for /ch replay and /ch probe.")

  Settings.RegisterAddOnCategory(category)
  self.category = category
end

function ns.Options:Open()
  if self.category then
    Settings.OpenToCategory(self.category:GetID())
  end
end
