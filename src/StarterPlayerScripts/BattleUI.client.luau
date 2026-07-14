--[[
    BattleUI.lua — Retro "Studs Cartridge" Battle Interface for Stud Catcher
    Instance.new() only · No external assets

    DESIGN SYSTEM — "Studs Cartridge" (shared with UITheme)
      Palette   → Dark plum cartridge background, chunky black pixel borders,
                  arcade-gold accents; per-type edge tints from StudData,
                  gold foil for shiny/legendary encounters.
      Type      → Press Start 2P / Arcade (display/names/buttons) · Code (body)
      Signature → SQUARE corners everywhere (mkCorner is a no-op), a row of
                  round LEGO "stud bumps" along the top of each card, and a
                  rotated rarity diamond lit with a pulsing foil ring on
                  shinies. Cards surface real ATK/DEF/SPD stat bars and
                  flavor text pulled live from StudData.

    Opened via:  UIManager.Call("OpenBattleUI", wildStud, playerStud, wildMaxHP, playerMaxHP)
    Also auto-opens on: StudEvents.EncounterStart

    Layout:
      Top    → Player card (left) · Battle ticker (center) · Wild card (right)
      Bottom → Action console: ATTACK / CATCH / RUN
      ATTACK → swaps to 3-move sub-menu + BACK
      CATCH  → circle-tap minigame (or fallback bar-fill capture console)
      RUN    → fires flee remote, closes UI
]]

-- ─── SERVICES ──────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

-- ─── REFERENCES ──────────────────────────────────────────────────────────
local player     = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData   = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager  = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme    = require(ReplicatedStorage:WaitForChild("UITheme"))

-- ─── PALETTE — retro "Studs cartridge" (from UITheme) ────────────────────
-- Square corners, chunky black borders, arcade-gold accents; matches the
-- shared 8-bit cartridge look defined in ReplicatedStorage/UITheme.
local C_VOID      = UITheme.C_BG          -- deep background
local C_CARD      = UITheme.C_PANEL       -- card base
local C_CARD_HI   = Color3.fromRGB(44, 36, 58) -- card inner panels (lifted panel tone)
local C_INK       = UITheme.C_WHITE       -- primary text
local C_MUTE      = UITheme.C_SEC         -- secondary text
local C_LINE      = UITheme.C_BORDER      -- chunky pixel borders
local C_GOLD      = UITheme.C_ACCENT      -- foil / legendary / shiny
local C_BTN_N     = Color3.fromRGB(28, 23, 38)
local C_BTN_H     = Color3.fromRGB(44, 36, 58)
local C_BTN_P     = C_GOLD
local C_BTN_D     = Color3.fromRGB(20, 17, 28)
local C_HP_HI     = UITheme.HP_HIGH
local C_HP_MID    = UITheme.HP_MID
local C_HP_LO     = UITheme.HP_LOW
local C_BAR_BG    = Color3.fromRGB(24, 20, 34)

-- ─── FONTS ───────────────────────────────────────────────────────────────
local F_DISPLAY = UITheme.F_PIXEL         -- stud names / big headers (Press Start 2P)
local F_BODY    = UITheme.F_BODY          -- chrome, captions, flavor text (Code)
local F_MONO    = UITheme.F_BODY          -- stat numbers, HP, ticker log
local F_BTN     = UITheme.F_PIXEL         -- console buttons

-- ─── STATE ───────────────────────────────────────────────────────────────
local gui
local main
local isOpen         = false
local actionLocked   = false
local catchActive    = false
local inMoveMode     = false
local inBallMode     = false -- catch-ball picker (Catch pressed, choosing a ball)
local ballOptions    = {}   -- picker slots: { id, label, disabled }
-- "encounter" = wild grass encounter (EncounterAction remote)
-- "arena"     = Battle Arena battle (BattleAction remote, AI opponent)
local battleMode     = "encounter"
local trainerMode    = false -- arena battle vs a trainer's team (no catching)

local wildInfo  = { name = "?", studType = "Fire", rarity = "Common" }
local pInfo     = { name = "?", studType = "Fire", rarity = "Common" }
local wMaxHP    = 100
local wCurHP    = 100
local pMaxHP    = 100
local pCurHP    = 100

local logLines  = {}
local MAX_LOG   = 5
local encounterData = nil  -- Full encounter data from server (for CatchingMinigame)

-- Catch minigame (fallback bar) state
local catchBar      = 0
local catchTarget   = 100
local catchFillRate = 8
local catchDecay    = 2
local catchTimer    = 0
local catchRunning  = false
local catchConn     = nil

-- UI element references
local wildCard, playerCard
local wildNameLbl, wildEyebrowLbl, wildHPFill, wildHPTxt, wildFlavorLbl
local pNameLbl, pEyebrowLbl, pHPFill, pHPTxt
local pExpFill, pExpTxt
local wildBadgeHolder, pBadgeHolder
local wildGemHolder, pGemHolder
local wildStatFills, pStatFills = {}, {}
local wildStatTxts, pStatTxts = {}, {}
local wildStatusLbl -- 🔥/❄️/⚡ badge next to the wild's VITALITY label
local logLabels = {}
local bottomFrame, catchFrame
local atkBtn, catchBtn, runBtn
local moveBtn4 -- 4th kit slot (Lv50 move); only visible in move mode
local backBtn
local catchBarFill, catchTimerLbl, catchTapBtn

-- ─── BUTTON STATE LOOKUP (avoids custom methods on Instances) ──────────
local _btnState = {}  -- [button] = { disabled, nBg, nTc, nSc, stroke }

-- ─── WALKSPEED LOCK (via UIManager) ─────────────────────────────────────
local function lockWalk()
    UIManager.AcquireLock()
end

local function unlockWalk()
    UIManager.ReleaseLock()
end

-- ─── HELPERS ─────────────────────────────────────────────────────────────
local function typeColor(t)
    local d = StudData.Types[t]
    return d and d.color or C_MUTE
end

local function typeIcon(t)
    local d = StudData.Types[t]
    return d and d.icon or "?"
end

local function rarityColor(r)
    local d = StudData.Rarity[r]
    return d and d.color or C_MUTE
end

local function hpColor(ratio)
    if ratio > 0.5 then return C_HP_HI end
    if ratio > 0.25 then return C_HP_MID end
    return C_HP_LO
end

local function tw(obj, props, dur, style)
    dur = dur or 0.15
    TweenService:Create(obj, TweenInfo.new(dur, style or Enum.EasingStyle.Quad), props):Play()
end

-- Look up full roster data (stats/description) by id, tolerating missing id
local function lookupFull(id)
    if not id then return nil end
    return StudData.GetStudById(id)
end

local STAT_CAP = 40 -- rough ceiling across the roster, used to scale stat bars

-- ─── BUTTON DISABLE HELPER ────────────────────────────────────────────
local function setBtnDisabled(btn, v)
    local s = _btnState[btn]
    if not s then return end
    s.disabled = v
    if v then
        btn.BackgroundColor3 = C_BTN_D
        btn.TextColor3       = C_MUTE
        s.stroke.Color       = C_LINE
    else
        btn.BackgroundColor3 = s.nBg
        btn.TextColor3       = s.nTc
        s.stroke.Color       = s.nSc
    end
end

-- ─── UI FACTORY ─────────────────────────────────────────────────────────

-- Square corners everywhere: the retro "Studs cartridge" look has no rounded
-- panels. Kept as a no-op so every call site stays untouched; only the round
-- stud bumps (below) get real UICorners.
local function mkCorner(_parent, _radius)
    return nil
end

-- Row of round "stud bumps" along a panel's top edge — the top of a LEGO
-- plate. Bumps are round by nature; the panels stay square.
local function mkStudBumps(parent, count, zIndex)
    local strip = Instance.new("Frame")
    strip.Name = "StudBumps"
    strip.Size = UDim2.new(1, -16, 0, 10)
    strip.Position = UDim2.new(0, 8, 0, -5)
    strip.BackgroundTransparency = 1
    strip.ZIndex = zIndex or 2
    strip.Parent = parent
    for i = 1, count do
        local bump = Instance.new("Frame")
        bump.Name = "Bump" .. i
        bump.Size = UDim2.new(0, 12, 0, 12)
        bump.Position = UDim2.new((i - 0.5) / count, -6, 0, -1)
        bump.BackgroundColor3 = C_CARD
        bump.BorderSizePixel = 0
        bump.ZIndex = zIndex or 2
        bump.Parent = strip
        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = bump
        local s = Instance.new("UIStroke")
        s.Color = C_LINE
        s.Thickness = 2
        s.Parent = bump
    end
    return strip
