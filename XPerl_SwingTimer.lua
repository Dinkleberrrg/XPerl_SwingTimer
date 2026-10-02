--=====================================================================
-- X-Perl SwingTimer
--
-- Eigenstaendiges XPerl-Modul. Braucht AttackBar nicht mehr - die
-- Swing-Erkennung ist hier nachgebaut. Ordner loeschen = weg.
--
-- Die Erkennung folgt derselben Idee wie AttackBar: Vanilla hat kein
-- Swing-Event, also wird jeder eigene Nahkampftreffer im Kampflog als
-- "Swing ist gerade losgegangen" gewertet und die Waffengeschwindigkeit
-- aus UnitAttackSpeed() als Balkenlaenge genommen.
--=====================================================================

XPerl_SwingTimer = {}
local XPS = XPerl_SwingTimer

local TEX_XPERL = "Interface\\AddOns\\XPerl\\Images\\XPerl_StatusBar"
local TEX_FLAT  = "Interface\\Buttons\\WHITE8X8"

XPS.defaults = {
    enabled        = 1,   -- Modul aktiv
    combatOnly     = 0,   -- Leisten nur im Kampf einblenden

    showMainhand   = 1,   -- Haupthand
    showOffhand    = 1,   -- Schildhand (nur beim Beidhandkampf sinnvoll)
    showRanged     = 1,   -- Fernkampf / Wurf / Zauberstab
    showTargetMob  = 1,   -- Swing-Timer von Kreaturen
    showTargetPvP  = 1,   -- Swing-Timer von feindlichen Spielern

    attachPlayer   = 1,   -- an XPerl_Player andocken statt frei stehen
    attachTarget   = 1,   -- an XPerl_Target andocken
    autoWidth      = 1,   -- Breite vom Unitframe uebernehmen
    width          = 200, -- feste Breite, falls autoWidth aus
    height         = 9,
    gap            = 2,   -- Abstand zwischen Haupt- und Schildhand
    padding        = 2,   -- Abstand zum Unitframe

    xperlTexture   = 1,   -- XPerls Balkentextur statt flacher Farbflaeche
    background     = 1,   -- dunkler Untergrund hinter dem Balken
    spark          = 0,   -- Laufmarke am Balkenende

    showLabel      = 1,   -- Beschriftung links (Waffe + Geschwindigkeit)
    showTimer      = 1,   -- Restzeit rechts
    decimals       = 1,   -- Nachkommastellen der Restzeit
    fontSize       = 9,
    -- [patch] Schriftart der Balken; 1 = Prototype, 0 = Blizzard-Standard
    protoFont      = 0,

    colMH     = {0.10, 0.35, 1.00},
    colOH     = {0.00, 0.65, 0.95},
    colRanged = {0.20, 0.90, 0.30},
    colTarget = {0.90, 0.15, 0.15},
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

--------------------------------------------------------------------- Aufbau
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

function XPS:Build()
    if self.built then return end

    self.playerBox = CreateFrame("Frame", "XPerlSwingPlayer", UIParent)
    self.playerBox:SetMovable(true)
    self.playerBox:SetWidth(200); self.playerBox:SetHeight(20)
    self.mh = MakeBar("XPerlSwingMH", self.playerBox)
    self.oh = MakeBar("XPerlSwingOH", self.playerBox)

    self.targetBox = CreateFrame("Frame", "XPerlSwingTarget", UIParent)
    self.targetBox:SetMovable(true)
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
    bar:SetStatusBarColor(r, g, b)

    if self:Get("background") == 1 then
        bar.bg:SetTexture(self:Get("xperlTexture") == 1 and TEX_XPERL or TEX_FLAT)
        bar.bg:SetVertexColor(0, 0, 0, 0.5)
        bar.bg:Show()
    else
        bar.bg:Hide()
    end

    bar.spark:SetHeight(h * 2)
    if self:Get("spark") == 1 then bar.spark:Show() else bar.spark:Hide() end

    -- [patch] MONOCHROME schaltet das Antialiasing ab; die duenne Prototype
    -- wird dadurch scharf statt verwaschen.
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

local function AnchorWidth(host, fallbackWidth)
    if host and host:IsShown() then
        local w = host:GetWidth()
        if w and w > 40 then return w end
    end
    return fallbackWidth
end

function XPS:ApplyLayout()
    if not self.built then return end

    local h, gap, pad = self:Get("height"), self:Get("gap"), self:Get("padding")
    local fixedW = self:Get("width")

    -- Spielerleisten
    local host = (self:Get("attachPlayer") == 1) and (XPerl_Player or PlayerFrame) or nil
    local w = (self:Get("autoWidth") == 1) and AnchorWidth(host, fixedW) or fixedW

    self.playerBox:SetWidth(w); self.playerBox:SetHeight(h * 2 + gap)
    if host then
        self.playerBox:ClearAllPoints()
        self.playerBox:SetPoint("TOP", host, "BOTTOM", 0, -pad)
    end
    self:StyleBar(self.mh, w, self:Colour("colMH"))
    self:StyleBar(self.oh, w, self:Colour("colOH"))
    self.mh:ClearAllPoints(); self.mh:SetPoint("TOPLEFT", self.playerBox, "TOPLEFT", 0, 0)
    self.oh:ClearAllPoints(); self.oh:SetPoint("TOPLEFT", self.playerBox, "TOPLEFT", 0, -(h + gap))

    -- Zielleiste
    local thost = (self:Get("attachTarget") == 1) and (XPerl_Target or TargetFrame) or nil
    local tw = (self:Get("autoWidth") == 1) and AnchorWidth(thost, fixedW) or fixedW
    self.targetBox:SetWidth(tw); self.targetBox:SetHeight(h)
    if thost then
        self.targetBox:ClearAllPoints()
        self.targetBox:SetPoint("TOP", thost, "BOTTOM", 0, -pad)
    end
    self:StyleBar(self.tb, tw, self:Colour("colTarget"))
    self.tb:ClearAllPoints(); self.tb:SetPoint("TOPLEFT", self.targetBox, "TOPLEFT", 0, 0)

    if self:Get("enabled") == 0 then
        self.mh:Hide(); self.oh:Hide(); self.tb:Hide()
    end
end

--------------------------------------------------------------------- Ablauf
function XPS:Start(bar, duration, label, r, g, b)
    if self:Get("enabled") == 0 then return end
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

--------------------------------------------------------------------- Erkennung
-- Beidhand-Heuristik: Vanilla sagt nicht, welche Hand getroffen hat.
-- Wir vergleichen, welche der beiden Waffen zeitlich "faellig" war.
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
                self:Start(self.mh, sMH, format("Haupthand [%.2fs]", sMH), self:Colour("colMH"))
            end
        else
            lastOH, streakOH, streakMH = now, streakOH + 1, 0
            self:Start(self.oh, sOH, format("Schildhand [%.2fs]", sOH), self:Colour("colOH"))
        end
    else
        lastMH = now
        if self:Get("showMainhand") == 1 then
            self:Start(self.mh, sMH, format("Haupthand [%.2fs]", sMH), self:Colour("colMH"))
        end
    end
end

-- Faehigkeiten, die den laufenden Nahkampfschwung verbrauchen
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
    ["Shoot"] = "Zauberstab", ["Shoot Bow"] = "Bogen", ["Shoot Gun"] = "Schusswaffe",
    ["Shoot Crossbow"] = "Armbrust", ["Throw"] = "Wurf", ["Auto Shot"] = "Autoschuss",
}

