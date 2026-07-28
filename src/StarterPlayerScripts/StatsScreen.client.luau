--[[
    StatsScreen.lua — Player Stats Screen for Stud Catcher
    Retro pixel-art style · Instance.new() only · No UICorner · No external assets

    Opened by:  Square [STATS] HUD button (top-left, always visible)
    Closes on:  X button, Escape key, or clicking the HUD button again

    Shows: username, coins, studs caught, studs seen, level, XP bar
    Layout: two-column grid of square tiles
]]

-- ─── SERVICES ──────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

-- ─── REFERENCES ──────────────────────────────────────────────────────────
local player     = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData   = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager  = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme    = require(ReplicatedStorage:WaitForChild("UITheme"))

-- ─── PALETTE ─────────────────────────────────────────────────────────────
local C_BG        = UITheme.C_BG
local C_PANEL     = UITheme.C_PANEL
local C_ACCENT    = UITheme.C_ACCENT
local C_WHITE     = UITheme.C_WHITE
local C_SEC       = UITheme.C_SEC
local C_BTN_N     = Color3.fromRGB(28, 31, 42)
local C_BTN_H     = Color3.fromRGB(48, 51, 62)
local C_BTN_P     = Color3.fromRGB(255, 220, 60)
local C_BORDER    = UITheme.C_BORDER
local C_BAR_BG    = UITheme.HP_BG

-- ─── FONTS ───────────────────────────────────────────────────────────────
local F_HEAD = UITheme.F_HEAD
local F_BODY = UITheme.F_BODY
local F_BTN  = UITheme.F_BTN

-- ─── STATE ───────────────────────────────────────────────────────────────
local gui
local hudGui           -- separate ScreenGui for the HUD button
local main
local isOpen           = false
local hudBtn

-- ─── BUTTON STATE LOOKUP (avoids custom methods on Instances) ──────────
local _btnState = {}  -- [button] = { disabled, nBg, nTc, nSc, stroke }

-- Player stats (fetched from server)
local stats = {
    username    = "",
    coins       = 0,
    totalCaught = 0,
    uniqueCount = 0,
    level       = 1,
    xpCurrent   = 0,
    xpNeeded    = 5,
}

-- Cached UI references, deliberately kept out of `stats` so the data model
-- above keeps its exact type and a typo in e.g. stats.coins stays an error.
local view: { [string]: any } = {}

-- ─── WALKSPEED LOCK (via UIManager) ──────────────────────────────────────
local function lockWalk()
    UIManager.AcquireLock()
end

local function unlockWalk()
    UIManager.ReleaseLock()
end

-- ─── HELPERS ─────────────────────────────────────────────────────────────
local function tw(obj, props, dur)
    dur = dur or 0.15
    TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Linear), props):Play()
end

-- ─── BUTTON DISABLE HELPER ────────────────────────────────────────────
local function setBtnDisabled(btn, v)
    local s = _btnState[btn]
    if not s then return end
    s.disabled = v
    if v then
        btn.BackgroundColor3 = C_BG; btn.TextColor3 = C_SEC; s.stroke.Color = C_BORDER
    else
        btn.BackgroundColor3 = s.nBg; btn.TextColor3 = s.nTc; s.stroke.Color = s.nSc
    end
end

-- ─── UI FACTORY ─────────────────────────────────────────────────────────

local function mkFrame(p)
    local f = Instance.new("Frame")
    f.Name             = p.name or "F"
    f.Size             = p.size or UDim2.new(1, 0, 1, 0)
    f.Position         = p.pos or UDim2.new(0, 0, 0, 0)
    f.BackgroundColor3 = p.bg or C_PANEL
    f.BorderSizePixel  = 0
    if p.anchor then f.AnchorPoint = p.anchor end
    if p.clip   then f.ClipsDescendants = true end
    if p.parent then f.Parent = p.parent end
    if p.stroke then
        local s = Instance.new("UIStroke")
        s.Color     = p.stroke
        s.Thickness = 1
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
    l.TextColor3         = p.color or C_WHITE
    l.Font               = p.font or F_BODY
    l.TextSize           = p.ts or 16
    l.TextXAlignment     = p.xa or Enum.TextXAlignment.Left
    l.TextYAlignment     = p.ya or Enum.TextYAlignment.Center
    if p.parent then l.Parent = p.parent end
    return l