end

local function mkFrame(p)
    local f = Instance.new("Frame")
    f.Name             = p.name or "F"
    f.Size             = p.size or UDim2.new(1, 0, 1, 0)
    f.Position         = p.pos or UDim2.new(0, 0, 0, 0)
    f.BackgroundColor3 = p.bg or C_CARD
    f.BackgroundTransparency = p.transparency or 0
    f.BorderSizePixel  = 0
    if p.anchor then f.AnchorPoint = p.anchor end
    if p.clip   then f.ClipsDescendants = true end
    if p.parent then f.Parent = p.parent end
    if p.corner ~= false then mkCorner(f, p.corner) end
    if p.stroke then
        local s = Instance.new("UIStroke")
        s.Color     = p.stroke
        s.Thickness = p.strokeThickness or 2
        s.Parent    = f
    end
    if p.pad then
        local pd = Instance.new("UIPadding")
        pd.PaddingTop    = UDim.new(0, p.pad)
        pd.PaddingBottom = UDim.new(0, p.pad)
        pd.PaddingLeft   = UDim.new(0, p.pad)
        pd.PaddingRight  = UDim.new(0, p.pad)
        pd.Parent = f
    end
    return f
end

local function mkLabel(p)
    local l = Instance.new("TextLabel")
    l.Name               = p.name or "L"
    l.Size               = p.size or UDim2.new(1, 0, 1, 0)
    l.Position           = p.pos or UDim2.new(0, 0, 0, 0)
    l.BackgroundTransparency = 1
    l.Text               = p.text or ""
    l.TextColor3         = p.color or C_INK
    l.Font               = p.font or F_BODY
    l.TextSize           = p.ts or 16
    l.TextXAlignment     = p.xa or Enum.TextXAlignment.Left
    l.TextYAlignment     = p.ya or Enum.TextYAlignment.Center
    l.TextTruncate       = p.truncate or Enum.TextTruncate.None
    if p.wrap    then l.TextWrapped = true end
    if p.anchor  then l.AnchorPoint = p.anchor end
    if p.parent  then l.Parent = p.parent end
    if p.transparency then l.TextTransparency = p.transparency end
    return l
end

local function mkBtn(p)
    local b = Instance.new("TextButton")
    b.Name               = p.name or "Btn"
    b.Size               = p.size or UDim2.new(0, 120, 0, 48)
    b.Position           = p.pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3   = p.bg or C_BTN_N
    b.TextColor3         = p.tc or C_INK
    b.Font               = p.font or F_BTN
    b.TextSize           = p.ts or 13
    b.Text               = p.text or ""
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    if p.anchor then b.AnchorPoint = p.anchor end
    if p.parent then b.Parent = p.parent end
    mkCorner(b, p.corner or 10)

    local stroke = Instance.new("UIStroke")
    stroke.Color     = p.sc or C_LINE
    stroke.Thickness = p.scThickness or 2
    stroke.Parent    = b

    local nBg = p.bg or C_BTN_N
    local nTc = p.tc or C_INK
    local nSc = p.sc or C_LINE

    _btnState[b] = { disabled = false, nBg = nBg, nTc = nTc, nSc = nSc, stroke = stroke }

    b.MouseEnter:Connect(function()
        if _btnState[b].disabled then return end
        tw(b, { BackgroundColor3 = C_BTN_H })
        tw(stroke, { Color = C_GOLD })
    end)
    b.MouseLeave:Connect(function()
        if _btnState[b].disabled then return end
        tw(b, { BackgroundColor3 = nBg })
        tw(stroke, { Color = nSc })
    end)
    b.MouseButton1Down:Connect(function()
        if _btnState[b].disabled then return end
        tw(b, { BackgroundColor3 = C_BTN_P, TextColor3 = C_VOID }, 0.08)
    end)
    b.MouseButton1Up:Connect(function()
        if _btnState[b].disabled then return end
        tw(b, { BackgroundColor3 = C_BTN_H, TextColor3 = nTc }, 0.08)
    end)

    return b
end

-- Type pill: rounded chip with the stud's icon glyph + uppercase type name
local function mkTypePill(parent, studType, pos)
    local tc = typeColor(studType)
    local pill = mkFrame({
        name    = "TypePill",
        size    = UDim2.new(0, 92, 0, 22),
        pos     = pos or UDim2.new(0, 0, 0, 0),
        bg      = tc,
        corner  = 11,
        parent  = parent,
    })
    mkLabel({
        name   = "TypeLbl",
        text   = typeIcon(studType) .. "  " .. studType:upper(),
        color  = C_VOID,
        font   = F_BTN,
        ts     = 12,
        xa     = Enum.TextXAlignment.Center,
        parent = pill,
    })
    return pill
end

-- Signature element: rotated rarity gem, optionally lit with a shiny foil ring
local function mkRarityGem(parent, rarity, isShiny, pos)
    local holder = mkFrame({
        name = "GemHolder",
        size = UDim2.new(0, 26, 0, 26),
        pos  = pos or UDim2.new(1, -26, 0, 0),
        bg   = C_CARD,
        transparency = 1,
        corner = false,
        parent = parent,
    })

    if isShiny then
        local foil = mkFrame({
            name    = "FoilRing",
            size    = UDim2.new(0, 24, 0, 24),
            pos     = UDim2.new(0.5, 0, 0.5, 0),
            anchor  = Vector2.new(0.5, 0.5),
            bg      = C_GOLD,
            transparency = 0.55,
            corner  = 6,
            parent  = holder,
        })
        foil.Rotation = 45
        local foilStroke = Instance.new("UIStroke")
        foilStroke.Color = C_GOLD
        foilStroke.Thickness = 2
        foilStroke.Parent = foil
        local pulse = TweenService:Create(foil, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.1 })
        pulse:Play()
    end

    local gem = mkFrame({
        name   = "Gem",
        size   = UDim2.new(0, 16, 0, 16),
        pos    = UDim2.new(0.5, 0, 0.5, 0),
        anchor = Vector2.new(0.5, 0.5),
        bg     = rarityColor(rarity),
        corner = 4,
        parent = holder,
    })
    gem.Rotation = 45
    local grad = Instance.new("UIGradient")
    grad.Rotation = 90
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.5, rarityColor(rarity)),
        ColorSequenceKeypoint.new(1, rarityColor(rarity)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.35),
        NumberSequenceKeypoint.new(0.5, 0),
        NumberSequenceKeypoint.new(1, 0),
    })
    grad.Parent = gem

    return holder
end

-- Vitality (HP) bar
local function mkHPBar(parent, pos, width)
    local bg = mkFrame({
        name   = "HPBg",
        size   = UDim2.new(0, width, 0, 14),
        pos    = pos,
        bg     = C_BAR_BG,
        corner = 7,
        clip   = true,
        parent = parent,
    })
    local fill = Instance.new("Frame")
    fill.Name              = "HPFill"
    fill.Size              = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3  = C_HP_HI
    fill.BorderSizePixel   = 0
    fill.Parent            = bg
    mkCorner(fill, 7)
    local txt = mkLabel({
        name   = "HPTxt",
        text   = "100/100",
        color  = C_INK,
        font   = F_MONO,
        ts     = 11,
        xa     = Enum.TextXAlignment.Center,
        parent = bg,
    })
    return bg, fill, txt
end

