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

  local lib = LibStub and LibStub("LibEditMode", true)

  local f = CreateFrame("Frame", "CastHistoryFrame", UIParent, "BackdropTemplate")
  local w, h = self:CalcSize()
  f:SetSize(w, h)
  -- Position from the active Edit Mode layout. The layout may not be known yet
  -- at login (LibEditMode loads it from the server slightly later); the 'layout'
  -- callback registered below repositions us once it is, and on every switch.
  local initLayout = lib and lib:GetActiveLayoutName()
  local point, relPoint, x, y = ns.DB:GetPosition(initLayout)
  f:SetPoint(point, UIParent, relPoint, x, y)
  f:SetFrameStrata(p.strata or "HIGH")
  f:SetAlpha(p.alpha)
  f:SetClampedToScreen(true)
  f.editModeName = "CastHistory"

  applyBackdrop(f, p.background)

  local function snapToGrid(frame, layoutName)
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
    ns.DB:SetPosition(layoutName, "CENTER", "CENTER", snappedX, snappedY)
  end

  if lib then
    -- layoutName is the active Edit Mode layout, so each HUD profile records its
    -- own position; layouts left untouched keep falling back to the baseline.
    lib:AddFrame(f, function(frame, layoutName, point, x, y)
      ns.DB:SetPosition(layoutName, point, point, x, y)
      snapToGrid(frame, layoutName)
    end, {
      point = ns.DB.defaults.point,
      x = ns.DB.defaults.x,
      y = ns.DB.defaults.y,
    }, "CastHistory")

    -- Reposition whenever the Edit Mode layout changes. This also fires once at
    -- login as soon as the active layout is known.
    lib:RegisterCallback("layout", function()
      ns.UI:ApplyPosition()
    end)
    lib:RegisterCallback("rename", function(oldName, newName)
      ns.DB:RenameLayout(oldName, newName)
    end)
    lib:RegisterCallback("delete", function(name)
      ns.DB:DeleteLayout(name)
    end)

    -- Mapped straight off the settings schema, so a setting added there shows
    -- up here without touching this file.
    local KINDS = {
      slider = lib.SettingType.Slider,
      toggle = lib.SettingType.Checkbox,
      choice = lib.SettingType.Dropdown,
    }
    local editModeSettings = {}
    for entry in ns.Settings:Each("editMode") do
      editModeSettings[#editModeSettings + 1] = {
        kind = KINDS[entry.kind],
        name = entry.label,
        default = entry.default,
        minValue = entry.min, maxValue = entry.max, valueStep = entry.step,
        values = entry.values,
        get = function() return ns.Settings:Get(entry) end,
        set = function(_, value) ns.Settings:Set(entry, value) end,
      }
    end
    lib:AddFrameSettings(f, editModeSettings)

    lib:AddFrameSettingsButtons(f, {
      {
        text = "Reset position",
        click = function()
          -- Reset only the active layout's position so other HUD profiles keep
          -- theirs.
          local layoutName = lib:GetActiveLayoutName()
          local d = ns.DB.defaults
          ns.DB:SetPosition(layoutName, d.point, d.relPoint, d.x, d.y)
          ns.UI:ApplyPosition()
        end,
      },
    })
  end

  f.nowLine = f:CreateTexture(nil, "ARTWORK")
  f.nowLine:SetColorTexture(1, 1, 1, 0.7)

  f.gcdTextures = {}
  f.icons = {}
  -- Reused across frames so the per-frame Refresh doesn't allocate: a scratch
  -- list for icon collision-stacking, and the count of icons shown last frame.
  self.placed = {}
  self.shownIcons = 0

  f:SetScript("OnUpdate", function() ns.UI:Refresh() end)

  -- Marker spacing depends on the haste-adjusted GCD, so re-place the markers
  -- when it changes rather than recomputing them every frame in Refresh.
  ns.GCD:OnChange(function() ns.UI:LayoutGCDMarkers() end)

  self.frame = f
  self:ApplyLayout()
  -- Settle on the active layout's position now that self.frame exists: AddFrame
  -- above can make LibEditMode learn the active layout mid-Build, when the
  -- 'layout' callback would have no-op'd because self.frame wasn't set yet.
  self:ApplyPosition()
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

-- Lay out the GCD reference markers. These sit at fixed offsets from the
-- "now" anchor (secs * pixels-per-second) and so DON'T move as time passes --
-- the only thing that changes their spacing is the haste-adjusted GCD or a
-- layout setting. So this runs from ApplyLayout (settings change) and from the
-- GCD change callback registered in Build, NOT from the per-frame Refresh.
function ns.UI:LayoutGCDMarkers()
  local f = self.frame
  if not f then return end
  local p = ns.DB.profile
  local d = dir()
  local pps = pxPerSec()

  local gcdIdx = 1
  if p.showBaseGCD then
    local secs = 1.5
    while secs <= p.windowSeconds do
      local tex = self:GetGCDTex(gcdIdx)
      tex:SetColorTexture(0.6, 0.6, 0.6, 0.45)
      placeGCDMarker(tex, d, p, secs * pps)
      gcdIdx = gcdIdx + 1
      secs = secs + 1.5
    end
  end
  if p.showHastedGCD then
    local step = ns.GCD:Get()
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
end

function ns.UI:Refresh()
  local f = self.frame
  if not f:IsShown() then return end
  local p = ns.DB.profile
  local d = dir()
  local now = GetTime()
  local pps = pxPerSec()

  -- Pruning happens inside Window; the timeline just asks for what's visible.
  local casts = ns.Casts:Window(p.windowSeconds)

  -- Idle fast-path: with nothing in the window there are no icons to animate,
  -- so skip all per-frame work. GCD markers are laid out elsewhere (see
  -- LayoutGCDMarkers) and stay put, so we only clear icons shown last frame.
  if #casts == 0 then
    for i = 1, self.shownIcons do f.icons[i]:Hide() end
    self.shownIcons = 0
    return
  end

  local visible = 0
  local placed = self.placed
  local placedN = 0
  local threshold = p.iconSize * 0.6
  for _, cast in ipairs(casts) do
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
      for j = 1, placedN do
        local prev = placed[j]
        if math.abs(prev.px - agePx) < threshold and prev.stack == stack then
          stack = stack + 1
        end
      end
      -- Reuse the scratch slot instead of allocating a fresh subtable: this
      -- runs every frame, so per-frame allocations would churn the GC.
      placedN = placedN + 1
      local slot = placed[placedN]
      if not slot then slot = {}; placed[placedN] = slot end
      slot.px = agePx
      slot.stack = stack
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
  -- Only hide icons that were actually shown last frame (anything above that
  -- high-water mark is already hidden), then record this frame's count.
  for i = visible + 1, self.shownIcons do f.icons[i]:Hide() end
  self.shownIcons = visible
end

-- Move the frame to the position saved for the active Edit Mode layout (falling
-- back to the baseline for layouts that have never been positioned). Called at
-- login and on every layout switch via LibEditMode's 'layout' callback.
function ns.UI:ApplyPosition()
  if not self.frame then return end
  local lib = LibStub and LibStub("LibEditMode", true)
  local layoutName = lib and lib:GetActiveLayoutName()
  local point, relPoint, x, y = ns.DB:GetPosition(layoutName)
  self.frame:ClearAllPoints()
  self.frame:SetPoint(point, UIParent, relPoint, x, y)
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

  self:LayoutGCDMarkers()
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
