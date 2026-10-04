--=====================================================================
-- X-Perl SwingTimer
--
-- Standalone XPerl module. Does not need AttackBar any more - the swing
-- detection is rebuilt here. Delete the folder and it is gone.
--
-- Detection follows the same idea as AttackBar: vanilla has no swing
-- event, so every own melee hit in the combat log is treated as
-- "a swing just started", and the weapon speed from UnitAttackSpeed()
-- is used as the bar length.
--=====================================================================

XPerl_SwingTimer = {}
local XPS = XPerl_SwingTimer

local TEX_XPERL = "Interface\\AddOns\\XPerl\\Images\\XPerl_StatusBar"
local TEX_FLAT  = "Interface\\Buttons\\WHITE8X8"

XPS.defaults = {
    enabled        = 1,   -- module active
    combatOnly     = 0,   -- only show the bars in combat

    showMainhand   = 1,   -- main hand
    showOffhand    = 1,   -- off hand (only useful when dual wielding)
    showRanged     = 1,   -- ranged / thrown / wand
    showTargetMob  = 1,   -- swing timer of creatures
    showTargetPvP  = 1,   -- swing timer of enemy players

    attachPlayer   = 1,   -- dock to XPerl_Player instead of free placement
    attachTarget   = 1,   -- dock to XPerl_Target
    locked         = 1,   -- 0 = bars are shown and can be dragged
    autoWidth      = 1,   -- take the width from the unit frame
    width          = 200, -- fixed width if autoWidth is off
    height         = 9,
    gap            = 2,   -- spacing between main hand and off hand
    padding        = 2,   -- spacing to the unit frame

    xperlTexture   = 1,   -- XPerl's bar texture instead of a flat colour
    background     = 1,   -- dark background behind the bar
    spark          = 0,   -- spark at the end of the bar

    showLabel      = 1,   -- label on the left (weapon + speed)
    showTimer      = 1,   -- time left on the right
    decimals       = 1,   -- decimal places of the time left
    fontSize       = 9,
    -- [patch] bar font; 1 = Prototype, 0 = Blizzard default
    protoFont      = 0,

    colMH     = {0.10, 0.35, 1.00},
    colOH     = {0.00, 0.65, 0.95},
    colRanged = {0.20, 0.90, 0.30},
    colTarget = {0.90, 0.15, 0.15},

    -- free positions, {x, y} of the TOPLEFT corner relative to the
    -- BOTTOMLEFT of UIParent; nil = default spot near the screen centre
    posPlayer = nil,
    posTarget = nil,
}

--------------------------------------------------------------------- Config
function XPS:Get(k)
    if XPerlSwingConfig and XPerlSwingConfig[k] ~= nil then return XPerlSwingConfig[k] end
    return self.defaults[k]
end

function XPS:Set(k, v)
    if not XPerlSwingConfig then XPerlSwingConfig = {} end
    XPerlSwingConfig[k] = v
    self:ApplyLayout()
end

function XPS:Colour(k)
    local c = self:Get(k)
    return c[1], c[2], c[3]
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF40FF40X-Perl SwingTimer:|r " .. msg)
end

--------------------------------------------------------------------- Moving
-- Dragging a docked box detaches it, so the new spot sticks.
local function DragStart()
    if XPS:Get("locked") == 1 then return end
    this:StartMoving()
    this.moving = true
end

local function DragStop()
    if not this.moving then return end
    this:StopMovingOrSizing()
    this.moving = nil
    -- the client would otherwise also store the frame in layout-cache.txt
    -- and fight with our own anchoring on the next login
    if this.SetUserPlaced then this:SetUserPlaced(false) end

    if not XPerlSwingConfig then XPerlSwingConfig = {} end
    XPerlSwingConfig[this.posKey]    = { this:GetLeft(), this:GetTop() }
    XPerlSwingConfig[this.attachKey] = 0
    XPS:ApplyLayout()
    if XPerl_SwingTimer_RefreshOptions then XPerl_SwingTimer_RefreshOptions() end
end