end

local function mkBtn(p)
    local b = Instance.new("TextButton")
    b.Name               = p.name or "Btn"
    b.Size               = p.size or UDim2.new(0, 120, 0, 48)
    b.Position           = p.pos or UDim2.new(0, 0, 0, 0)
    b.BackgroundColor3   = p.bg or C_BTN_N
    b.TextColor3         = p.tc or C_WHITE
    b.Font               = p.font or F_BTN
    b.TextSize           = p.ts or 16
    b.Text               = p.text or ""
    b.BorderSizePixel    = 0
    b.AutoButtonColor    = false
    if p.anchor then b.AnchorPoint = p.anchor end
    if p.parent then b.Parent = p.parent end

    local stroke = Instance.new("UIStroke")
    stroke.Color     = p.sc or C_SEC
    stroke.Thickness = 1
    stroke.Parent    = b

    local nBg = p.bg or C_BTN_N
    local nTc = p.tc or C_WHITE
    local nSc = p.sc or C_SEC

    -- Store state in lookup table (cannot add custom methods to Instances)
    _btnState[b] = { disabled = false, nBg = nBg, nTc = nTc, nSc = nSc, stroke = stroke }

    b.MouseEnter:Connect(function()
        if not _btnState[b].disabled then tw(b, {BackgroundColor3 = C_BTN_H}) tw(stroke, {Color = C_ACCENT}) end
    end)
    b.MouseLeave:Connect(function()
        if not _btnState[b].disabled then tw(b, {BackgroundColor3 = nBg}) tw(stroke, {Color = nSc}) end
    end)
    b.MouseButton1Down:Connect(function()
        if not _btnState[b].disabled then tw(b, {BackgroundColor3 = C_BTN_P, TextColor3 = C_BG}) end
    end)
    b.MouseButton1Up:Connect(function()
        if not _btnState[b].disabled then tw(b, {BackgroundColor3 = C_BTN_H, TextColor3 = nTc}) end
    end)

    return b
end

-- ─── BUILD HUD BUTTON ──────────────────────────────────────────────────
local function buildHudButton()
    hudGui = Instance.new("ScreenGui")
    hudGui.Name           = "StatsHud"
    hudGui.ResetOnSpawn   = false
    hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    hudGui.Parent         = player:WaitForChild("PlayerGui")

    -- Square HUD button top-left
    hudBtn = mkBtn({
        name   = "StatsHudBtn",
        size   = UDim2.new(0, 56, 0, 56),
        pos    = UDim2.new(0, 8, 0, 8),
        text   = "STATS",
        tc     = C_ACCENT,
        font   = F_BTN,
        ts     = 14,
        bg     = C_PANEL,
        sc     = C_ACCENT,
        parent = hudGui,
    })

    hudBtn.MouseButton1Click:Connect(function()
        if isOpen then
            closeStats()
        else
            openStats()
        end
    end)
end

