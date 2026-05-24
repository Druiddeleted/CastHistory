local _, ns = ...

ns.Options = {}

local function makeCheck(parent, label, key, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
  cb.Text:SetText(label)
  cb:SetChecked(ns.DB.profile[key])
  cb:SetScript("OnClick", function(self)
    ns.DB.profile[key] = self:GetChecked() and true or false
    if onChange then onChange() end
  end)
  return cb
end

local function makeSlider(parent, label, key, minV, maxV, step, onChange)
  local s = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
  s:SetWidth(220)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  s:SetObeyStepOnDrag(true)
  s:SetValue(ns.DB.profile[key])
  s.Low:SetText(tostring(minV))
  s.High:SetText(tostring(maxV))
  s.Text:SetText(label .. ": " .. ns.DB.profile[key])
  s:SetScript("OnValueChanged", function(self, v)
    if step >= 1 then v = math.floor(v + 0.5) end
    ns.DB.profile[key] = v
    self.Text:SetText(label .. ": " .. (step >= 1 and v or string.format("%.2f", v)))
    if onChange then onChange() end
  end)
  return s
end

function ns.Options:Register()
  local panel = CreateFrame("Frame")
  panel.name = "CastTimeline"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("CastTimeline")

  local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  desc:SetText("Horizontal timeline of your recent casts with GCD reference markers.")

  local apply = function() ns.UI:ApplyLayout() end

  local cbShown = makeCheck(panel, "Show frame", "shown", function()
    if ns.DB.profile.shown then ns.UI.frame:Show() else ns.UI.frame:Hide() end
  end)
  cbShown:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -16)

  local cbBg = makeCheck(panel, "Show background", "background", apply)
  cbBg:SetPoint("TOPLEFT", cbShown, "BOTTOMLEFT", 0, -4)

  local cbBase = makeCheck(panel, "Show base 1.5s GCD markers", "showBaseGCD")
  cbBase:SetPoint("TOPLEFT", cbBg, "BOTTOMLEFT", 0, -4)

  local cbHasted = makeCheck(panel, "Show haste-adjusted GCD markers", "showHastedGCD")
  cbHasted:SetPoint("TOPLEFT", cbBase, "BOTTOMLEFT", 0, -4)

  local cbNames = makeCheck(panel, "Show spell names under icons", "showSpellNames", apply)
  cbNames:SetPoint("TOPLEFT", cbHasted, "BOTTOMLEFT", 0, -4)

  local growthLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  growthLabel:SetPoint("TOPLEFT", cbNames, "BOTTOMLEFT", 0, -16)
  growthLabel:SetText("Growth direction:")
  local growthDD = CreateFrame("Frame", "CastTimelineGrowthDropdown", panel, "UIDropDownMenuTemplate")
  growthDD:SetPoint("TOPLEFT", growthLabel, "BOTTOMLEFT", -16, -4)
  local growths = { "RIGHT", "LEFT", "UP", "DOWN" }
  local function setGrowth(value)
    ns.DB.profile.growth = value
    UIDropDownMenu_SetText(growthDD, value)
    ns.UI:ApplyLayout()
  end
  UIDropDownMenu_Initialize(growthDD, function(self, level)
    for _, v in ipairs(growths) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.func = function() setGrowth(v) end
      info.checked = (ns.DB.profile.growth == v)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetWidth(growthDD, 120)
  UIDropDownMenu_SetText(growthDD, ns.DB.profile.growth)

  local strataLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  strataLabel:SetPoint("TOPLEFT", growthDD, "BOTTOMLEFT", 16, -12)
  strataLabel:SetText("Frame strata:")
  local strataDD = CreateFrame("Frame", "CastTimelineStrataDropdown", panel, "UIDropDownMenuTemplate")
  strataDD:SetPoint("TOPLEFT", strataLabel, "BOTTOMLEFT", -16, -4)
  local stratas = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
  local function setStrata(value)
    ns.DB.profile.strata = value
    UIDropDownMenu_SetText(strataDD, value)
    ns.UI:ApplyLayout()
  end
  UIDropDownMenu_Initialize(strataDD, function(self, level)
    for _, v in ipairs(stratas) do
      local info = UIDropDownMenu_CreateInfo()
      info.text = v
      info.func = function() setStrata(v) end
      info.checked = (ns.DB.profile.strata == v)
      UIDropDownMenu_AddButton(info, level)
    end
  end)
  UIDropDownMenu_SetWidth(strataDD, 160)
  UIDropDownMenu_SetText(strataDD, ns.DB.profile.strata)

  local sWindow = makeSlider(panel, "Time window (seconds)", "windowSeconds", 3, 30, 1, apply)
  sWindow:SetPoint("TOPLEFT", strataDD, "BOTTOMLEFT", 16, -20)

  local sSize = makeSlider(panel, "Icon size", "iconSize", 16, 64, 1, apply)
  sSize:SetPoint("TOPLEFT", sWindow, "BOTTOMLEFT", 0, -32)

  local sMax = makeSlider(panel, "Max icons", "maxIcons", 5, 60, 1, apply)
  sMax:SetPoint("TOPLEFT", sSize, "BOTTOMLEFT", 0, -32)

  local sAlpha = makeSlider(panel, "Alpha", "alpha", 0.1, 1.0, 0.05, apply)
  sAlpha:SetPoint("TOPLEFT", sMax, "BOTTOMLEFT", 0, -32)

  local cbDebug = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
  cbDebug.Text:SetText("Debug logging (writes events to SavedVariables)")
  cbDebug:SetChecked(CastTimelineDB.debug)
  cbDebug:SetScript("OnClick", function(self)
    CastTimelineDB.debug = self:GetChecked() and true or false
  end)
  cbDebug:SetPoint("TOPLEFT", sAlpha, "BOTTOMLEFT", -16, -24)

  local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  reset:SetSize(140, 22)
  reset:SetText("Reset position")
  reset:SetPoint("TOPLEFT", cbDebug, "BOTTOMLEFT", 16, -16)
  reset:SetScript("OnClick", function()
    ns.DB.profile.point = ns.DB.defaults.point
    ns.DB.profile.relPoint = ns.DB.defaults.relPoint
    ns.DB.profile.x = ns.DB.defaults.x
    ns.DB.profile.y = ns.DB.defaults.y
    ns.UI.frame:ClearAllPoints()
    ns.UI.frame:SetPoint(ns.DB.profile.point, UIParent, ns.DB.profile.relPoint, ns.DB.profile.x, ns.DB.profile.y)
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory then
    local category = Settings.RegisterCanvasLayoutCategory(panel, "CastTimeline")
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
