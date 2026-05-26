local _, ns = ...

ns.UI = {}

-- Growth directions: where older casts go relative to "now".
-- axis:        H = horizontal timeline, V = vertical
-- nowAnchor:   edge of the frame that represents "now"
-- ageSign:     direction multiplier for older casts (along the long axis)
-- stackSign:   direction multiplier for stacking overlaps (along the short axis)
local DIRS = {
  LEFT  = { axis = "H", nowAnchor = "RIGHT",  ageSign = -1, stackSign =  1 },
  RIGHT = { axis = "H", nowAnchor = "LEFT",   ageSign =  1, stackSign =  1 },
  UP    = { axis = "V", nowAnchor = "BOTTOM", ageSign =  1, stackSign =  1 },
  DOWN  = { axis = "V", nowAnchor = "TOP",    ageSign = -1, stackSign =  1 },
}

local function dir()
  return DIRS[ns.DB.profile.growth] or DIRS.LEFT
end

local function applyBackdrop(frame, show)
  if show then
    if not frame.bg then
      frame.bg = frame:CreateTexture(nil, "BACKGROUND")
      frame.bg:SetAllPoints()
      frame.bg:SetColorTexture(0, 0, 0, 0.4)
    end
    frame.bg:Show()
  elseif frame.bg then
    frame.bg:Hide()
  end
end

local function pxPerSec()
  return math.max(ns.DB.profile.iconSize * 0.9, 24)
end

function ns.UI:CalcSize()
  local p = ns.DB.profile
  local long = p.windowSeconds * pxPerSec()
  local short = p.iconSize + (p.showSpellNames and 70 or 18)
  if dir().axis == "H" then
    return long, short
  else
    return short, long
  end
end