-- ─── BUILD STATS SCREEN ────────────────────────────────────────────────
local function buildStatsScreen()
    gui = Instance.new("ScreenGui")
    gui.Name           = "StatsScreen"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player:WaitForChild("PlayerGui")

    -- Main container
    main = mkFrame({ name = "Main", bg = C_BG, parent = gui })
    main.Visible = false

    -- ── HEADER ─────────────────────────────────────────────────────────
    local header = mkFrame({
        name   = "Header",
        size   = UDim2.new(1, -16, 0, 48),
        pos    = UDim2.new(0, 8, 0, 8),
        parent = main,
    })
    header.BackgroundTransparency = 1

    mkLabel({
        name   = "Title",
        size   = UDim2.new(0.5, 0, 1, 0),
        text   = "STATS",
        color  = C_ACCENT,
        font   = F_HEAD,
        ts     = 32,
        parent = header,
    })

    -- X close button
    local closeBtn = mkBtn({
        name   = "CloseBtn",
        size   = UDim2.new(0, 40, 0, 40),
        pos    = UDim2.new(1, -40, 0, 4),
        text   = "X",
        tc     = C_WHITE,
        font   = F_HEAD,
        ts     = 24,
        bg     = C_PANEL,
        sc     = C_SEC,
        parent = header,
    })
    closeBtn.MouseButton1Click:Connect(closeStats)

    -- ── USERNAME TILE (full width) ─────────────────────────────────────
    local nameTile = mkFrame({
        name   = "NameTile",
        size   = UDim2.new(1, -16, 0, 48),
        pos    = UDim2.new(0, 8, 0, 64),
        bg     = C_PANEL,
        stroke = C_SEC,
        pad    = 8,
        parent = main,
    })
    mkLabel({
        name   = "Username",
        size   = UDim2.new(1, 0, 1, 0),
        text   = player.Name,
        color  = C_WHITE,
        font   = F_HEAD,
        ts     = 24,
        xa     = Enum.TextXAlignment.Center,
        parent = nameTile,
    })

    -- ── TWO-COLUMN STAT GRID ──────────────────────────────────────────
    local gridFrame = mkFrame({
        name   = "GridFrame",
        size   = UDim2.new(1, -16, 0, 160),
        pos    = UDim2.new(0, 8, 0, 120),
        parent = main,
    })
    gridFrame.BackgroundTransparency = 1

    local gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize    = UDim2.new(0.5, -4, 0, 72)
    gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
    gridLayout.SortOrder   = Enum.SortOrder.LayoutOrder
    gridLayout.Parent      = gridFrame

    -- Stat tiles: Coins, Caught, Seen, Level
    local statDefs = {
        { label = "COINS",       key = "coins",       color = C_ACCENT,  order = 1 },
        { label = "STUDS CAUGHT", key = "totalCaught", color = Color3.fromRGB(50, 200, 50), order = 2 },
        { label = "STUDS SEEN",   key = "uniqueCount", color = Color3.fromRGB(50, 100, 255), order = 3 },
        { label = "LEVEL",        key = "level",       color = C_ACCENT,  order = 4 },
    }

    for _, def in ipairs(statDefs) do
        local tile = mkFrame({
            name   = def.label,
            bg     = C_PANEL,
            stroke = def.color,
            pad    = 8,
            parent = gridFrame,
        })
        tile.LayoutOrder = def.order

        mkLabel({
            name   = "Lbl",
            size   = UDim2.new(1, 0, 0, 16),
            pos    = UDim2.new(0, 0, 0, 4),
            text   = def.label,
            color  = C_SEC,
            font   = F_BODY,
            ts     = 12,
            xa     = Enum.TextXAlignment.Center,
            parent = tile,
        })
        mkLabel({
            name   = "Val",
            size   = UDim2.new(1, 0, 0, 32),
            pos    = UDim2.new(0, 0, 0, 24),
            text   = "0",
            color  = def.color,
            font   = F_HEAD,
            ts     = 32,
            xa     = Enum.TextXAlignment.Center,
            parent = tile,
        })
    end

    -- ── XP BAR ────────────────────────────────────────────────────────
    local xpSection = mkFrame({
        name   = "XPSection",
        size   = UDim2.new(1, -16, 0, 48),
        pos    = UDim2.new(0, 8, 0, 296),
        bg     = C_PANEL,
        stroke = C_SEC,
        pad    = 8,
        parent = main,
    })

    mkLabel({
        name   = "XPLbl",
        size   = UDim2.new(1, 0, 0, 16),
        pos    = UDim2.new(0, 0, 0, 0),
        text   = "XP: 0 / 5",
        color  = C_SEC,
        font   = F_BODY,
        ts     = 14,
        parent = xpSection,
    })

    local xpBarBg = mkFrame({
        name   = "XPBarBg",
        size   = UDim2.new(1, 0, 0, 16),
        pos    = UDim2.new(0, 0, 0, 20),
        bg     = C_BAR_BG,
        stroke = C_SEC,
        clip   = true,
        parent = xpSection,
    })
    local xpFill = Instance.new("Frame")
    xpFill.Name             = "XPFill"
    xpFill.Size             = UDim2.new(0, 0, 1, 0)
    xpFill.BackgroundColor3 = C_ACCENT
    xpFill.BorderSizePixel  = 0
    xpFill.Parent           = xpBarBg

    -- Store references for updating
    view.gridFrame = gridFrame
    view.xpLbl     = xpSection:FindFirstChild("XPLbl")
    view.xpFill    = xpFill
