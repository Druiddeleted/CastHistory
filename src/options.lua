local _, ns = ...

ns.Options = {}

-- Panel controls are built from the settings schema, so this file knows how to
-- draw a slider/toggle/choice but nothing about which settings exist.

local function makeToggle(panel, entry)
  local cb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(entry.label)
  cb:SetChecked(ns.Settings:Get(entry))
  cb:SetScript("OnClick", function(self)
    ns.Settings:Set(entry, self:GetChecked() and true or false)
  end)
  return cb
end

local function makeSlider(panel, entry)
  local s = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
  local step = entry.step or 1
  local function text(v)
    return entry.label .. ": " .. (step >= 1 and v or string.format("%.2f", v))
  end
  s:SetWidth(220)
  s:SetMinMaxValues(entry.min, entry.max)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:SetValue(ns.Settings:Get(entry))
  s.Low:SetText(tostring(entry.min))
  s.High:SetText(tostring(entry.max))
  s.Text:SetText(text(ns.Settings:Get(entry)))
  s:SetScript("OnValueChanged", function(self, v)
    if step >= 1 then v = math.floor(v + 0.5) end
    ns.Settings:Set(entry, v)
    self.Text:SetText(text(v))
  end)
  return s
end

local function makeChoice(panel, entry, index)
  local label = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  label:SetText(entry.label .. ":")

  local dd = CreateFrame("Frame", "CastHistory" .. entry.key .. "Dropdown", panel, "UIDropDownMenuTemplate")
  local function current()
    local value = ns.Settings:Get(entry)
    for _, v in ipairs(entry.values) do
      if v.value == value then return v.text end
    end
    return tostring(value)
  end
  UIDropDownMenu_Initialize(dd, function(_, level)
    for _, v in ipairs(entry.values) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v.text
      info.func = function()
        ns.Settings:Set(entry, v.value)
        UIDropDownMenu_SetText(dd, v.text)
      end
      info.checked = (ns.Settings:Get(entry) == v.value)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetWidth(dd, entry.width or 120)
  UIDropDownMenu_SetText(dd, current())
  return dd, label
end

function ns.Options:Register()
  local panel = CreateFrame("Frame")
  panel.name = "CastHistory"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("CastHistory")

  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetText("Horizontal timeline of your recent casts with GCD reference markers.")

  -- Absolute vertical cursor rather than a chain of relative anchors: the
  -- schema decides what's drawn and in what order, so the control above any
  -- given one isn't known here.
  local y = -80
  for entry in ns.Settings:Each("panel") do
    if entry.kind == "toggle" then
      local cb = makeToggle(panel, entry)
      cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
      y = y - 28
    elseif entry.kind == "slider" then
      local s = makeSlider(panel, entry)
      s:SetPoint("TOPLEFT", panel, "TOPLEFT", 24, y - 14)
      y = y - 56
    elseif entry.kind == "choice" then
      local dd, label = makeChoice(panel, entry)
      label:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
      dd:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, y - 18)
      y = y - 56
    end
  end

  -- Not a profile setting: debug logging is account-wide diagnostic state.
  local cbDebug = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cbDebug.Text:SetText("Debug logging (writes events to SavedVariables)")
  cbDebug:SetChecked(CastHistoryDB.debug)
  cbDebug:SetScript("OnClick", function(self)
    CastHistoryDB.debug = self:GetChecked() and true or false
  end)
  cbDebug:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y - 12)
  y = y - 48

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(140, 22)
  reset:SetText("Reset position")
  reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
  reset:SetScript("OnClick", function()
    -- Reset the active Edit Mode layout's position to default; other HUD
    -- profiles keep their own saved positions.
    local lib = LibStub and LibStub("LibEditMode", true)
    local layoutName = lib and lib:GetActiveLayoutName()
    local d = ns.DB.defaults
    ns.DB:SetPosition(layoutName, d.point, d.relPoint, d.x, d.y)
    ns.UI:ApplyPosition()
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "CastHistory")
    Settings.RegisterAddOnCategory(category)
    self.category = category
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end

  self.panel = panel
end

function ns.Options:Open()
  if Settings and self.category then
    Settings.OpenToCategory(self.category.ID)
  elseif InterfaceOptionsFrame_OpenToCategory then
    InterfaceOptionsFrame_OpenToCategory(self.panel)
    InterfaceOptionsFrame_OpenToCategory(self.panel)
  end
end