--------------------------------------------------------------------- Building
local function MakeBar(name, parent)
    local bar = CreateFrame("StatusBar", name, parent)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:Hide()

    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints(bar)

    bar.spark = bar:CreateTexture(nil, "OVERLAY")
    bar.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    bar.spark:SetBlendMode("ADD")
    bar.spark:SetWidth(16)

    bar.label = bar:CreateFontString(nil, "OVERLAY")
    bar.label:SetJustifyH("LEFT")
    bar.timer = bar:CreateFontString(nil, "OVERLAY")
    bar.timer:SetJustifyH("RIGHT")

    bar:SetScript("OnUpdate", function() XPS:OnUpdate(this) end)
    return bar
end

local function MakeBox(name, posKey, attachKey)
    local box = CreateFrame("Frame", name, UIParent)
    box:SetMovable(true)
    box:SetClampedToScreen(true)
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", DragStart)
    box:SetScript("OnDragStop",  DragStop)
    box:SetScript("OnHide",      DragStop)
    box:SetBackdrop({ bgFile = TEX_FLAT })
    box:SetBackdropColor(0.25, 1, 0.25, 0.25)
    box.posKey, box.attachKey = posKey, attachKey
    return box
end

function XPS:Build()
    if self.built then return end

    self.playerBox = MakeBox("XPerlSwingPlayer", "posPlayer", "attachPlayer")
    self.playerBox:SetWidth(200); self.playerBox:SetHeight(20)
    self.mh = MakeBar("XPerlSwingMH", self.playerBox)
    self.oh = MakeBar("XPerlSwingOH", self.playerBox)

    self.targetBox = MakeBox("XPerlSwingTarget", "posTarget", "attachTarget")
    self.targetBox:SetWidth(200); self.targetBox:SetHeight(10)
    self.tb = MakeBar("XPerlSwingTB", self.targetBox)

    self.built = true
end

--------------------------------------------------------------------- Layout
function XPS:StyleBar(bar, w, r, g, b)
    local h  = self:Get("height")
    local fs = self:Get("fontSize")

    bar:SetWidth(w); bar:SetHeight(h)
    bar:SetStatusBarTexture(self:Get("xperlTexture") == 1 and TEX_XPERL or TEX_FLAT)
    -- keep the colour of a running bar (ranged shots use the main hand bar)
    if bar.preview or not bar:IsShown() then bar:SetStatusBarColor(r, g, b) end

    if self:Get("background") == 1 then
        bar.bg:SetTexture(self:Get("xperlTexture") == 1 and TEX_XPERL or TEX_FLAT)
        bar.bg:SetVertexColor(0, 0, 0, 0.5)
        bar.bg:Show()
    else
        bar.bg:Hide()
    end

    bar.spark:SetHeight(h * 2)
    if self:Get("spark") == 1 then bar.spark:Show() else bar.spark:Hide() end

    -- [patch] MONOCHROME turns off anti-aliasing; this makes the thin
    -- Prototype font sharp instead of blurry.
    local proto = (self:Get("protoFont") == 1)
    local fp = proto and "Interface\\AddOns\\ShaguPlates\\fonts\\Prototype.ttf"
                     or  "Fonts\\FRIZQT__.TTF"
    local fl = proto and "OUTLINE, MONOCHROME" or "OUTLINE"
    bar.label:SetFont(fp, fs, fl)
    bar.label:ClearAllPoints(); bar.label:SetPoint("LEFT", bar, "LEFT", 3, 0)
    bar.timer:SetFont(fp, fs, fl)
    bar.timer:ClearAllPoints(); bar.timer:SetPoint("RIGHT", bar, "RIGHT", -3, 0)

    if self:Get("showLabel") == 1 then bar.label:Show() else bar.label:Hide() end
    if self:Get("showTimer") == 1 then bar.timer:Show() else bar.timer:Hide() end
end

-- Width of the unit frame, converted into the box's scale. The XPerl
-- frames have their own scale setting, the boxes sit on UIParent.
-- GetWidth() also works while the frame is hidden (no target yet).
local function AnchorWidth(host, box, fallbackWidth)
    if host then
        local w = host:GetWidth()
        if w and w > 40 then
            return w * host:GetEffectiveScale() / box:GetEffectiveScale()
        end
    end
    return fallbackWidth
end

-- Docked: below the unit frame. Free: saved spot, or a default near the
-- screen centre so the box never ends up without an anchor.
function XPS:PlaceBox(box, host, posKey, defaultY)
    if box.moving then return end
    box:ClearAllPoints()
    if host then
        box:SetPoint("TOP", host, "BOTTOM", 0, -self:Get("padding"))
    else
        local pos = self:Get(posKey)
        if pos then
            box:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", pos[1], pos[2])
        else
            box:SetPoint("CENTER", UIParent, "CENTER", 0, defaultY)
        end
    end