function ns.UI:Build()
  local p = ns.DB.profile

  local f = CreateFrame("Frame", "CastHistoryFrame", UIParent, "BackdropTemplate")
  local w, h = self:CalcSize()
  f:SetSize(w, h)
  f:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
  f:SetFrameStrata(p.strata or "HIGH")
  f:SetAlpha(p.alpha)
  f:SetClampedToScreen(true)
  f.editModeName = "CastHistory"

  applyBackdrop(f, p.background)

  local function snapToGrid(frame)
    if not EditModeManagerFrame or not EditModeManagerFrame.IsSnapEnabled then return end
    if not EditModeManagerFrame:IsSnapEnabled() then return end
    local grid = EditModeManagerFrame.Grid
    local spacing = grid and grid.gridSpacing or 30
    local fx, fy = frame:GetCenter()
    if not fx then return end
    local pcx, pcy = UIParent:GetCenter()
    if not pcx then return end
    local offX = fx - pcx
    local offY = fy - pcy
    local snappedX = math.floor(offX / spacing + 0.5) * spacing
    local snappedY = math.floor(offY / spacing + 0.5) * spacing
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", snappedX, snappedY)
    ns.DB.profile.point = "CENTER"
    ns.DB.profile.relPoint = "CENTER"
    ns.DB.profile.x = snappedX
    ns.DB.profile.y = snappedY
  end

  local lib = LibStub and LibStub("LibEditMode", true)
  if lib then
    lib:AddFrame(f, function(frame, _layout, point, x, y)
      ns.DB.profile.point = point
      ns.DB.profile.relPoint = point
      ns.DB.profile.x = x
      ns.DB.profile.y = y
      snapToGrid(frame)
    end, {
      point = p.point,
      x = p.x,
      y = p.y,
    }, "CastHistory")

    local function getter(key) return function() return ns.DB.profile[key] end end
    local function setter(key, after)
      return function(_, value)
        ns.DB.profile[key] = value
        ns.UI:ApplyLayout()
        if after then after() end
      end
    end

    lib:AddFrameSettings(f, {
      {
        kind = lib.SettingType.Slider, name = "Time window (s)",
        default = ns.DB.defaults.windowSeconds,
        minValue = 3, maxValue = 30, valueStep = 1,
        get = getter("windowSeconds"), set = setter("windowSeconds"),
      },
      {
        kind = lib.SettingType.Slider, name = "Icon size",
        default = ns.DB.defaults.iconSize,
        minValue = 16, maxValue = 64, valueStep = 1,
        get = getter("iconSize"), set = setter("iconSize"),
      },
      {
        kind = lib.SettingType.Slider, name = "Max icons",
        default = ns.DB.defaults.maxIcons,
        minValue = 5, maxValue = 60, valueStep = 1,
        get = getter("maxIcons"), set = setter("maxIcons"),
      },
      {
        kind = lib.SettingType.Slider, name = "Alpha",
        default = ns.DB.defaults.alpha,
        minValue = 0.1, maxValue = 1.0, valueStep = 0.05,
        get = getter("alpha"), set = setter("alpha"),
      },
      {
        kind = lib.SettingType.Dropdown, name = "Growth direction",
        default = ns.DB.defaults.growth,
        values = {
          { text = "Right", value = "RIGHT" },
          { text = "Left",  value = "LEFT" },
          { text = "Up",    value = "UP" },
          { text = "Down",  value = "DOWN" },
        },
        get = getter("growth"), set = setter("growth"),
      },
      {
        kind = lib.SettingType.Dropdown, name = "Frame strata",
        default = ns.DB.defaults.strata,
        values = {
          { text = "Background",       value = "BACKGROUND" },
          { text = "Low",              value = "LOW" },
          { text = "Medium",           value = "MEDIUM" },
          { text = "High",             value = "HIGH" },
          { text = "Dialog",           value = "DIALOG" },
          { text = "Fullscreen",       value = "FULLSCREEN" },
          { text = "Fullscreen Dialog", value = "FULLSCREEN_DIALOG" },
          { text = "Tooltip",          value = "TOOLTIP" },
        },
        get = getter("strata"), set = setter("strata"),
      },
      {
        kind = lib.SettingType.Checkbox, name = "Show background",
        default = ns.DB.defaults.background,
        get = getter("background"), set = setter("background"),
      },
      {
        kind = lib.SettingType.Checkbox, name = "Show base 1.5s GCD markers",
        default = ns.DB.defaults.showBaseGCD,
        get = getter("showBaseGCD"), set = setter("showBaseGCD"),
      },
      {
        kind = lib.SettingType.Checkbox, name = "Show haste-adjusted GCD",
        default = ns.DB.defaults.showHastedGCD,
        get = getter("showHastedGCD"), set = setter("showHastedGCD"),
      },
      {
        kind = lib.SettingType.Checkbox, name = "Show spell names",
        default = ns.DB.defaults.showSpellNames,
        get = getter("showSpellNames"), set = setter("showSpellNames"),
      },
    })

    lib:AddFrameSettingsButtons(f, {
      {
        text = "Reset position",
        click = function()
          ns.DB.profile.point = ns.DB.defaults.point
          ns.DB.profile.relPoint = ns.DB.defaults.relPoint
          ns.DB.profile.x = ns.DB.defaults.x
          ns.DB.profile.y = ns.DB.defaults.y
          f:ClearAllPoints()
          f:SetPoint(ns.DB.profile.point, UIParent, ns.DB.profile.relPoint, ns.DB.profile.x, ns.DB.profile.y)
        end,
      },
    })
  end

  f.nowLine = f:CreateTexture(nil, "ARTWORK")
  f.nowLine:SetColorTexture(1, 1, 1, 0.7)

  f.gcdTextures = {}
  f.icons = {}

  f:SetScript("OnUpdate", function() ns.UI:Refresh() end)

  self.frame = f
  self:ApplyLayout()
end

function ns.UI:GetIcon(i)
  local f = self.frame
  if f.icons[i] then return f.icons[i] end
  local btn = CreateFrame("Frame", nil, f)
  btn:SetSize(ns.DB.profile.iconSize, ns.DB.profile.iconSize)
  btn.bg = btn:CreateTexture(nil, "BACKGROUND")
  btn.bg:SetPoint("TOPLEFT", -1, 1)
  btn.bg:SetPoint("BOTTOMRIGHT", 1, -1)
  btn.bg:SetColorTexture(0, 0, 0, 1)
  btn.tex = btn:CreateTexture(nil, "ARTWORK")
  btn.tex:SetAllPoints()
  btn.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  btn.label:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 4, -2)
  btn.label:SetRotation(math.rad(-45))
  btn.label:SetJustifyH("LEFT")
  f.icons[i] = btn
  return btn
end

function ns.UI:GetGCDTex(i)
  local f = self.frame
  if f.gcdTextures[i] then return f.gcdTextures[i] end
  local t = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  f.gcdTextures[i] = t
  return t
end