-- Mini stat bar row (ATK / DEF / SPD)
local function mkStatRow(parent, pos, label, statFillsOut, statTxtsOut, key)
    local row = mkFrame({ name = key .. "Row", size = UDim2.new(1, 0, 0, 14), pos = pos, transparency = 1, corner = false, parent = parent })
    mkLabel({
        name = "Lbl", size = UDim2.new(0, 34, 1, 0), text = label,
        color = C_MUTE, font = F_MONO, ts = 11, parent = row,
    })
    local barBg = mkFrame({
        name = "Bar", size = UDim2.new(1, -66, 1, -4), pos = UDim2.new(0, 36, 0, 2),
        bg = C_BAR_BG, corner = 4, clip = true, parent = row,
    })
    local fill = Instance.new("Frame")
    fill.Name = "Fill"
    fill.Size = UDim2.new(0, 0, 1, 0)
    fill.BackgroundColor3 = C_GOLD
    fill.BorderSizePixel = 0
    fill.Parent = barBg
    mkCorner(fill, 4)
    local valTxt = mkLabel({
        name = "Val", size = UDim2.new(0, 26, 1, 0), pos = UDim2.new(1, -26, 0, 0),
        text = "--", color = C_MUTE, font = F_MONO, ts = 11, xa = Enum.TextXAlignment.Right, parent = row,
    })
    statFillsOut[key] = fill
    statTxtsOut[key] = valTxt
end

local function setStatRow(fill, txt, value)
    if not value then
        fill.Size = UDim2.new(0, 0, 1, 0)
        txt.Text = "--"
        return
    end
    local ratio = math.clamp(value / STAT_CAP, 0, 1)
    tw(fill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0.25)
    txt.Text = tostring(value)
end

-- ─── BUILD UI ────────────────────────────────────────────────────────────
local function buildUI()
    gui = Instance.new("ScreenGui")
    gui.Name           = "BattleUI"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player:WaitForChild("PlayerGui")

    main = mkFrame({ name = "Main", bg = C_VOID, corner = false, parent = gui })
    main.Visible = false

    -- ── TOP SECTION: Player card / ticker log / Wild card ──────────────
    local topSection = mkFrame({
        name = "TopSection", size = UDim2.new(1, -16, 1, -140), pos = UDim2.new(0, 8, 0, 8),
        transparency = 1, corner = false, parent = main,
    })

    -- Player card (left)
    playerCard = mkFrame({
        name = "PlayerCard", size = UDim2.new(0.27, -8, 0, 244), pos = UDim2.new(0, 0, 0.5, -122),
        bg = C_CARD, stroke = C_LINE, strokeThickness = 3, corner = 12, pad = 12, parent = topSection,
    })
    mkStudBumps(playerCard, 4)

    pEyebrowLbl = mkLabel({
        name = "Eyebrow", size = UDim2.new(1, -30, 0, 16), text = "YOUR STUD",
        color = C_MUTE, font = F_MONO, ts = 11, parent = playerCard,
    })
    pGemHolder = mkRarityGem(playerCard, "Common", false, UDim2.new(1, -26, 0, -2))

    pNameLbl = mkLabel({
        name = "PName", size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, 18),
        text = "???", color = C_INK, font = F_DISPLAY, ts = 16, parent = playerCard,
    })

    pBadgeHolder = mkTypePill(playerCard, "Fire", UDim2.new(0, 0, 0, 52))

    mkLabel({ name = "VitLbl", size = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 0, 84), text = "VITALITY", color = C_MUTE, font = F_MONO, ts = 10, parent = playerCard })
    local _, pf, pt = mkHPBar(playerCard, UDim2.new(0, 0, 0, 98), 200)
    pHPFill = pf
    pHPTxt  = pt

    mkStatRow(playerCard, UDim2.new(0, 0, 0, 128), "ATK", pStatFills, pStatTxts, "atk")
    mkStatRow(playerCard, UDim2.new(0, 0, 0, 146), "DEF", pStatFills, pStatTxts, "def")
    mkStatRow(playerCard, UDim2.new(0, 0, 0, 164), "SPD", pStatFills, pStatTxts, "spd")

    -- EXP progress toward the next level
    mkLabel({ name = "ExpLbl", size = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 0, 184), text = "EXPERIENCE", color = C_MUTE, font = F_MONO, ts = 10, parent = playerCard })
    local expBg = mkFrame({
        name   = "ExpBg",
        size   = UDim2.new(0, 200, 0, 12),
        pos    = UDim2.new(0, 0, 0, 198),
        bg     = C_BAR_BG,
        corner = 6,
        clip   = true,
        parent = playerCard,
    })
    pExpFill = Instance.new("Frame")
    pExpFill.Name             = "ExpFill"
    pExpFill.Size             = UDim2.new(0, 0, 1, 0)
    pExpFill.BackgroundColor3 = C_GOLD
    pExpFill.BorderSizePixel  = 0
    pExpFill.Parent           = expBg
    mkCorner(pExpFill, 6)
    pExpTxt = mkLabel({
        name   = "ExpTxt",
        text   = "",
        color  = C_INK,
        font   = F_MONO,
        ts     = 10,
        xa     = Enum.TextXAlignment.Center,
        parent = expBg,
    })

    -- Center: Battle ticker log
    local logP = mkFrame({
        name = "LogPanel", size = UDim2.new(0.46, -16, 1, 0), pos = UDim2.new(0.27, 8, 0, 0),
        bg = C_CARD, stroke = C_LINE, corner = 12, parent = topSection,
    })
    mkFrame({ name = "HeaderStrip", size = UDim2.new(1, 0, 0, 30), bg = C_CARD_HI, corner = 12, parent = logP })
    mkLabel({
        name = "HeaderTxt", size = UDim2.new(1, -20, 0, 30), pos = UDim2.new(0, 12, 0, 0),
        text = "BATTLE LOG", color = C_GOLD, font = F_MONO, ts = 12, parent = logP,
    })
    mkFrame({ name = "Divider", size = UDim2.new(1, 0, 0, 1), pos = UDim2.new(0, 0, 0, 30), bg = C_LINE, corner = false, parent = logP })

    for i = 1, MAX_LOG do
        local lbl = mkLabel({
            name = "Log" .. i, size = UDim2.new(1, -24, 0, 22), pos = UDim2.new(0, 14, 0, 40 + (i - 1) * 26),
            text = "", color = C_MUTE, font = F_MONO, ts = 14, parent = logP,
        })
        logLabels[i] = lbl
    end

    -- Wild card (right)
    wildCard = mkFrame({
        name = "WildCard", size = UDim2.new(0.27, -8, 0, 244), pos = UDim2.new(0.73, 8, 0.5, -122),
        bg = C_CARD, stroke = C_LINE, strokeThickness = 3, corner = 12, pad = 12, parent = topSection,
    })
    mkStudBumps(wildCard, 4)

    wildEyebrowLbl = mkLabel({
        name = "Eyebrow", size = UDim2.new(1, -30, 0, 16), text = "WILD ENCOUNTER",
        color = C_MUTE, font = F_MONO, ts = 11, parent = wildCard,
    })
    wildGemHolder = mkRarityGem(wildCard, "Common", false, UDim2.new(1, -26, 0, -2))

    wildNameLbl = mkLabel({
        name = "WildName", size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, 18),
        text = "???", color = C_INK, font = F_DISPLAY, ts = 16, parent = wildCard,
    })

    wildBadgeHolder = mkTypePill(wildCard, "Fire", UDim2.new(0, 0, 0, 52))

    mkLabel({ name = "VitLbl", size = UDim2.new(1, 0, 0, 12), pos = UDim2.new(0, 0, 0, 84), text = "VITALITY", color = C_MUTE, font = F_MONO, ts = 10, parent = wildCard })
    wildStatusLbl = mkLabel({
        name = "StatusBadge", size = UDim2.new(0, 110, 0, 12), pos = UDim2.new(1, -110, 0, 84),
        text = "", color = C_MUTE, font = F_MONO, ts = 10,
        xa = Enum.TextXAlignment.Right, parent = wildCard,
    })
    local _, wf, wt = mkHPBar(wildCard, UDim2.new(0, 0, 0, 98), 200)
    wildHPFill = wf
    wildHPTxt  = wt

    mkStatRow(wildCard, UDim2.new(0, 0, 0, 128), "ATK", wildStatFills, wildStatTxts, "atk")
    mkStatRow(wildCard, UDim2.new(0, 0, 0, 146), "DEF", wildStatFills, wildStatTxts, "def")
    mkStatRow(wildCard, UDim2.new(0, 0, 0, 164), "SPD", wildStatFills, wildStatTxts, "spd")

    mkFrame({ name = "FlavorDivider", size = UDim2.new(1, 0, 0, 1), pos = UDim2.new(0, 0, 0, 190), bg = C_LINE, corner = false, parent = wildCard })
    wildFlavorLbl = mkLabel({
        name = "Flavor", size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, 198),
        text = "", color = C_MUTE, font = F_BODY, ts = 12, wrap = true, truncate = Enum.TextTruncate.AtEnd,
        ya = Enum.TextYAlignment.Top, parent = wildCard,
    })

    -- ── BOTTOM SECTION: Action console ──────────────────────────────────
    bottomFrame = mkFrame({
        name = "Bottom", size = UDim2.new(1, -16, 0, 120), pos = UDim2.new(0, 8, 1, -128),
        bg = C_CARD, stroke = C_LINE, corner = 12, pad = 8, parent = main,
    })
    mkFrame({ name = "TopDivider", size = UDim2.new(1, -16, 0, 1), pos = UDim2.new(0, 8, 0, 0), bg = C_LINE, corner = false, parent = bottomFrame })

    atkBtn = mkBtn({
        name = "AtkBtn", size = UDim2.new(0.31, 0, 0.78, 0), pos = UDim2.new(0, 0, 0.14, 0),
        text = "⚔️ ATTACK", tc = C_INK, bg = C_BTN_N, sc = C_GOLD, parent = bottomFrame,
    })

    catchBtn = mkBtn({
        name = "CatchBtn", size = UDim2.new(0.31, 0, 0.78, 0), pos = UDim2.new(0.345, 0, 0.14, 0),
        text = "🎯 CATCH", tc = C_INK, bg = C_BTN_N, sc = C_GOLD, parent = bottomFrame,
    })

    runBtn = mkBtn({
        name = "RunBtn", size = UDim2.new(0.31, 0, 0.78, 0), pos = UDim2.new(0.69, 0, 0.14, 0),
        text = ">  RUN", tc = C_INK, bg = C_BTN_N, sc = C_GOLD, parent = bottomFrame,
    })

    moveBtn4 = mkBtn({
        name = "Move4Btn", size = UDim2.new(0.18, 0, 0.78, 0), pos = UDim2.new(0.585, 0, 0.14, 0),
        text = "-", tc = C_INK, bg = C_BTN_N, sc = C_GOLD, parent = bottomFrame,
    })
    moveBtn4.Visible = false

    backBtn = mkBtn({
        name = "BackBtn", size = UDim2.new(0.22, 0, 0.78, 0), pos = UDim2.new(0.77, 0, 0.14, 0),
        text = "< BACK", tc = C_GOLD, bg = C_BTN_N, sc = C_GOLD, parent = bottomFrame,
    })
    backBtn.Visible = false

    -- ── CAPTURE CONSOLE (fallback tap-bar minigame, hidden by default) ──
    catchFrame = mkFrame({
        name = "CaptureConsole", size = UDim2.new(0, 320, 0, 290), pos = UDim2.new(0.5, -160, 0.28, 0),
        bg = C_CARD, stroke = C_LINE, strokeThickness = 3, corner = 14, pad = 20, parent = main,
    })
    mkStudBumps(catchFrame, 5)
    catchFrame.Visible = false

    mkLabel({
        name = "CatchTitle", size = UDim2.new(1, 0, 0, 26), text = "🎯 CAPTURE ATTEMPT",
        color = C_GOLD, font = F_DISPLAY, ts = 15, xa = Enum.TextXAlignment.Center, parent = catchFrame,
    })

    catchTimerLbl = mkLabel({
        name = "CatchTimer", size = UDim2.new(1, 0, 0, 22), pos = UDim2.new(0, 0, 0, 34),
        text = "TIME: 5.0s", color = C_MUTE, font = F_MONO, ts = 14, xa = Enum.TextXAlignment.Center, parent = catchFrame,
    })

    local cBarBg = mkFrame({
        name = "CatchBarBg", size = UDim2.new(1, 0, 0, 26), pos = UDim2.new(0, 0, 0, 66),
        bg = C_BAR_BG, corner = 13, clip = true, stroke = C_LINE, parent = catchFrame,
    })
    catchBarFill = Instance.new("Frame")
    catchBarFill.Name = "CatchFill"
    catchBarFill.Size = UDim2.new(0, 0, 1, 0)
    catchBarFill.BackgroundColor3 = C_GOLD
    catchBarFill.BorderSizePixel = 0
    catchBarFill.Parent = cBarBg
    mkCorner(catchBarFill, 13)
    -- Decorative capture-tick marks
    for i = 1, 3 do
        mkFrame({
            name = "Tick" .. i, size = UDim2.new(0, 2, 1, 0), pos = UDim2.new(i * 0.25, 0, 0, 0),
            bg = C_VOID, transparency = 0.3, corner = false, parent = cBarBg,
        })
    end

    mkLabel({
        name = "CatchBarTxt", size = UDim2.new(1, 0, 0, 20), pos = UDim2.new(0, 0, 0, 100),
        text = "TAP TO FILL THE CAPTURE METER", color = C_MUTE, font = F_MONO, ts = 12,
        xa = Enum.TextXAlignment.Center, parent = catchFrame,
    })

    catchTapBtn = mkBtn({
        name = "TapBtn", size = UDim2.new(1, 0, 0, 60), pos = UDim2.new(0, 0, 0, 130),
        text = "🎯 TAP TO CAPTURE", tc = C_VOID, font = F_DISPLAY, ts = 14, bg = C_GOLD, sc = C_GOLD, parent = catchFrame,
    })