end

function XPS:ApplyLayout()
    if not self.built then return end

    local h, gap = self:Get("height"), self:Get("gap")
    local fixedW = self:Get("width")
    local auto   = self:Get("autoWidth") == 1

    -- player bars
    local host = (self:Get("attachPlayer") == 1) and (XPerl_Player or PlayerFrame) or nil
    local w = auto and AnchorWidth(host, self.playerBox, fixedW) or fixedW

    self.playerBox:SetWidth(w); self.playerBox:SetHeight(h * 2 + gap)
    self:PlaceBox(self.playerBox, host, "posPlayer", -120)
    self:StyleBar(self.mh, w, self:Colour("colMH"))
    self:StyleBar(self.oh, w, self:Colour("colOH"))
    self.mh:ClearAllPoints(); self.mh:SetPoint("TOPLEFT", self.playerBox, "TOPLEFT", 0, 0)
    self.oh:ClearAllPoints(); self.oh:SetPoint("TOPLEFT", self.playerBox, "TOPLEFT", 0, -(h + gap))

    -- target bar
    local thost = (self:Get("attachTarget") == 1) and (XPerl_Target or TargetFrame) or nil
    local tw = auto and AnchorWidth(thost, self.targetBox, fixedW) or fixedW
    self.targetBox:SetWidth(tw); self.targetBox:SetHeight(h)
    self:PlaceBox(self.targetBox, thost, "posTarget", -160)
    self:StyleBar(self.tb, tw, self:Colour("colTarget"))
    self.tb:ClearAllPoints(); self.tb:SetPoint("TOPLEFT", self.targetBox, "TOPLEFT", 0, 0)

    self:UpdateLock()

    if self:Get("enabled") == 0 then
        self.mh:Hide(); self.oh:Hide(); self.tb:Hide()
    end
end

-- Unlocked: boxes take the mouse, get a green backdrop and show
-- placeholder bars, so even empty bars can be grabbed and placed.
function XPS:UpdateLock()
    local unlocked = self:Get("locked") == 0
    local boxes = { self.playerBox, self.targetBox }
    for i = 1, 2 do
        local box = boxes[i]
        box:EnableMouse(unlocked)
        if unlocked then box:SetBackdropColor(0.25, 1, 0.25, 0.25)
        else             box:SetBackdropColor(0, 0, 0, 0) end
    end

    local bars = { self.mh, self.oh, self.tb }
    local text = { "Main hand (drag to move)", "Off hand", "Target (drag to move)" }
    for i = 1, 3 do
        local bar = bars[i]
        if unlocked then
            bar.preview = true
            bar.endTime = nil
            bar:SetMinMaxValues(0, 1); bar:SetValue(0.6)
            bar.label:SetText(text[i]); bar.timer:SetText("")
            bar:Show()
        elseif bar.preview then
            bar.preview = nil
            bar:Hide()
        end
    end
end

--------------------------------------------------------------------- Running
function XPS:Start(bar, duration, label, r, g, b)
    if self:Get("enabled") == 0 or bar.preview then return end
    if self:Get("combatOnly") == 1 and not UnitAffectingCombat("player") then return end
    if not duration or duration <= 0 then return end

    bar.startTime = GetTime()
    bar.endTime   = GetTime() + duration
    bar:SetMinMaxValues(bar.startTime, bar.endTime)
    bar:SetValue(bar.startTime)
    if r then bar:SetStatusBarColor(r, g, b) end
    bar.label:SetText(label or "")
    bar:Show()
end

function XPS:OnUpdate(bar)
    if bar.preview then return end
    local now = GetTime()
    if not bar.endTime or now >= bar.endTime then
        bar:Hide()
        return
    end
    bar:SetValue(now)

    if self:Get("showTimer") == 1 then
        local left = bar.endTime - now
        local d = self:Get("decimals")
        local mult = 10 ^ d
        bar.timer:SetText(format("%." .. d .. "f", floor(left * mult) / mult))
    end

    if self:Get("spark") == 1 then
        local pct = (now - bar.startTime) / (bar.endTime - bar.startTime)
        bar.spark:ClearAllPoints()
        bar.spark:SetPoint("CENTER", bar, "LEFT", pct * bar:GetWidth(), 0)
    end
