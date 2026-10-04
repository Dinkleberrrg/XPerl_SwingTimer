--=====================================================================
-- Options window in XPerl style.
--
-- XPerl_Options is a 563 KB hard-wired XML without a registration API -
-- other modules cannot add themselves there. So this is a separate panel
-- with the same look, plus a button that is hooked into XPerl's options
-- window as soon as that one is loaded on demand.
--=====================================================================

local XPS = XPerl_SwingTimer
local panel
local refreshing   -- true while the panel is filled from the config

local function Check(parent, key, label, tip, x, y)
    local name = "XPerlSwingOpt_" .. key
    local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    c:SetWidth(22); c:SetHeight(22)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    getglobal(name .. "Text"):SetText(label)
    c.tooltipText = tip
    c:SetScript("OnClick", function()
        if this.key == "locked" then
            XPS:SetLocked(this:GetChecked() and true or false)
        else
            XPS:Set(this.key, this:GetChecked() and 1 or 0)
        end
    end)
    c:SetScript("OnEnter", function()
        if this.tooltipText then
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(this.tooltipText, nil, nil, nil, nil, 1)
        end
    end)
    c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c.key = key
    return c
end

local function Slider(parent, key, label, lo, hi, step, x, y)
    local name = "XPerlSwingOpt_" .. key
    local s = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    s:SetWidth(150); s:SetHeight(16)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 6, y)
    s:SetMinMaxValues(lo, hi); s:SetValueStep(step)
    getglobal(name .. "Low"):SetText(lo)
    getglobal(name .. "High"):SetText(hi)
    s.labelText = label
    s:SetScript("OnValueChanged", function()
        local v = this:GetValue()
        if step >= 1 then v = floor(v + 0.5) else v = floor(v * 100 + 0.5) / 100 end
        getglobal(this:GetName() .. "Text"):SetText(this.labelText .. ": " .. v)
        if not refreshing and this.key then XPS:Set(this.key, v) end
    end)
    s.key = key
    return s
end

local function Swatch(parent, key, label, x, y)
    local b = CreateFrame("Button", "XPerlSwingOpt_" .. key, parent)
    b:SetWidth(16); b:SetHeight(16)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + 6, y)
    b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8,
                    insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    local t = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t:SetPoint("LEFT", b, "RIGHT", 6, 0)
    t:SetText(label)
    b.key = key
    b:SetScript("OnClick", function()
        local k = this.key
        local c = XPS:Get(k)
        local function apply()
            local r, g, bl = ColorPickerFrame:GetColorRGB()
            XPS:Set(k, { r, g, bl })
            getglobal("XPerlSwingOpt_" .. k):SetBackdropColor(r, g, bl, 1)
        end
        ColorPickerFrame.hasOpacity = nil
        ColorPickerFrame.previousValues = { c[1], c[2], c[3] }
        ColorPickerFrame.func = apply
        ColorPickerFrame.cancelFunc = function()
            local p = ColorPickerFrame.previousValues
            XPS:Set(k, { p[1], p[2], p[3] })
            getglobal("XPerlSwingOpt_" .. k):SetBackdropColor(p[1], p[2], p[3], 1)
        end
        ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
        ColorPickerFrame:Hide(); ColorPickerFrame:Show()
    end)
    return b
end

local function Header(parent, text, x, y)
    local f = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    f:SetText("|cFF40FF40" .. text .. "|r")
    return f
end

local widgets = {}