end

-- ─── UPDATE FUNCTIONS ───────────────────────────────────────────────────

-- EXP bar (player card): progress toward the next level
local function updatePlayerExp(level, exp)
    if not level then
        pExpFill.Size = UDim2.new(0, 0, 1, 0)
        pExpTxt.Text = ""
        return
    end
    if level >= StudData.MAX_LEVEL then
        tw(pExpFill, { Size = UDim2.new(1, 0, 1, 0) }, 0.25)
        pExpTxt.Text = "MAX LEVEL"
        return
    end
    local needed = StudData.GetExpToLevel(level)
    local ratio = math.clamp((exp or 0) / needed, 0, 1)
    tw(pExpFill, { Size = UDim2.new(ratio, 0, 1, 0) }, 0.25)
    pExpTxt.Text = (exp or 0) .. "/" .. needed
end

local function setWildInfo(stud)
    wildInfo = stud
    wildNameLbl.Text = (stud.name or "???") .. (stud.level and (" Lv" .. stud.level) or "")
    if stud.isShiny then
        wildEyebrowLbl.Text = "* SHINY ENCOUNTER"
        wildEyebrowLbl.TextColor3 = C_GOLD
    else
        wildEyebrowLbl.Text = "WILD ENCOUNTER"
        wildEyebrowLbl.TextColor3 = C_MUTE
    end

    if wildBadgeHolder then wildBadgeHolder:Destroy() end
    wildBadgeHolder = mkTypePill(wildCard, stud.studType or "Fire", UDim2.new(0, 0, 0, 52))

    if wildGemHolder then wildGemHolder:Destroy() end
    wildGemHolder = mkRarityGem(wildCard, stud.rarity or "Common", stud.isShiny, UDim2.new(1, -26, 0, -2))

    -- Card border tints toward the stud's own color (shiny-aware if provided)
    local edgeColor = stud.colorR and Color3.fromRGB(stud.colorR, stud.colorG, stud.colorB) or typeColor(stud.studType)
    local wildStroke = wildCard:FindFirstChildOfClass("UIStroke")
    if wildStroke then tw(wildStroke, { Color = edgeColor }, 0.3) end

    local full = stud.stats and stud or lookupFull(stud.id)
    local stats = full and full.stats or nil
    setStatRow(wildStatFills.atk, wildStatTxts.atk, stats and stats.attack)
    setStatRow(wildStatFills.def, wildStatTxts.def, stats and stats.defense)
    setStatRow(wildStatFills.spd, wildStatTxts.spd, stats and stats.speed)

    wildFlavorLbl.Text = stud.description or (full and full.description) or ""
end