end

--------------------------------------------------------------------- Detection
-- Dual wield heuristic: vanilla does not tell which hand hit.
-- We compare which of the two weapons was "due" in time.
local lastMH, lastOH, streakMH, streakOH = 0, 0, 0, 0

function XPS:MeleeSwing()
    local sMH, sOH = UnitAttackSpeed("player")
    if not sMH then return end
    local now = GetTime()

    if sOH and self:Get("showOffhand") == 1 then
        local dueMH = abs((now - lastMH) - sMH)
        local dueOH = abs((now - lastOH) - sOH)
        if (dueMH <= dueOH and not (streakMH <= sOH / sMH)) or streakOH >= sMH / sOH then
            if lastOH == 0 then lastOH = now end
            lastMH, streakMH, streakOH = now, streakMH + 1, 0
            if self:Get("showMainhand") == 1 then
                self:Start(self.mh, sMH, format("Main hand [%.2fs]", sMH), self:Colour("colMH"))
            end
        else
            lastOH, streakOH, streakMH = now, streakOH + 1, 0
            self:Start(self.oh, sOH, format("Off hand [%.2fs]", sOH), self:Colour("colOH"))
        end
    else
        lastMH = now
        if self:Get("showMainhand") == 1 then
            self:Start(self.mh, sMH, format("Main hand [%.2fs]", sMH), self:Colour("colMH"))
        end
    end
end

-- Abilities that consume the current melee swing
local onNextSwing = {
    ["Heroic Strike"] = 1, ["Cleave"] = 1, ["Maul"] = 1,
    ["Raptor Strike"] = 1, ["Slam"] = 1,
}

function XPS:RangedSwing(spell)
    if self:Get("showRanged") == 0 then return end
    local speed = UnitRangedDamage("player")
    if not speed or speed <= 0 then return end
    self:Start(self.mh, speed, format("%s [%.2fs]", spell, speed), self:Colour("colRanged"))
end

local rangedCast = {
    ["Shoot"] = "Wand", ["Shoot Bow"] = "Bow", ["Shoot Gun"] = "Gun",
    ["Shoot Crossbow"] = "Crossbow", ["Throw"] = "Thrown", ["Auto Shot"] = "Auto Shot",
}

-- "Your X hits/crits ...", "Your X missed ...", "Your X was dodged/blocked
-- ...", "Your X is parried ...", "Your X failed. ..."
local selfSpellPatterns = {
    "^Your (.-) hits ", "^Your (.-) crits ", "^Your (.-) misse",
    "^Your (.-) was ", "^Your (.-) is ", "^Your (.-) failed",
}

-- isSpell: message comes from CHAT_MSG_SPELL_SELF_DAMAGE, where only
-- known abilities count - anything else there is not a white swing.
function XPS:ParseSelf(msg, isSpell)
    if not msg then return end
    -- falling, drowning, lava etc. also land in the SELF_HITS channel
    if string.find(msg, "lose %d+ health") then return end

    local spell
    for i = 1, table.getn(selfSpellPatterns) do
        local _, _, s = string.find(msg, selfSpellPatterns[i])
        if s then spell = s; break end
    end

    if not spell then
        if not isSpell then self:MeleeSwing() end   -- normal auto attack
    elseif onNextSwing[spell] then
        self:MeleeSwing()                           -- consumes the swing
    elseif spell == "Auto Shot" then
        self:RangedSwing("Auto Shot")
    end
end

function XPS:ParseEnemy(msg)
    if not msg or not UnitExists("target") then return end
    local _, _, who = string.find(msg, "^(.-) hits you")
    if not who then _, _, who = string.find(msg, "^(.-) crits you") end
    if not who then _, _, who = string.find(msg, "^(.-) misses you") end
    if not who then _, _, who = string.find(msg, "^(.-) attacks%. You ") end
    if not who or who ~= UnitName("target") then return end

    local speed = UnitAttackSpeed("target")
    if not speed or speed <= 0 then return end
    self:Start(self.tb, speed, format("%s [%.2fs]", who, speed), self:Colour("colTarget"))
end

local function HideIfRunning(bar)
    if not bar.preview then bar.endTime = nil; bar:Hide() end
end

function XPS:Reset()
    lastMH, lastOH, streakMH, streakOH = 0, 0, 0, 0
    if self.built then HideIfRunning(self.mh); HideIfRunning(self.oh); HideIfRunning(self.tb) end