end

-- ─── FETCH STATS FROM SERVER ──────────────────────────────────────────
local function fetchStats()
    local ok, data = pcall(function()
        return StudEvents.GetPlayerStats:InvokeServer()
    end)
    if ok and data then
        stats.username    = player.Name
        stats.coins       = data.coins or 0
        stats.totalCaught = data.totalCaught or data.totalCount or 0
        stats.uniqueCount = data.uniqueCount or 0

        -- Derive level from unique studs seen
        -- Every 5 unique studs = 1 level
        stats.level     = math.floor(stats.uniqueCount / 5) + 1
        stats.xpCurrent = stats.uniqueCount % 5
        stats.xpNeeded  = 5
    end
end

-- ─── UPDATE DISPLAY ────────────────────────────────────────────────────
local function updateDisplay()
    -- Update stat tile values
    if view.gridFrame then
        local tiles = view.gridFrame:GetChildren()
        for _, tile in ipairs(tiles) do
            if tile:IsA("Frame") then
                local valLbl = tile:FindFirstChild("Val")
                if valLbl then
                    if tile.Name == "COINS" then
                        valLbl.Text = tostring(stats.coins)
                    elseif tile.Name == "STUDS CAUGHT" then
                        valLbl.Text = tostring(stats.totalCaught)
                    elseif tile.Name == "STUDS SEEN" then
                        valLbl.Text = tostring(stats.uniqueCount)
                    elseif tile.Name == "LEVEL" then
                        valLbl.Text = tostring(stats.level)
                    end
                end
            end
        end
    end

    -- Update XP bar
    if view.xpLbl then
        view.xpLbl.Text = "XP: " .. stats.xpCurrent .. " / " .. stats.xpNeeded
    end
    if view.xpFill then
        local ratio = math.clamp(stats.xpCurrent / math.max(stats.xpNeeded, 1), 0, 1)
        view.xpFill.Size = UDim2.new(ratio, 0, 1, 0)
    end
end

-- ─── OPEN / CLOSE ──────────────────────────────────────────────────────

function openStats()
    if isOpen then return end
    isOpen = true
    fetchStats()
    updateDisplay()
    main.Visible = true
    lockWalk()
end

function closeStats()
    if not isOpen then return end
    isOpen = false
    main.Visible = false
    unlockWalk()
end

UIManager.Register("OpenStats", openStats)
UIManager.Register("CloseStats", closeStats)

-- ─── KEYBOARD SHORTCUTS ────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe or not isOpen then return end
    if input.KeyCode == Enum.KeyCode.Escape then
        closeStats()
    end
end)

-- ─── LISTEN FOR COIN UPDATES ──────────────────────────────────────────
if StudEvents:FindFirstChild("UpdateCoins") then
    StudEvents.UpdateCoins.OnClientEvent:Connect(function()
        if isOpen then
            fetchStats()
            updateDisplay()
        end
    end)
end

-- ─── INIT ───────────────────────────────────────────────────────────────
buildHudButton()
buildStatsScreen()