local function setPlayerInfo(stud)
    pInfo = stud

    if stud.hasStud == false then
        -- Player has no equipped Stud — show a clear placeholder instead of fake data
        pNameLbl.Text = "No Stud Equipped"

        if pBadgeHolder then pBadgeHolder:Destroy() pBadgeHolder = nil end
        if pGemHolder then pGemHolder:Destroy() pGemHolder = nil end

        local pStroke = playerCard:FindFirstChildOfClass("UIStroke")
        if pStroke then tw(pStroke, { Color = C_MUTE }, 0.3) end

        setStatRow(pStatFills.atk, pStatTxts.atk, nil)
        setStatRow(pStatFills.def, pStatTxts.def, nil)
        setStatRow(pStatFills.spd, pStatTxts.spd, nil)
        updatePlayerExp(nil)
        return
    end

    pNameLbl.Text = (stud.name or "???") .. (stud.level and (" Lv" .. stud.level) or "")
    updatePlayerExp(stud.level or 1, stud.exp or 0)

    if pBadgeHolder then pBadgeHolder:Destroy() end
    pBadgeHolder = mkTypePill(playerCard, stud.studType or "Fire", UDim2.new(0, 0, 0, 52))

    if pGemHolder then pGemHolder:Destroy() end
    pGemHolder = mkRarityGem(playerCard, stud.rarity or "Common", false, UDim2.new(1, -26, 0, -2))

    local edgeColor = typeColor(stud.studType)
    local pStroke = playerCard:FindFirstChildOfClass("UIStroke")
    if pStroke then tw(pStroke, { Color = edgeColor }, 0.3) end

    local full = lookupFull(stud.id)
    local stats = full and full.stats or nil
    setStatRow(pStatFills.atk, pStatTxts.atk, stats and stats.attack)
    setStatRow(pStatFills.def, pStatTxts.def, stats and stats.defense)
    setStatRow(pStatFills.spd, pStatTxts.spd, stats and stats.speed)
end

local function updateWildHP(cur, max)
    wCurHP = cur
    wMaxHP = max
    local ratio = math.clamp(cur / math.max(max, 1), 0, 1)
    tw(wildHPFill, { Size = UDim2.new(ratio, 0, 1, 0), BackgroundColor3 = hpColor(ratio) }, 0.25)
    wildHPTxt.Text = math.floor(cur) .. "/" .. max
end

local function updatePlayerHP(cur, max)
    pCurHP = cur
    pMaxHP = max
    local ratio = math.clamp(cur / math.max(max, 1), 0, 1)
    tw(pHPFill, { Size = UDim2.new(ratio, 0, 1, 0), BackgroundColor3 = hpColor(ratio) }, 0.25)
    pHPTxt.Text = math.floor(cur) .. "/" .. max
end

local function addLog(msg)
    if #logLines >= MAX_LOG then
        table.remove(logLines, 1)
    end
    table.insert(logLines, msg)
    for i, lbl in ipairs(logLabels) do
        local line = logLines[i]
        lbl.Text = line and ("> " .. line) or ""
    end
end

local function clearLog()
    logLines = {}
    for _, lbl in ipairs(logLabels) do lbl.Text = "" end
end

-- Announce a combatant's passive kit (species ability + held item) in the log
-- at battle start, so the damage swings they cause are legible instead of
-- mysterious. The ability is derived client-side from the species id; the held
-- item id rides in on the battle payload (players only — wild studs hold none,
-- but a Rare/Legendary wild still shows its ability, flagging a tougher fight).
local function logPassives(stud)
    if not stud or stud.hasStud == false or not stud.id then return end
    local who = stud.name or "Stud"
    local ability = StudData.GetAbility(stud.id)
    if ability then
        addLog((ability.icon or "✨") .. " " .. who .. "'s ability: " .. ability.name .. " — " .. ability.description)
    end
    local item = stud.heldItem and StudData.GetHeldItem(stud.heldItem)
    if item then
        addLog((item.icon or "🎽") .. " " .. who .. " is holding " .. item.name .. " — " .. item.description)
    end
end

local function setActionsEnabled(enabled)
    setBtnDisabled(atkBtn, not enabled)
    setBtnDisabled(catchBtn, not enabled)
    setBtnDisabled(runBtn, not enabled)
    if inMoveMode then
        setBtnDisabled(moveBtn4, not enabled)
        setBtnDisabled(backBtn, not enabled)
    end
end

-- ─── MOVE SUB-MENU ──────────────────────────────────────────────────────

local function showMoves()
    inMoveMode = true
    local pMoves = StudData.GetMoves(pInfo) -- per-species kit (falls back to type default)
    local pLevel = pInfo.level or 1

    -- Four move slots + back: 0.18 wide at 0 / 0.195 / 0.39 / 0.585
    atkBtn.Size = UDim2.new(0.18, 0, 0.78, 0)
    atkBtn.Position = UDim2.new(0, 0, 0.14, 0)
    catchBtn.Size = UDim2.new(0.18, 0, 0.78, 0)
    catchBtn.Position = UDim2.new(0.195, 0, 0.14, 0)
    runBtn.Size = UDim2.new(0.18, 0, 0.78, 0)
    runBtn.Position = UDim2.new(0.39, 0, 0.14, 0)
    moveBtn4.Visible = true

    for i = 1, 4 do
        local m = pMoves[i]
        local btn = ({ atkBtn, catchBtn, runBtn, moveBtn4 })[i]
        if m and StudData.IsMoveUnlocked(m, pLevel) then
            -- Show the accuracy tradeoff so "reliable vs swingy" is visible
            local accText = m.accuracy and (" · " .. math.floor(m.accuracy * 100 + 0.5) .. "%") or ""
            btn.Text = m.name .. "\n" .. m.power .. "x" .. accText
            setBtnDisabled(btn, false)
        elseif m then
            -- Locked: unlocks at m.unlockLevel (server enforces this too)
            btn.Text = m.name .. "\n🔒 Lv" .. m.unlockLevel
            setBtnDisabled(btn, true)
        else
            btn.Text = "-\n-"
            setBtnDisabled(btn, true)
        end
    end

    backBtn.Visible = true
end

-- Universal "back to the action bar" reset — leaves both the move submenu
-- and the catch-ball picker
local function hideMoves()
    inMoveMode = false
    inBallMode = false

    atkBtn.Size = UDim2.new(0.31, 0, 0.78, 0)
    atkBtn.Position = UDim2.new(0, 0, 0.14, 0)
    atkBtn.Text = "⚔️ ATTACK"
    catchBtn.Size = UDim2.new(0.31, 0, 0.78, 0)
    catchBtn.Position = UDim2.new(0.345, 0, 0.14, 0)
    catchBtn.Text = "🎯 CATCH"
    runBtn.Size = UDim2.new(0.31, 0, 0.78, 0)
    runBtn.Position = UDim2.new(0.69, 0, 0.14, 0)
    runBtn.Text = ">  RUN"

    moveBtn4.Visible = false
    backBtn.Visible = false
end

-- ─── CAPTURE MINIGAME (fallback bar-fill) ──────────────────────────────

local catchTapConn = nil