local function BuildPanel()
    if panel then return panel end

    panel = CreateFrame("Frame", "XPerlSwingOptions", UIParent)
    panel:SetWidth(470); panel:SetHeight(530)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 } })
    panel:SetMovable(true); panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop",  function() this:StopMovingOrSizing() end)
    panel:SetFrameStrata("DIALOG")
    panel:Hide()

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", panel, "TOP", 0, -18)
    title:SetText("X-Perl |cFF40FF40SwingTimer|r")

    local L, R = 24, 240

    -- Fixed Y values instead of arithmetic: otherwise the left and right
    -- columns quickly overlap when a row is added later.
    Header(panel, "Bars", L, -50)
    widgets.enabled       = Check(panel, "enabled",      "Module enabled",           "Turns off all bars without removing the add-on.", L, -72)
    widgets.showMainhand  = Check(panel, "showMainhand", "Main hand",                nil, L, -94)
    widgets.showOffhand   = Check(panel, "showOffhand",  "Off hand",                 "Only visible when dual wielding.", L, -116)
    widgets.showRanged    = Check(panel, "showRanged",   "Ranged / thrown",          "Bow, gun, crossbow, thrown weapon, wand.", L, -138)
    widgets.showTargetMob = Check(panel, "showTargetMob","Target: creatures",        "Swing timer of the targeted enemy.", L, -160)
    widgets.showTargetPvP = Check(panel, "showTargetPvP","Target: enemy players",    nil, L, -182)
    widgets.combatOnly    = Check(panel, "combatOnly",   "Only in combat",           "Hides the bars outside of combat.", L, -204)
    widgets.useSuperWoW   = Check(panel, "useSuperWoW",  "Use SuperWoW",             "Exact detection: every real swing per hand, ranged shots, and the target's swings at anyone. Off or without SuperWoW = combat log.|nSuperWoW: " .. (SUPERWOW_VERSION and ("|cFF40FF40found (" .. SUPERWOW_VERSION .. ")|r") or "|cFFFF4040not found|r"), L, -226)

    Header(panel, "Anchoring", L, -258)
    widgets.attachPlayer  = Check(panel, "attachPlayer", "Dock to X-Perl player",    "Off = free placement (unlock the bars to move them).", L, -280)
    widgets.attachTarget  = Check(panel, "attachTarget", "Dock to X-Perl target",    "Off = free placement (unlock the bars to move them).", L, -302)
    widgets.autoWidth     = Check(panel, "autoWidth",    "Width from frame",         "Takes the width of the unit frame. Off = fixed value on the right.", L, -324)
    widgets.locked        = Check(panel, "locked",       "Lock bars",                "Off = bars are shown and can be dragged with the left mouse button. Dragging a docked bar detaches it. /xps unlock, /xps lock, /xps reset", L, -346)

    Header(panel, "Colours", L, -378)
    widgets.colMH     = Swatch(panel, "colMH",     "Main hand", L,     -402)
    widgets.colOH     = Swatch(panel, "colOH",     "Off hand",  L+110, -402)
    widgets.colRanged = Swatch(panel, "colRanged", "Ranged",    L,     -426)
    widgets.colTarget = Swatch(panel, "colTarget", "Target",    L+110, -426)

    Header(panel, "Appearance", R, -50)
    widgets.xperlTexture  = Check(panel, "xperlTexture", "X-Perl bar texture",       "Off = flat colour.", R, -72)
    widgets.background    = Check(panel, "background",   "Dark background",          nil, R, -94)
    widgets.spark         = Check(panel, "spark",        "Spark",                    nil, R, -116)
    widgets.showLabel     = Check(panel, "showLabel",    "Label on the left",        "Weapon and speed.", R, -138)
    widgets.showTimer     = Check(panel, "showTimer",    "Time left on the right",   nil, R, -160)
    widgets.protoFont     = Check(panel, "protoFont",    "Prototype font",           "Off = Blizzard default font. Needs ShaguPlates, otherwise the default font is used.", R, -182)

    widgets.height    = Slider(panel, "height",    "Height",            4,   24, 1, R, -222)
    widgets.width     = Slider(panel, "width",     "Fixed width",       80, 400, 5, R, -260)
    widgets.gap       = Slider(panel, "gap",       "Bar spacing",       0,   12, 1, R, -298)
    widgets.padding   = Slider(panel, "padding",   "Distance to frame",-10, 30, 1, R, -336)
    widgets.fontSize  = Slider(panel, "fontSize",  "Font size",         6,   18, 1, R, -374)
    widgets.decimals  = Slider(panel, "decimals",  "Decimal places",    0,    2, 1, R, -412)

    -- show / move the bars and preview the settings without a fight
    local unlock = CreateFrame("Button", "XPerlSwingOpt_Unlock", panel, "UIPanelButtonTemplate")
    unlock:SetWidth(100); unlock:SetHeight(22)
    unlock:SetPoint("BOTTOM", panel, "BOTTOM", -60, 46)
    unlock:SetScript("OnClick", function()
        XPS:SetLocked(XPS:Get("locked") == 0)
    end)
    panel.unlock = unlock

    local demo = CreateFrame("Button", "XPerlSwingOpt_Demo", panel, "UIPanelButtonTemplate")
    demo:SetWidth(100); demo:SetHeight(22)
    demo:SetPoint("BOTTOM", panel, "BOTTOM", 60, 46)
    demo:SetScript("OnClick", function()
        if XPS.demo then XPS:StopDemo() else XPS:StartDemo() end
    end)
    panel.demo = demo

    -- closing the options ends the demo
    panel:SetScript("OnHide", function() XPS:StopDemo() end)

    local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    close:SetWidth(100); close:SetHeight(22)
    close:SetPoint("BOTTOM", panel, "BOTTOM", 60, 18)
    close:SetText("Close")
    close:SetScript("OnClick", function() panel:Hide() end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetWidth(100); reset:SetHeight(22)
    reset:SetPoint("BOTTOM", panel, "BOTTOM", -60, 18)
    reset:SetText("Defaults")
    reset:SetScript("OnClick", function()
        XPerlSwingConfig = {}
        XPS:ApplyLayout()
        XPerl_SwingTimer_RefreshOptions()
    end)

    return panel
end

function XPerl_SwingTimer_RefreshOptions()
    if not panel then return end
    refreshing = true
    for key, w in pairs(widgets) do
        local v = XPS:Get(key)
        if type(v) == "table" then
            w:SetBackdropColor(v[1], v[2], v[3], 1)
        elseif w.SetValue and w.GetObjectType and w:GetObjectType() == "Slider" then
            w:SetValue(v)
            getglobal(w:GetName() .. "Text"):SetText(w.labelText .. ": " .. v)
        else
            w:SetChecked(v == 1)
        end
    end
    refreshing = nil
    panel.unlock:SetText(XPS:Get("locked") == 1 and "Unlock bars" or "Lock bars")
    panel.demo:SetText(XPS.demo and "Stop demo" or "Demo")
end

function XPerl_SwingTimer_ToggleOptions()
    BuildPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        XPerl_SwingTimer_RefreshOptions()
        panel:Show()
    end
end

-- Hook a button into XPerl's options window as soon as it is loaded
local hook = CreateFrame("Frame")
hook:RegisterEvent("ADDON_LOADED")
hook:SetScript("OnEvent", function()
    if arg1 ~= "XPerl_Options" then return end
    if not XPerl_Options or XPerl_Options.swingButton then return end
    local b = CreateFrame("Button", nil, XPerl_Options, "UIPanelButtonTemplate")
    b:SetWidth(110); b:SetHeight(21)
    b:SetPoint("TOPRIGHT", XPerl_Options, "TOPRIGHT", -40, -16)
    b:SetText("SwingTimer")
    b:SetScript("OnClick", function() XPerl_SwingTimer_ToggleOptions() end)
    XPerl_Options.swingButton = b
    hook:UnregisterEvent("ADDON_LOADED")
end)