function XPS:ParseSelf(msg)
    local _, _, spell = string.find(msg, "Your (.+) hits")
    if not spell then _, _, spell = string.find(msg, "Your (.+) crits") end
    if not spell then _, _, spell = string.find(msg, "Your (.+) misses") end
    if not spell then _, _, spell = string.find(msg, "Your (.+) is") end

    if not spell then
        self:MeleeSwing()                       -- normaler Autoangriff
    elseif onNextSwing[spell] then
        self:MeleeSwing()                       -- verbraucht den Schwung
    elseif spell == "Auto Shot" then
        self:RangedSwing("Autoschuss")
    end
end

function XPS:ParseEnemy(msg)
    if not UnitExists("target") then return end
    local _, _, who = string.find(msg, "(.+) hits you")
    if not who then _, _, who = string.find(msg, "(.+) crits you") end
    if not who then _, _, who = string.find(msg, "(.+) misses you") end
    if not who then _, _, who = string.find(msg, "(.+) attacks%. You ") end
    if not who or who ~= UnitName("target") then return end

    local speed = UnitAttackSpeed("target")
    if not speed or speed <= 0 then return end
    self:Start(self.tb, speed, format("%s [%.2fs]", who, speed), self:Colour("colTarget"))
end

function XPS:Reset()
    lastMH, lastOH, streakMH, streakOH = 0, 0, 0, 0
    if self.built then self.mh:Hide(); self.oh:Hide(); self.tb:Hide() end
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
        XPS:Build()
        XPS:ApplyLayout()

        -- AttackBar ist jetzt ueberfluessig; falls noch installiert, still legen
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
        if XPS.built then XPS.tb:Hide() end

    elseif event == "CHAT_MSG_COMBAT_SELF_HITS" or event == "CHAT_MSG_COMBAT_SELF_MISSES" then
        XPS:ParseSelf(arg1)

    elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" then
        XPS:ParseSelf(arg1)

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

SLASH_XPERLSWING1 = "/xps"
SLASH_XPERLSWING2 = "/xperlswing"
SlashCmdList["XPERLSWING"] = function() XPerl_SwingTimer_ToggleOptions() end