local function startCatch(params)
    catchActive  = true
    catchBar     = 0
    catchTarget  = params.barTarget or 100
    catchFillRate = params.fillPerTap or 8
    catchDecay   = params.decayRate or 2
    catchTimer   = params.timerDuration or 5
    catchRunning = true

    catchFrame.Visible = true
    catchBarFill.Size   = UDim2.new(0, 0, 1, 0)
    catchTimerLbl.Text  = "TIME: " .. string.format("%.1f", catchTimer) .. "s"
    setBtnDisabled(catchTapBtn, false)

    if catchTapConn then catchTapConn:Disconnect() catchTapConn = nil end

    catchTapConn = catchTapBtn.MouseButton1Click:Connect(function()
        if not catchRunning then return end
        catchBar = math.min(catchBar + catchFillRate, catchTarget)
        -- Report the tap so the server can validate the catch was earned
        local tapEvent = StudEvents:FindFirstChild("CatchTap")
        if tapEvent then
            tapEvent:FireServer()
        end
    end)

    if catchConn then catchConn:Disconnect() catchConn = nil end
    catchConn = RunService.RenderStepped:Connect(function(dt)
        if not catchRunning then return end

        if catchBar >= catchTarget then
            catchRunning = false
            setBtnDisabled(catchTapBtn, true)
            addLog("Capture attempt...")
            local ok, result = pcall(function()
                return StudEvents.EncounterAction:InvokeServer("CatchSuccess")
            end)
            if ok and result then
                addLog("Caught " .. (result.studName or wildInfo.name) .. "!")
                if result.isNew then
                    addLog("New stud discovered!")
                end
                if result.coins then
                    addLog("+" .. result.coins .. " coins!")
                end
                if result.expGained then
                    addLog(pInfo.name .. " gained " .. result.expGained .. " EXP!")
                    if result.leveledUp and result.newLevel then
                        addLog(pInfo.name .. " grew to Lv" .. result.newLevel .. "!")
                    end
                    updatePlayerExp(result.newLevel or pInfo.level or 1, result.newExp or 0)
                end
            else
                addLog("Catch failed!")
            end
            task.delay(1.5, function()
                catchFrame.Visible = false
                catchActive = false
                closeUI()
            end)
            return
        end

        catchBar = math.max(0, catchBar - catchDecay * dt)
        local ratio = catchBar / math.max(catchTarget, 1)
        catchBarFill.Size = UDim2.new(ratio, 0, 1, 0)
        catchTimer = catchTimer - dt
        catchTimerLbl.Text = "TIME: " .. string.format("%.1f", math.max(catchTimer, 0)) .. "s"

        if catchTimer <= 0 then
            catchRunning = false
            setBtnDisabled(catchTapBtn, true)
            addLog("The stud broke free!")
            pcall(function()
                StudEvents.EncounterAction:InvokeServer("CatchFail")
            end)
            task.delay(1, function()
                catchFrame.Visible = false
                catchActive = false
                setActionsEnabled(true)
            end)
        end
    end)
end

-- ─── NAMED ACTION HANDLERS (callable from buttons AND keyboard) ──────────

local function handleAttack()
    if actionLocked then return end
    if pInfo.hasStud == false then
        addLog("No Stud Equipped!")
        return
    end
    showMoves()
end

local function handleMoveSelect(i)
    if actionLocked then return end
    local pMoves = StudData.GetMoves(pInfo) -- per-species kit (falls back to type default)
    local move = pMoves[i]
    if move and not StudData.IsMoveUnlocked(move, pInfo.level or 1) then
        addLog(move.name .. " unlocks at Lv" .. move.unlockLevel .. "!")
        return
    end
    actionLocked = true
    setActionsEnabled(false)
    hideMoves()
    local moveName = (move and move.name) or "Attack"

    -- Arena battles route through BattleAction; results arrive via the
    -- BattleState listener (turn_update / battle_end), not the return value
    if battleMode == "arena" then
        addLog("Used " .. moveName .. "!")
        local ok = pcall(function()
            return StudEvents.BattleAction:InvokeServer("Attack", i)
        end)
        if not ok then
            addLog("Attack failed!")
        end
        actionLocked = false
        if isOpen then setActionsEnabled(true) end
        return
    end

    addLog("Used " .. moveName .. "!")
    local ok, result = pcall(function()
        return StudEvents.EncounterAction:InvokeServer("Attack", i)
    end)
    if ok and result and result.success == false then
        if result.reason == "no_stud" then
            addLog("No Stud Equipped!")
        else
            addLog("Attack failed!")
        end
        actionLocked = false
        setActionsEnabled(true)
        return
    end
    if ok and result then
        if result.wildHP then
            updateWildHP(result.wildHP, result.wildMaxHP or wMaxHP)
        end
        if result.playerHP then
            updatePlayerHP(result.playerHP, result.playerMaxHP or pMaxHP)
        end
        if result.missed then
            addLog("It missed!")
        end
        if result.isCrit then
            addLog("Critical hit!")
        end
        if not result.missed then
            if result.effectiveness and result.effectiveness > 1 then
                addLog("It's super effective!")
            elseif result.effectiveness and result.effectiveness < 1 then
                addLog("It's not very effective...")
            end
            if result.playerDmg and result.playerDmg > 0 then
                addLog("Wild " .. wildInfo.name .. " took " .. math.floor(result.playerDmg) .. " damage!")
            end
        end
        -- Status effects: infliction + per-turn ticks (burn/freeze/paralyze),
        -- mirrored onto the badge next to the wild's VITALITY label
        local statusBadge = {
            burn = { text = "🔥 BURNED", color = Color3.fromRGB(255, 140, 70) },
            freeze = { text = "❄️ FROZEN", color = Color3.fromRGB(140, 210, 240) },
            paralyze = { text = "⚡ PARALYZED", color = Color3.fromRGB(240, 210, 60) },
        }
        if result.statusInflicted then
            local inflictText = { burn = "was burned!", freeze = "was frozen solid!", paralyze = "was paralyzed!" }
            addLog("Wild " .. wildInfo.name .. " " .. (inflictText[result.statusInflicted] or "was afflicted!"))
            local badge = statusBadge[result.statusInflicted]
            if badge and wildStatusLbl then
                wildStatusLbl.Text = badge.text
                wildStatusLbl.TextColor3 = badge.color
            end
        end
        if result.statusTick then
            if result.statusTick.chip and result.statusTick.chip > 0 then
                addLog("Wild " .. wildInfo.name .. " is hurt by its burn! -" .. result.statusTick.chip .. " HP")
                if result.wildHP then
                    updateWildHP(result.wildHP, result.wildMaxHP or wMaxHP)
                end
            end
            if result.statusTick.skipped then
                addLog("Wild " .. wildInfo.name .. " can't move!")
            end
            if result.statusTick.cured and wildStatusLbl then
                wildStatusLbl.Text = ""
            end
        end
        if result.wildCrit then
            addLog("Wild " .. wildInfo.name .. " got a critical hit!")
        end
        if result.wildEffectiveness and result.wildEffectiveness > 1 then
            addLog("Wild attack is super effective!")
        end
        if result.wildDmg then
            addLog("Your " .. pInfo.name .. " took " .. math.floor(result.wildDmg) .. " damage!")
        end
        if result.result == "wild_fainted" then
            addLog("Wild " .. wildInfo.name .. " fainted!")
            if result.coins then
                addLog("Earned " .. result.coins .. " coins!")
            end
            if result.expGained then
                addLog(pInfo.name .. " gained " .. result.expGained .. " EXP!")
            end
            if result.leveledUp and result.newLevel then
                addLog(pInfo.name .. " grew to Lv" .. result.newLevel .. "!")
                pInfo.level = result.newLevel
                pNameLbl.Text = (pInfo.name or "???") .. " Lv" .. result.newLevel
            end
            if result.newExp then
                updatePlayerExp(result.newLevel or pInfo.level or 1, result.newExp)
            end
            task.delay(2, closeUI)
        elseif result.result == "player_fainted" then
            addLog("Your " .. pInfo.name .. " fainted!")
            if result.coinsLost and result.coinsLost > 0 then
                addLog("Dropped " .. result.coinsLost .. " coins!")
            end
            task.delay(2, closeUI)
        end
    else
        addLog("Attack failed!")
    end
    actionLocked = false
    setActionsEnabled(true)
end