end

--------------------------------------------------------------------- Events
local ev = CreateFrame("Frame")
ev:RegisterEvent("VARIABLES_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_LEAVE_COMBAT")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("CHAT_MSG_COMBAT_SELF_HITS")
ev:RegisterEvent("CHAT_MSG_COMBAT_SELF_MISSES")
ev:RegisterEvent("CHAT_MSG_SPELL_SELF_DAMAGE")
ev:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS")
ev:RegisterEvent("CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES")
ev:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS")
ev:RegisterEvent("CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES")
ev:RegisterEvent("UNIT_SPELLCAST_SENT")

ev:SetScript("OnEvent", function()
    if event == "VARIABLES_LOADED" then
        if not XPerlSwingConfig then XPerlSwingConfig = {} end
        -- never start a session with movable bars in the way
        XPerlSwingConfig.locked = nil
        XPS:Build()
        XPS:ApplyLayout()

        -- AttackBar is redundant now; if still installed, silence it
        if Abar_Frame then
            Abar_Frame:Hide(); Abar_Frame:SetScript("OnShow", function() this:Hide() end)
            if Abar_Mhr then Abar_Mhr:Hide() end
            if Abar_Oh  then Abar_Oh:Hide()  end
        end
        if ebar_Frame then
            ebar_Frame:Hide(); ebar_Frame:SetScript("OnShow", function() this:Hide() end)
            if ebar_mh then ebar_mh:Hide() end
            if ebar_oh then ebar_oh:Hide() end
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        XPS:ApplyLayout()

    elseif event == "PLAYER_LEAVE_COMBAT" then
        XPS:Reset()

    elseif event == "PLAYER_TARGET_CHANGED" then
        if XPS.built then
            HideIfRunning(XPS.tb)
            XPS:ApplyLayout()   -- target frame may have changed its width
        end

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        XPS:ParseSelf(arg1)

    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        XPS:ParseSelf(arg1, true)

    elseif event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_HITS"
        or event == "CHAT_MSG_COMBAT_CREATURE_VS_SELF_MISSES" then
        if XPS:Get("showTargetMob") == 1 then XPS:ParseEnemy(arg1) end

    elseif event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_HITS"
        or event == "CHAT_MSG_COMBAT_HOSTILEPLAYER_MISSES" then
        if XPS:Get("showTargetPvP") == 1 then XPS:ParseEnemy(arg1) end

    elseif event == "UNIT_SPELLCAST_SENT" then
        local spell = arg2
        if spell then
            local _, _, base = string.find(spell, "(.+)%(")
            if base then spell = base end
            if rangedCast[spell] then XPS:RangedSwing(rangedCast[spell]) end
        end
    end
end)

--------------------------------------------------------------------- Slash
function XPS:SetLocked(locked)
    self:Set("locked", locked and 1 or 0)
    if XPerl_SwingTimer_RefreshOptions then XPerl_SwingTimer_RefreshOptions() end
end

SLASH_XPERLSWING1 = "/xps"
SLASH_XPERLSWING2 = "/xperlswing"
SlashCmdList["XPERLSWING"] = function(msg)
    msg = string.lower(msg or "")
    if msg == "unlock" or msg == "move" then
        XPS:SetLocked(false)
        Print("bars unlocked - drag them with the left mouse button. Dragging detaches them from the unit frame. |cFFFFFF00/xps lock|r when done.")
    elseif msg == "lock" then
        XPS:SetLocked(true)
        Print("bars locked.")
    elseif msg == "reset" then
        if XPerlSwingConfig then
            XPerlSwingConfig.posPlayer, XPerlSwingConfig.posTarget = nil, nil
            XPerlSwingConfig.attachPlayer, XPerlSwingConfig.attachTarget = nil, nil
        end
        XPS:ApplyLayout()
        if XPerl_SwingTimer_RefreshOptions then XPerl_SwingTimer_RefreshOptions() end
        Print("bars docked to the X-Perl frames again.")
    elseif msg == "help" or msg == "?" then
        Print("|cFFFFFF00/xps|r options, |cFFFFFF00/xps unlock|r / |cFFFFFF00lock|r move bars, |cFFFFFF00/xps reset|r dock bars again.")
    else
        XPerl_SwingTimer_ToggleOptions()
    end
end
