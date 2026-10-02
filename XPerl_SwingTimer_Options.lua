--=====================================================================
-- Optionsfenster im XPerl-Stil.
--
-- XPerl_Options ist eine 563 KB grosse, fest verdrahtete XML ohne
-- Registrierungs-API - fremde Module koennen sich dort nicht eintragen.
-- Deshalb ein eigenes Panel im gleichen Look, plus ein Knopf, der in
-- XPerls Optionsfenster eingehaengt wird, sobald das nachgeladen wird.
--=====================================================================

local XPS = XPerl_SwingTimer
local panel

local function Check(parent, key, label, tip, x, y)
    local name = "XPerlSwingOpt_" .. key
    local c = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate")
    c:SetWidth(22); c:SetHeight(22)
    c:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    getglobal(name .. "Text"):SetText(label)
    c.tooltipText = tip
    c:SetScript("OnClick", function()
        XPS:Set(key, this:GetChecked() and 1 or 0)
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
        XPS:Set(this.key, v)
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
    panel:SetWidth(470); panel:SetHeight(500)
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

    -- Feste Y-Werte statt Rechnerei: linke und rechte Spalte ueberschneiden
    -- sich sonst schnell, wenn man spaeter eine Zeile einfuegt.
    Header(panel, "Leisten", L, -50)
    widgets.enabled       = Check(panel, "enabled",      "Modul aktiv",              "Schaltet alle Leisten ab, ohne das Addon zu entfernen.", L, -72)
    widgets.showMainhand  = Check(panel, "showMainhand", "Haupthand",                nil, L, -94)
    widgets.showOffhand   = Check(panel, "showOffhand",  "Schildhand",               "Nur beim Beidhandkampf sichtbar.", L, -116)
    widgets.showRanged    = Check(panel, "showRanged",   "Fernkampf / Wurf",         "Bogen, Schusswaffe, Armbrust, Wurfwaffe, Zauberstab.", L, -138)
    widgets.showTargetMob = Check(panel, "showTargetMob","Ziel: Kreaturen",          "Swing-Timer des anvisierten Gegners.", L, -160)
    widgets.showTargetPvP = Check(panel, "showTargetPvP","Ziel: feindl. Spieler",    nil, L, -182)
    widgets.combatOnly    = Check(panel, "combatOnly",   "Nur im Kampf",             "Blendet die Leisten ausserhalb des Kampfes aus.", L, -204)

    Header(panel, "Verankerung", L, -236)
    widgets.attachPlayer  = Check(panel, "attachPlayer", "An XPerl-Playerframe",     "Aus = frei platzierbar.", L, -258)
    widgets.attachTarget  = Check(panel, "attachTarget", "An XPerl-Targetframe",     nil, L, -280)
    widgets.autoWidth     = Check(panel, "autoWidth",    "Breite vom Frame",         "Uebernimmt die Breite des Unitframes. Aus = fester Wert rechts.", L, -302)

    Header(panel, "Farben", L, -334)
    widgets.colMH     = Swatch(panel, "colMH",     "Haupthand",  L,     -358)
    widgets.colOH     = Swatch(panel, "colOH",     "Schildhand", L+110, -358)
    widgets.colRanged = Swatch(panel, "colRanged", "Fernkampf",  L,     -382)
    widgets.colTarget = Swatch(panel, "colTarget", "Ziel",       L+110, -382)

    Header(panel, "Darstellung", R, -50)
    widgets.xperlTexture  = Check(panel, "xperlTexture", "XPerl-Balkentextur",       "Aus = flache Farbflaeche.", R, -72)
    widgets.background    = Check(panel, "background",   "Dunkler Untergrund",       nil, R, -94)
    widgets.spark         = Check(panel, "spark",        "Laufmarke",                nil, R, -116)
    widgets.showLabel     = Check(panel, "showLabel",    "Beschriftung links",       "Waffe und Geschwindigkeit.", R, -138)
    widgets.showTimer     = Check(panel, "showTimer",    "Restzeit rechts",          nil, R, -160)
    widgets.protoFont     = Check(panel, "protoFont",    "Prototype-Schrift",        "Aus = Blizzard-Standardschrift.", R, -182)

    widgets.height    = Slider(panel, "height",    "Hoehe",            4,   24, 1, R, -222)
    widgets.width     = Slider(panel, "width",     "Feste Breite",     80, 400, 5, R, -260)
    widgets.gap       = Slider(panel, "gap",       "Balkenabstand",    0,   12, 1, R, -298)
    widgets.padding   = Slider(panel, "padding",   "Abstand zum Frame",-10, 30, 1, R, -336)
    widgets.fontSize  = Slider(panel, "fontSize",  "Schriftgroesse",   6,   18, 1, R, -374)
    widgets.decimals  = Slider(panel, "decimals",  "Nachkommastellen", 0,    2, 1, R, -412)

    local close = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    close:SetWidth(100); close:SetHeight(22)
    close:SetPoint("BOTTOM", panel, "BOTTOM", 60, 18)
    close:SetText("Schliessen")
    close:SetScript("OnClick", function() panel:Hide() end)

    local reset = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    reset:SetWidth(100); reset:SetHeight(22)
    reset:SetPoint("BOTTOM", panel, "BOTTOM", -60, 18)
    reset:SetText("Standard")
    reset:SetScript("OnClick", function()
        XPerlSwingConfig = {}
        XPS:ApplyLayout()
        XPerl_SwingTimer_RefreshOptions()
    end)

    return panel
end

function XPerl_SwingTimer_RefreshOptions()
    if not panel then return end
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

-- Knopf in XPerls Optionsfenster einhaengen, sobald es nachgeladen ist
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