-- Run the actual capture flow with the chosen ball ("none" = bare-handed)
local function doCatch(ballId)
    actionLocked = true
    setActionsEnabled(false)
    addLog("Attempting capture...")

    if UIManager.IsRegistered("StartCatchingMinigame") and encounterData then
        -- ANTI-CHEAT HANDSHAKE FIX: the server's CatchSuccess handler requires
        -- that "CatchStart" was invoked first (and ≥1.5s elapsed). This path
        -- previously skipped CatchStart entirely, so every catch was rejected
        -- server-side ("catch_not_started") even though the UI said "Caught!".
        local startOk, startParams = pcall(function()
            return StudEvents.EncounterAction:InvokeServer("CatchStart", ballId)
        end)
        if not startOk then
            addLog("Can't catch right now!")
            actionLocked = false
            setActionsEnabled(true)
            return
        end
        if startParams and startParams.ballName then
            addLog("Used a " .. startParams.ballName .. "!")
        end
        UIManager.Register("OnCatchingMinigameEnd", function(wasCaught, result)
            UIManager.Unregister("OnCatchingMinigameEnd")
            if wasCaught then
                if result then
                    addLog("Caught " .. (result.studName or wildInfo.name) .. "!")
                    if result.isNew then addLog("New stud discovered!") end
                    if result.coins then addLog("+" .. result.coins .. " coins!") end
                    if result.chainCount and result.chainCount > 1 then
                        addLog("Chain x" .. result.chainCount .. "! Shiny odds rising!")
                    end
                    if result.expGained then
                        addLog(pInfo.name .. " gained " .. result.expGained .. " EXP!")
                        if result.leveledUp and result.newLevel then
                            addLog(pInfo.name .. " grew to Lv" .. result.newLevel .. "!")
                        end
                    end
                end
                task.delay(1.2, closeUI)
            elseif result and result.result == "player_fainted" then
                addLog("Your " .. pInfo.name .. " fainted!")
                if result.coinsLost and result.coinsLost > 0 then
                    addLog("Dropped " .. result.coinsLost .. " coins!")
                end
                task.delay(1.5, closeUI)
            elseif result and result.result == "escaped" then
                addLog("Got away safely!")
                task.delay(0.8, closeUI)
            else
                if result and result.playerHP then
                    updatePlayerHP(result.playerHP, result.playerMaxHP or pMaxHP)
                end
                if result and result.wildDmg then
                    addLog("Wild " .. wildInfo.name .. " attacked for " .. math.floor(result.wildDmg) .. " damage!")
                end
                actionLocked = false
                setActionsEnabled(true)
            end
        end)

        local studInfo = {
            id = encounterData.id,
            name = encounterData.name,
            studType = encounterData.studType,
            rarity = encounterData.rarity,
            colorR = encounterData.colorR or 200,
            colorG = encounterData.colorG or 200,
            colorB = encounterData.colorB or 200,
            isShiny = encounterData.isShiny or false,
            wildMaxHP = encounterData.wildMaxHP,
            wildHP = encounterData.wildHP,
            -- Catch ball consumed by the server at CatchStart: the circle
            -- minigame shrinks its bar target by this factor
            ballMult = startParams and startParams.ballMult or nil,
            ballName = startParams and startParams.ballName or nil,
        }
        UIManager.Call("StartCatchingMinigame", studInfo)
    else
        local ok, params = pcall(function()
            return StudEvents.EncounterAction:InvokeServer("CatchStart", ballId)
        end)
        if ok and params then
            if params.ballName then
                addLog("Used a " .. params.ballName .. "!")
            end
            actionLocked = false
            startCatch(params)
        else
            addLog("Can't catch right now!")
            actionLocked = false
            setActionsEnabled(true)
        end
    end
end