local function placeGCDMarker(tex, d, p, offsetPx)
  tex:ClearAllPoints()
  if d.axis == "H" then
    tex:SetSize(1, p.iconSize + 4)
    tex:SetPoint(d.nowAnchor, tex:GetParent(), d.nowAnchor, d.ageSign * offsetPx, 0)
  else
    tex:SetSize(p.iconSize + 4, 1)
    tex:SetPoint(d.nowAnchor, tex:GetParent(), d.nowAnchor, 0, d.ageSign * offsetPx)
  end
  tex:Show()
end

local function placeIcon(btn, d, p, agePx, stackIdx)
  local stackOffset = stackIdx * (p.iconSize + 2)
  btn:ClearAllPoints()
  if d.axis == "H" then
    btn:SetPoint("CENTER", btn:GetParent(), d.nowAnchor, d.ageSign * agePx, 2 + stackOffset)
  else
    btn:SetPoint("CENTER", btn:GetParent(), d.nowAnchor, d.stackSign * stackOffset, d.ageSign * agePx)
  end
end

function ns.UI:Refresh()
  local f = self.frame
  if not f:IsShown() then return end
  local p = ns.DB.profile
  local d = dir()
  local now = GetTime()
  local pps = pxPerSec()

  ns.Tracker:Prune(p.windowSeconds)

  local gcdIdx = 1
  if p.showBaseGCD then
    local step = 1.5
    local secs = step
    while secs <= p.windowSeconds do
      local tex = self:GetGCDTex(gcdIdx)
      tex:SetColorTexture(0.6, 0.6, 0.6, 0.45)
      placeGCDMarker(tex, d, p, secs * pps)
      gcdIdx = gcdIdx + 1
      secs = secs + step
    end
  end
  if p.showHastedGCD then
    local step = ns.Tracker:GetHastedGCD()
    local secs = step
    while secs <= p.windowSeconds do
      local tex = self:GetGCDTex(gcdIdx)
      tex:SetColorTexture(0.2, 0.8, 1.0, 0.55)
      placeGCDMarker(tex, d, p, secs * pps)
      gcdIdx = gcdIdx + 1
      secs = secs + step
    end
  end
  for i = gcdIdx, #f.gcdTextures do f.gcdTextures[i]:Hide() end

  local visible = 0
  local placed = {}
  local threshold = p.iconSize * 0.6
  for _, cast in ipairs(ns.Tracker.casts) do
    local age = now - cast.t
    if age <= p.windowSeconds and visible < p.maxIcons then
      visible = visible + 1
      local btn = self:GetIcon(visible)
      btn:SetSize(p.iconSize, p.iconSize)
      btn.tex:SetTexture(cast.icon)
      local agePx = age * pps
      -- On-GCD spells live on row 0 (the "main" timeline). Off-GCD spells
      -- (trinkets, racials, etc.) start one row above so they never sit on
      -- the GCD line, and stack further up only if they collide with each
      -- other in time.
      local stack = cast.onGCD and 0 or 1
      for _, prev in ipairs(placed) do
        if math.abs(prev.px - agePx) < threshold and prev.stack == stack then
          stack = stack + 1
        end
      end
      table.insert(placed, { px = agePx, stack = stack })
      placeIcon(btn, d, p, agePx, stack)
      if p.showSpellNames and d.axis == "H" then
        btn.label:SetText(cast.name)
        btn.label:Show()
      else
        btn.label:Hide()
      end
      btn:Show()
    end
  end
  for i = visible + 1, #f.icons do f.icons[i]:Hide() end
end

function ns.UI:ApplyLayout()
  if not self.frame then return end
  local p = ns.DB.profile
  local d = dir()
  local w, h = self:CalcSize()
  self.frame:SetSize(w, h)
  self.frame:SetAlpha(p.alpha)
  self.frame:SetFrameStrata(p.strata or "HIGH")
  applyBackdrop(self.frame, p.background)

  self.frame.nowLine:ClearAllPoints()
  if d.axis == "H" then
    self.frame.nowLine:SetSize(1, p.iconSize + 4)
    self.frame.nowLine:SetPoint(d.nowAnchor, self.frame, d.nowAnchor, 0, 0)
  else
    self.frame.nowLine:SetSize(p.iconSize + 4, 1)
    self.frame.nowLine:SetPoint(d.nowAnchor, self.frame, d.nowAnchor, 0, 0)
  end
end

function ns.UI:Toggle()
  if not self.frame then return end
  if self.frame:IsShown() then
    self.frame:Hide()
    ns.DB.profile.shown = false
  else
    self.frame:Show()
    ns.DB.profile.shown = true
  end
end