-- Catch pressed: show the ball picker on the action bar — [No Ball],
-- then one slot per ball type with the owned count (owned counts come
-- from the shop's ShopInfo remote; unowned balls are greyed out)
local function showBallPicker()
    inBallMode = true

    local counts = {}
    local infoFunc = StudEvents:FindFirstChild("ShopInfo")
    if infoFunc then
        local ok, shopInfo = pcall(function()
            return infoFunc:InvokeServer()
        end)
        if ok and shopInfo and shopInfo.items then
            counts = shopInfo.items
        end
    end

    ballOptions = { { id = "none", label = "🚫 NO BALL", disabled = false } }
    for _, ball in ipairs(StudData.CatchBalls) do
        local n = counts[ball.id] or 0
        table.insert(ballOptions, {
            id = ball.id,
            label = string.upper(ball.name) .. "\nx" .. n,
            disabled = n <= 0,
        })
    end

    for i = 1, 3 do
        local btn = ({ atkBtn, catchBtn, runBtn })[i]
        local opt = ballOptions[i]
        if opt then
            btn.Text = opt.label
            setBtnDisabled(btn, opt.disabled)
        else
            btn.Text = "-"
            setBtnDisabled(btn, true)
        end
    end
    backBtn.Visible = true
end

local function handleBallSelect(i)
    if actionLocked then return end
    local opt = ballOptions[i]
    if not opt or opt.disabled then return end
    hideMoves() -- restores the action bar (also clears inBallMode)
    doCatch(opt.id)
end

local function handleCatch()
    if actionLocked or catchActive then return end

    -- Trainer studs can't be caught (server rejects this too)
    if trainerMode then
        addLog("You can't catch a trainer's stud!")
        return
    end

    -- Arena catches are a server-side chance roll, no minigame and no balls
    if battleMode == "arena" then
        actionLocked = true
        setActionsEnabled(false)
        addLog("Attempting capture...")
        local ok = pcall(function()
            return StudEvents.BattleAction:InvokeServer("Catch")
        end)
        if not ok then
            addLog("Can't catch right now!")
        end
        actionLocked = false
        if isOpen then setActionsEnabled(true) end
        return
    end

    showBallPicker()
end

local function handleRun()
    if actionLocked then return end
    actionLocked = true
    setActionsEnabled(false)
    addLog("Attempting to flee...")

    if battleMode == "arena" then
        pcall(function()
            return StudEvents.BattleAction:InvokeServer("Flee")
        end)
        -- battle_end (result "fled") from the BattleState listener closes the UI
        actionLocked = false
        return
    end

    local ok, result = pcall(function()
        return StudEvents.EncounterAction:InvokeServer("Run")
    end)
    if ok and result and result.result == "escaped" then
        addLog("Got away safely!")
        task.delay(0.8, closeUI)
    elseif ok and result and (result.result == "flee_failed" or result.result == "player_fainted") then
        -- Speed-based flee failed: the wild stud got a free hit in
        addLog("Couldn't escape!")
        if result.playerHP then
            updatePlayerHP(result.playerHP, result.playerMaxHP or pMaxHP)
        end
        if result.wildDmg then
            addLog("Wild " .. wildInfo.name .. " attacked for " .. math.floor(result.wildDmg) .. " damage!")
        end
        if result.result == "player_fainted" then
            addLog("Your " .. pInfo.name .. " fainted!")
            if result.coinsLost and result.coinsLost > 0 then
                addLog("Dropped " .. result.coinsLost .. " coins!")
            end
            task.delay(2, closeUI)
        else
            actionLocked = false
            setActionsEnabled(true)
        end
    else
        addLog("Can't escape!")
        actionLocked = false
        setActionsEnabled(true)
    end
end

-- ─── CONNECT BUTTON EVENTS (called after buildUI) ──────────────────────

local function connectEvents()
    atkBtn.MouseButton1Click:Connect(function()
        if inBallMode then
            handleBallSelect(1)
        elseif inMoveMode then
            handleMoveSelect(1)
        else
            handleAttack()
        end
    end)

    catchBtn.MouseButton1Click:Connect(function()
        if inBallMode then
            handleBallSelect(2)
        elseif inMoveMode then
            handleMoveSelect(2)
        else
            handleCatch()
        end
    end)

    runBtn.MouseButton1Click:Connect(function()
        if inBallMode then
            handleBallSelect(3)
        elseif inMoveMode then
            handleMoveSelect(3)
        else
            handleRun()
        end
    end)

    moveBtn4.MouseButton1Click:Connect(function()
        if inMoveMode then
            handleMoveSelect(4)
        end
    end)

    -- Cancel out of the move submenu or ball picker: restore the action bar
    -- and re-enable buttons (a greyed ball slot must not leave RUN disabled)
    backBtn.MouseButton1Click:Connect(function()
        hideMoves()
        if not actionLocked then
            setActionsEnabled(true)
        end
    end)
end

-- ─── OPEN / CLOSE ──────────────────────────────────────────────────────

-- Every world-HUD ScreenGui that must vanish during a battle — including
-- the whole top-right rail (coins pill, quest/settings/leaderboard/shop
-- toggles) so nothing overlaps or distracts from the battle screen.
local WORLD_HUD_GUIS = {
    "GameHUD", "QuestUI", "CatchStreak", "StatsHud", "WeatherDisplay",
    "AreaNameDisplay", "SettingsMenu", "LeaderboardUI", "ShopUI",
}

local function setWorldHudVisible(visible)
    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return end
    for _, guiName in ipairs(WORLD_HUD_GUIS) do
        local gui = playerGui:FindFirstChild(guiName)
        if gui then
            gui.Enabled = visible
        end
    end
end

local function openBattleUI(wildStud, playerStud, wMax, pMax)
    if isOpen then return end
    isOpen = true

    setWildInfo(wildStud)
    setPlayerInfo(playerStud)
    updateWildHP(wMax, wMax)
    updatePlayerHP(pMax, pMax)
    wCurHP = wMax
    pCurHP = pMax

    clearLog()
    addLog("A wild " .. (wildStud.name or "stud") .. " appeared!")

    if wildStatusLbl then
        wildStatusLbl.Text = "" -- fresh wild, no status
    end
    hideMoves()
    catchFrame.Visible = false
    catchActive = false
    catchRunning = false
    if catchConn then catchConn:Disconnect() catchConn = nil end
    actionLocked = false
    setActionsEnabled(true)

    setWorldHudVisible(false)

    main.Visible = true
    lockWalk()
end

function closeUI()
    if not isOpen then return end
    isOpen = false

    catchRunning = false
    if catchConn then catchConn:Disconnect() catchConn = nil end
    catchFrame.Visible = false
    catchActive = false
    actionLocked = false

    setWorldHudVisible(true)

    main.Visible = false
    unlockWalk()
end

UIManager.Register("OpenBattleUI", openBattleUI)
UIManager.Register("CloseBattleUI", closeUI)

-- ─── ENCOUNTER START LISTENER ──────────────────────────────────────────
StudEvents.EncounterStart.OnClientEvent:Connect(function(data)
    if isOpen then return end

    local wildStud = {
        id          = data.id,
        name        = data.name,
        studType    = data.studType,
        rarity      = data.rarity,
        description = data.description,
        colorR      = data.colorR,
        colorG      = data.colorG,
        colorB      = data.colorB,
        isShiny     = data.isShiny,
        level       = data.wildLevel,
    }
    local playerStud = {
        hasStud  = data.playerStud ~= nil,
        id       = data.playerStud and data.playerStud.id,
        name     = data.playerStud and data.playerStud.name,
        studType = data.playerStud and data.playerStud.studType,
        rarity   = data.playerStud and data.playerStud.rarity,
        level    = data.playerStud and data.playerStud.level,
        exp      = data.playerStud and data.playerStud.exp,
        heldItem = data.playerStud and data.playerStud.heldItem,
    }

    encounterData = data
    battleMode = "encounter"
    trainerMode = false

    openBattleUI(
        wildStud,
        playerStud,
        data.wildMaxHP or 80,
        data.playerMaxHP or (playerStud.hasStud and 80 or 0)
    )

    if data.wildHP then updateWildHP(data.wildHP, data.wildMaxHP or 80) end
    if data.playerHP then
        updatePlayerHP(data.playerHP, data.playerMaxHP or 80)
    elseif not playerStud.hasStud then
        pHPTxt.Text = "--"
    end

    -- Surface each side's passive kit (ability + held item) up front
    logPassives(playerStud)
    logPassives(wildStud)

    -- Faster wild stud landed a free opening hit (speed first-strike)
    if data.firstStrike then
        addLog("Wild " .. (wildStud.name or "stud") .. " strikes first! -" .. math.floor(data.firstStrike.dmg) .. " HP" .. (data.firstStrike.isCrit and " Critical!" or ""))
    end
end)

-- ─── BATTLE STATE LISTENER (arena battles) ────────────────────────────
StudEvents.BattleState.OnClientEvent:Connect(function(state)
    if type(state) ~= "table" then return end

    -- Arena/trainer battle opens the same UI in arena mode
    if state.action == "battle_start" then
        if isOpen then return end
        battleMode = "arena"
        trainerMode = state.isTrainer or false
        encounterData = nil
        local wildStud = state.wildStud or {}
        wildStud.level = wildStud.level or 1
        local playerStud = state.playerStud or {}
        playerStud.hasStud = true
        openBattleUI(wildStud, playerStud, state.wildMaxHP or 80, state.playerMaxHP or 80)
        wildEyebrowLbl.Text = trainerMode and ((state.trainerName or "TRAINER"):upper() .. "'S STUD") or "ARENA CHALLENGER"
        if state.log then
            for _, msg in ipairs(state.log) do
                addLog(msg)
            end
        end
        -- Surface each side's passive kit (ability + held item) up front
        logPassives(playerStud)
        logPassives(wildStud)
        return
    end

    if not isOpen or battleMode ~= "arena" then return end

    if state.wildHP and state.wildMaxHP then
        updateWildHP(state.wildHP, state.wildMaxHP)
    end
    if state.playerHP and state.playerMaxHP then
        updatePlayerHP(state.playerHP, state.playerMaxHP)
    end

    if state.log then
        if type(state.log) == "table" then
            for _, msg in ipairs(state.log) do
                addLog(msg)
            end
        elseif type(state.log) == "string" then
            addLog(state.log)
        end
    end

    if state.newExp then
        updatePlayerExp(state.newLevel or pInfo.level or 1, state.newExp)
        if state.leveledUp and state.newLevel then
            pInfo.level = state.newLevel
            pNameLbl.Text = (pInfo.name or "???") .. " Lv" .. state.newLevel
        end
    end

    -- Trainer sent out their next stud: swap the wild card, player acts first
    if state.action == "trainer_next" and state.wildStud then
        setWildInfo(state.wildStud)
        if wildStatusLbl then
            wildStatusLbl.Text = ""
        end
        actionLocked = false
        setActionsEnabled(true)
        return
    end

    if state.action == "battle_end" then
        setActionsEnabled(false)
        if state.result == "win" then
            addLog("You won the battle!")
        elseif state.result == "lose" then
            addLog("You lost the battle!")
        elseif state.result == "catch" then
            addLog("Stud was caught!")
        elseif state.result == "draw" then
            addLog("Battle ended in a draw!")
        end
        task.delay(state.result == "fled" and 0.5 or 2.5, closeUI)
    end
end)

-- ─── ARENA ENTRY (BattlePad prompt in Studville) ───────────────────────
-- BuildingInteractions pulses the OpenBattle attribute when the player
-- triggers the Battle Arena pad. Start an arena battle with the equipped
-- stud (same species rule as wild encounters).
player:GetAttributeChangedSignal("OpenBattle"):Connect(function()
    if not player:GetAttribute("OpenBattle") then return end
    if isOpen then return end
    local equippedId = player:GetAttribute("EquippedStud")
    if not equippedId then
        if UIManager.IsRegistered("Notify") then
            UIManager.Call("Notify", "warning", "Battle Arena", "Equip a stud first! (Open your inventory with E)")
        end
        return
    end
    local ok, result = pcall(function()
        return StudEvents.StartBattle:InvokeServer(equippedId)
    end)
    if not ok or not result or not result.success then
        if UIManager.IsRegistered("Notify") then
            UIManager.Call("Notify", "warning", "Battle Arena", "Couldn't start a battle right now.")
        end
    end
    -- On success the server fires BattleState "battle_start", handled above
end)

-- ─── KEYBOARD SHORTCUTS ────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not isOpen then return end
    if input.KeyCode == Enum.KeyCode.One then
        if inBallMode then
            handleBallSelect(1)
        elseif inMoveMode then
            handleMoveSelect(1)
        else
            handleAttack()
        end
    elseif input.KeyCode == Enum.KeyCode.Two then
        if inBallMode then
            handleBallSelect(2)
        elseif inMoveMode then
            handleMoveSelect(2)
        else
            handleCatch()
        end
    elseif input.KeyCode == Enum.KeyCode.Three then
        if inBallMode then
            handleBallSelect(3)
        elseif inMoveMode then
            handleMoveSelect(3)
        else
            handleRun()
        end
    elseif input.KeyCode == Enum.KeyCode.Four then
        if inMoveMode then
            handleMoveSelect(4)
        end
    elseif input.KeyCode == Enum.KeyCode.Escape then
        if inMoveMode or inBallMode then
            hideMoves()
            if not actionLocked then
                setActionsEnabled(true)
            end
        elseif catchActive then
            -- Can't escape the capture minigame
        end
    end
end)

-- ─── INIT ───────────────────────────────────────────────────────────────
buildUI()
connectEvents()
