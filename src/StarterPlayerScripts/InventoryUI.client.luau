--[[
    InventoryUI.lua — Full-screen Inventory for Stud Catcher
    Retro pixel-art style · Instance.new() only · No UICorner · No external assets

    Opened via:  UIManager.Call("OpenInventory")
    Closes on:   X button, Escape key

    Layout:
      Left  → Scrollable grid of square Stud tiles (name, type badge, rarity border, level)
      Right → Detail panel (icon, name, type, rarity, stats, moves, SELL button)
      Top   → Search bar (filters by name, type, rarity)
      Top-R → X close button
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
local C_BTN_D     = Color3.fromRGB(18, 20, 28)
local C_BORDER    = UITheme.C_BORDER
local C_BAR_BG    = UITheme.HP_BG

-- Rarity border colours (grey / green / blue / gold)
local RARITY_BORDER = UITheme.RARITY_COLORS

-- ─── FONTS ───────────────────────────────────────────────────────────────
local F_HEAD = UITheme.F_HEAD
local F_BODY = UITheme.F_BODY
local F_BTN  = UITheme.F_BTN

-- ─── STATE ───────────────────────────────────────────────────────────────
local gui
local main
local isOpen       = false
local collection   = {}   -- array of stud data from server
local equippedStudId = nil -- currently equipped stud, from server
local heldItems    = {}   -- [speciesId] = itemId (equipped held items)
local ownedItems   = {}   -- [itemId] = count (unequipped pool, for the picker)
local filtered     = {}   -- filtered subset
local selectedIdx  = nil  -- index into filtered
local searchQuery  = ""

-- UI references
local gridScroll   -- ScrollingFrame for the grid
local gridLayout   -- UIGridLayout
local detailPanel  -- right-side detail panel
local detailContent -- inner frame rebuilt on selection
local searchBox    -- TextBox for search
local placeholder  -- "SELECT A STUD" label

-- ─── BUTTON STATE LOOKUP (avoids custom methods on Instances) ──────────
local _btnState = {}  -- [button] = { disabled, nBg, nTc, nSc, stroke }

-- ─── WALKSPEED LOCK (via UIManager) ──────────────────────────────────────
local function lockWalk()
    UIManager.AcquireLock()
end

local function unlockWalk()
    UIManager.ReleaseLock()
end

-- ─── HIDE ALL OTHER UI WHILE INVENTORY IS OPEN ─────────────────────────
local hiddenGuis = {}
local function setOtherGuisHidden(hidden)
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    if hidden then
        table.clear(hiddenGuis)
        for _, g in ipairs(pg:GetChildren()) do
            if g:IsA("ScreenGui") and g ~= gui and g.Enabled then
                g.Enabled = false
                table.insert(hiddenGuis, g)
            end
        end
    else
        for _, g in ipairs(hiddenGuis) do
            if g.Parent then g.Enabled = true end
        end
        table.clear(hiddenGuis)
    end
end

-- ─── HELPERS ─────────────────────────────────────────────────────────────
local function typeColor(t)
    local d = StudData.Types[t]
    return d and d.color or C_SEC
end

local function rarityColor(r)
    local d = StudData.Rarity[r]
    return d and d.color or C_SEC
end

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
        btn.BackgroundColor3 = C_BTN_D; btn.TextColor3 = C_SEC; s.stroke.Color = C_BORDER
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
    if p.anchor   then f.AnchorPoint = p.anchor end
    if p.clip     then f.ClipsDescendants = true end
    if p.parent   then f.Parent = p.parent end
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
    if p.anchor  then l.AnchorPoint = p.anchor end
    if p.parent  then l.Parent = p.parent end
    if p.stroke then
        local s = Instance.new("UIStroke")
        s.Color     = p.stroke
        s.Thickness = 1
        s.Parent    = l
    end
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
    if p.anchor  then b.AnchorPoint = p.anchor end
    if p.parent  then b.Parent = p.parent end

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

-- Type badge: small square with type colour + label
local function mkTypeBadge(parent, studType, pos, size)
    size = size or UDim2.new(0, 56, 0, 20)
    local tc = typeColor(studType)
    local badge = mkFrame({ name = "Badge", size = size, pos = pos, bg = tc, stroke = tc, parent = parent })
    mkLabel({ name = "BL", text = studType:upper(), color = C_BG, font = F_BTN, ts = 11, xa = Enum.TextXAlignment.Center, parent = badge })
    return badge
end

-- ─── BUILD UI ────────────────────────────────────────────────────────────
local function buildUI()
    -- ScreenGui
    gui = Instance.new("ScreenGui")
    gui.Name           = "InventoryUI"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player:WaitForChild("PlayerGui")

    -- Main container
    main = mkFrame({ name = "Main", bg = C_BG, parent = gui })
    main.Visible = false

    -- ── TOP BAR: Search + Close ─────────────────────────────────────────
    local topBar = mkFrame({
        name   = "TopBar",
        size   = UDim2.new(1, -16, 0, 40),
        pos    = UDim2.new(0, 8, 0, 8),
        parent = main,
    })
    topBar.BackgroundTransparency = 1

    -- Search TextBox
    searchBox = Instance.new("TextBox")
    searchBox.Name               = "SearchBox"
    searchBox.Size               = UDim2.new(0.7, 0, 1, 0)
    searchBox.BackgroundColor3   = C_PANEL
    searchBox.TextColor3          = C_WHITE
    searchBox.PlaceholderText     = "Search name, type, rarity..."
    searchBox.PlaceholderColor3  = C_SEC
    searchBox.Font               = F_BODY
    searchBox.TextSize            = 16
    searchBox.BorderSizePixel    = 0
    searchBox.ClearTextOnFocus   = false
    searchBox.Parent             = topBar
    local sStroke = Instance.new("UIStroke")
    sStroke.Color     = C_SEC
    sStroke.Thickness = 1
    sStroke.Parent    = searchBox
    local sPad = Instance.new("UIPadding")
    sPad.PaddingLeft = UDim.new(0, 8)
    sPad.Parent      = searchBox

    -- X close button
    local closeBtn = mkBtn({
        name   = "CloseBtn",
        size   = UDim2.new(0, 40, 0, 40),
        pos    = UDim2.new(1, -40, 0, 0),
        text   = "X",
        tc     = C_WHITE,
        font   = F_HEAD,
        ts     = 24,
        bg     = C_PANEL,
        sc     = C_SEC,
        parent = topBar,
    })
    closeBtn.MouseButton1Click:Connect(function()
        closeInventory()
    end)

    -- ── TWO-COLUMN LAYOUT ──────────────────────────────────────────────
    local colFrame = mkFrame({
        name   = "Columns",
        size   = UDim2.new(1, -16, 1, -64),
        pos    = UDim2.new(0, 8, 0, 56),
        parent = main,
    })
    colFrame.BackgroundTransparency = 1

    -- ── LEFT COLUMN: Scrollable Grid ────────────────────────────────────
    local leftCol = mkFrame({
        name   = "LeftCol",
        size   = UDim2.new(0.48, 0, 1, 0),
        bg     = C_PANEL,
        stroke = C_SEC,
        pad    = 4,
        parent = colFrame,
    })

    gridScroll = Instance.new("ScrollingFrame")
    gridScroll.Name                 = "GridScroll"
    gridScroll.Size                 = UDim2.new(1, 0, 1, 0)
    gridScroll.BackgroundTransparency = 1
    gridScroll.BorderSizePixel       = 0
    gridScroll.ScrollBarThickness    = 8
    gridScroll.ScrollBarImageColor3  = C_SEC
    gridScroll.CanvasSize           = UDim2.new(0, 0, 0, 0)
    gridScroll.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    gridScroll.Parent               = leftCol

    gridLayout = Instance.new("UIGridLayout")
    gridLayout.CellSize       = UDim2.new(0, 96, 0, 96)
    gridLayout.CellPadding    = UDim2.new(0, 4, 0, 4)
    gridLayout.SortOrder      = Enum.SortOrder.LayoutOrder
    gridLayout.Parent         = gridScroll

    -- ── RIGHT COLUMN: Detail Panel ──────────────────────────────────────
    local rightCol = mkFrame({
        name   = "RightCol",
        size   = UDim2.new(0.48, -8, 1, 0),
        pos    = UDim2.new(0.52, 8, 0, 0),
        bg     = C_PANEL,
        stroke = C_SEC,
        pad    = 8,
        parent = colFrame,
    })

    detailPanel = rightCol

    -- Placeholder text when nothing selected
    placeholder = mkLabel({
        name   = "Placeholder",
        size   = UDim2.new(1, 0, 1, 0),
        text   = "SELECT A STUD",
        color  = C_SEC,
        font   = F_HEAD,
        ts     = 24,
        xa     = Enum.TextXAlignment.Center,
        parent = detailPanel,
    })

    -- Detail content (rebuilt on selection). A ScrollingFrame so the pane
    -- never overflows as rows accumulate (EXP bar, stats, moves, buttons):
    -- AutomaticCanvasSize grows the canvas to fit whatever showDetail lays out.
    detailContent = Instance.new("ScrollingFrame")
    detailContent.Name                 = "DetailContent"
    detailContent.Size                 = UDim2.new(1, 0, 1, 0)
    detailContent.BackgroundTransparency = 1
    detailContent.BorderSizePixel      = 0
    detailContent.ScrollBarThickness   = 6
    detailContent.ScrollBarImageColor3 = C_SEC
    detailContent.CanvasSize           = UDim2.new(0, 0, 0, 0)
    detailContent.AutomaticCanvasSize  = Enum.AutomaticSize.Y
    detailContent.Visible              = false
    detailContent.Parent               = detailPanel

    -- ── SEARCH HANDLER ─────────────────────────────────────────────────
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchQuery = searchBox.Text
        populateGrid()
    end)
end

-- ─── POPULATE GRID ──────────────────────────────────────────────────────

local function clearGrid()
    for _, child in ipairs(gridScroll:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextButton") then
            child:Destroy()
        end
    end
end

function populateGrid()
    clearGrid()
    filtered = {}

    -- Filter collection by search query
    local q = string.lower(searchQuery)
    for _, stud in ipairs(collection) do
        if q == "" then
            table.insert(filtered, stud)
        else
            local match = false
            if string.find(string.lower(stud.name or ""), q) then match = true end
            if string.find(string.lower(stud.studType or ""), q) then match = true end
            if string.find(string.lower(stud.rarity or ""), q) then match = true end
            if match then table.insert(filtered, stud) end
        end
    end

    -- Create tiles
    for i, stud in ipairs(filtered) do
        local tile = Instance.new("TextButton")
        tile.Name             = "Tile_" .. i
        tile.Size             = UDim2.new(0, 96, 0, 96)  -- matches grid cell
        tile.BackgroundColor3 = C_PANEL
        tile.Text             = ""
        tile.BorderSizePixel  = 0
        tile.AutoButtonColor  = false
        tile.Parent           = gridScroll
        tile.LayoutOrder      = i

        local tileStroke = Instance.new("UIStroke")
        tileStroke.Color     = RARITY_BORDER[stud.rarity] or C_SEC
        tileStroke.Thickness = 1
        tileStroke.Parent    = tile

        -- Rarity left border (thick left edge via a thin Frame)
        local leftBorder = Instance.new("Frame")
        leftBorder.Name             = "RarityBorder"
        leftBorder.Size             = UDim2.new(0, 4, 1, 0)
        leftBorder.BackgroundColor3 = RARITY_BORDER[stud.rarity] or C_SEC
        leftBorder.BorderSizePixel  = 0
        leftBorder.Parent           = tile

        -- Name label (nickname wins if this copy has one)
        mkLabel({
            name   = "NameLbl",
            size   = UDim2.new(1, -8, 0, 20),
            pos    = UDim2.new(0, 8, 0, 4),
            text   = stud.nickname or stud.name or "?",
            color  = C_WHITE,
            font   = F_BTN,
            ts     = 14,
            parent = tile,
        })

        -- Type badge
        mkTypeBadge(tile, stud.studType or "Fire", UDim2.new(0, 8, 0, 28), UDim2.new(0, 48, 0, 16))

        -- Level label (this copy's trained level)
        local level = stud.level or 1
        mkLabel({
            name   = "LvlLbl",
            size   = UDim2.new(0, 40, 0, 16),
            pos    = UDim2.new(1, -48, 0, 4),
            text   = "Lv" .. level,
            color  = C_SEC,
            font   = F_BODY,
            ts     = 12,
            xa     = Enum.TextXAlignment.Right,
            parent = tile,
        })

        -- Equipped indicator (small tag along the bottom of the tile)
        if equippedStudId and stud.id == equippedStudId then
            mkLabel({
                name   = "EquippedTag",
                size   = UDim2.new(1, -8, 0, 14),
                pos    = UDim2.new(0, 8, 1, -18),
                text   = "EQUIPPED",
                color  = C_ACCENT,
                font   = F_BTN,
                ts     = 10,
                parent = tile,
            })
        end

        -- Click handler
        tile.MouseButton1Click:Connect(function()
            selectedIdx = i
            showDetail(stud)
            -- Highlight selected tile
            for _, child in ipairs(gridScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    local s = child:FindFirstChildOfClass("UIStroke")
                    if s then
                        local idx = child.LayoutOrder
                        if filtered[idx] then
                            s.Color = RARITY_BORDER[filtered[idx].rarity] or C_SEC
                        end
                    end
                end
            end
            tileStroke.Color = C_ACCENT
        end)

        -- Hover effect
        tile.MouseEnter:Connect(function()
            tw(tile, {BackgroundColor3 = C_BTN_H})
        end)
        tile.MouseLeave:Connect(function()
            tw(tile, {BackgroundColor3 = C_PANEL})
        end)
    end
end

-- ─── DETAIL PANEL ───────────────────────────────────────────────────────

function showDetail(stud)
    -- Clear old detail content
    for _, child in ipairs(detailContent:GetChildren()) do
        child:Destroy()
    end

    placeholder.Visible  = false
    detailContent.Visible = true

    local y = 0  -- track Y position

    -- Large square icon placeholder (colored square with name initial)
    local tc = typeColor(stud.studType)
    local iconFrame = mkFrame({
        name   = "Icon",
        size   = UDim2.new(0, 80, 0, 80),
        pos    = UDim2.new(0.5, -40, 0, y),
        anchor = Vector2.new(0, 0),
        bg     = tc,
        stroke = tc,
        parent = detailContent,
    })
    mkLabel({
        name   = "IconInit",
        size   = UDim2.new(1, 0, 1, 0),
        text   = (stud.name or "?"):sub(1, 1):upper(),
        color  = C_BG,
        font   = F_HEAD,
        ts     = 40,
        xa     = Enum.TextXAlignment.Center,
        parent = iconFrame,
    })
    y = y + 88

    -- Full name (nickname first if this copy has one, species in parens)
    mkLabel({
        name   = "DName",
        size   = UDim2.new(1, 0, 0, 24),
        pos    = UDim2.new(0, 0, 0, y),
        text   = stud.nickname and (stud.nickname .. " (" .. (stud.name or "?") .. ")") or (stud.name or "?"),
        color  = C_WHITE,
        font   = F_HEAD,
        ts     = stud.nickname and 18 or 24,
        xa     = Enum.TextXAlignment.Center,
        parent = detailContent,
    })
    y = y + 28

    -- Type badge (centered)
    mkTypeBadge(detailContent, stud.studType or "Fire", UDim2.new(0.5, -28, 0, y), UDim2.new(0, 56, 0, 20))
    y = y + 24

    -- Rarity label
    mkLabel({
        name   = "DRarity",
        size   = UDim2.new(1, 0, 0, 20),
        pos    = UDim2.new(0, 0, 0, y),
        text   = stud.rarity or "Common",
        color  = rarityColor(stud.rarity),
        font   = F_BODY,
        ts     = 16,
        xa     = Enum.TextXAlignment.Center,
        parent = detailContent,
    })
    y = y + 28

    -- Level + nature (per-copy variance)
    local level = stud.level or 1
    local natureData = stud.nature and StudData.GetNature(stud.nature)
    mkLabel({
        name   = "DLevelNature",
        size   = UDim2.new(1, 0, 0, 18),
        pos    = UDim2.new(0, 0, 0, y),
        text   = "Lv" .. level .. (natureData and ("  ·  " .. natureData.name .. " nature") or ""),
        color  = C_SEC,
        font   = F_BODY,
        ts     = 14,
        xa     = Enum.TextXAlignment.Center,
        parent = detailContent,
    })
    y = y + 22

    -- EXP bar: progress toward next level (full golden bar at the cap)
    do
        local atCap = level >= StudData.MAX_LEVEL
        local needed = atCap and 1 or StudData.GetExpToLevel(level)
        local exp = atCap and 1 or math.clamp(stud.exp or 0, 0, needed)
        local expBg = mkFrame({
            name   = "DExpBar",
            size   = UDim2.new(0, 180, 0, 14),
            pos    = UDim2.new(0.5, -90, 0, y),
            bg     = C_BAR_BG,
            stroke = C_SEC,
            clip   = true,
            parent = detailContent,
        })
        mkFrame({
            name   = "Fill",
            size   = UDim2.new(exp / needed, 0, 1, 0),
            bg     = C_ACCENT,
            parent = expBg,
        })
        mkLabel({
            name   = "Txt",
            text   = atCap and "MAX LEVEL" or ("EXP " .. (stud.exp or 0) .. " / " .. needed),
            color  = C_WHITE,
            font   = F_BODY,
            ts     = 11,
            xa     = Enum.TextXAlignment.Center,
            stroke = C_BG,
            parent = expBg,
        })
        y = y + 20
    end

    -- 3-tile stat grid (HP, Damage, Price) — all scale with this copy's level
    local statW = 72
    local statGap = 8
    local statStartX = 0.5 - (statW * 3 + statGap * 2) / 2

    local studDataEntry = StudData.GetStudById(stud.id or "")
    local hp    = StudData.GetMaxHP(stud.rarity, level)
    local baseAtk = studDataEntry and studDataEntry.stats and studDataEntry.stats.attack or 0
    local dmg   = math.floor(baseAtk * StudData.GetLevelDamageMultiplier(level) + 0.5)

    -- The server always sells your LOWEST-level copy (so the trained one
    -- survives) — mirror that here so the quoted price matches what the sale
    -- actually pays, instead of quoting the selected copy's price.
    local sellEntry = nil
    local sellLowest = math.huge
    for _, c in ipairs(collection) do
        if c.id == stud.id then
            local lvl = c.level or 1
            if lvl < sellLowest then
                sellLowest = lvl
                sellEntry = c
            end
        end
    end
    local sellLevel = sellEntry and (sellEntry.level or 1) or level
    local price = StudData.GetSellValue(stud.id or "", sellLevel)
    if sellEntry and sellEntry.isShiny then
        price = price * 5
    end

    local stats = {
        { label = "HP",    value = tostring(hp) },
        { label = "DMG",   value = tostring(dmg) },
        { label = "PRICE", value = tostring(price) },
    }
    for si, s in ipairs(stats) do
        local sx = statStartX + (si - 1) * (statW + statGap)
        local sFrame = mkFrame({
            name   = "Stat" .. si,
            size   = UDim2.new(0, statW, 0, 48),
            pos    = UDim2.new(0, sx, 0, y),
            bg     = C_BAR_BG,
            stroke = C_SEC,
            parent = detailContent,
        })
        mkLabel({
            name   = "SLbl",
            size   = UDim2.new(1, 0, 0, 16),
            pos    = UDim2.new(0, 0, 0, 4),
            text   = s.label,
            color  = C_SEC,
            font   = F_BODY,
            ts     = 11,
            xa     = Enum.TextXAlignment.Center,
            parent = sFrame,
        })
        mkLabel({
            name   = "SVal",
            size   = UDim2.new(1, 0, 0, 20),
            pos    = UDim2.new(0, 0, 0, 20),
            text   = s.value,
            color  = C_ACCENT,
            font   = F_HEAD,
            ts     = 16,
            xa     = Enum.TextXAlignment.Center,
            parent = sFrame,
        })
    end
    y = y + 56

    -- 3 attack rows (name, type badge, power)
    mkLabel({
        name   = "MovesHdr",
        size   = UDim2.new(1, 0, 0, 16),
        pos    = UDim2.new(0, 0, 0, y),
        text   = "MOVES",
        color  = C_SEC,
        font   = F_BTN,
        ts     = 12,
        parent = detailContent,
    })
    y = y + 20

    local moves = StudData.GetMoves(stud) -- per-species kit (falls back to type default)
    for mi, move in ipairs(moves) do
        local unlocked = StudData.IsMoveUnlocked(move, level)
        local mRow = mkFrame({
            name   = "Move" .. mi,
            size   = UDim2.new(1, 0, 0, 24),
            pos    = UDim2.new(0, 0, 0, y),
            bg     = C_BAR_BG,
            stroke = C_BORDER,
            parent = detailContent,
        })
        mkLabel({
            name   = "MName",
            size   = UDim2.new(0.5, 0, 1, 0),
            pos    = UDim2.new(0, 4, 0, 0),
            text   = unlocked and move.name or ("🔒 " .. move.name),
            color  = unlocked and C_WHITE or C_SEC,
            font   = F_BODY,
            ts     = 13,
            parent = mRow,
        })
        mkTypeBadge(mRow, stud.studType, UDim2.new(0.5, 0, 0, 2), UDim2.new(0, 40, 0, 20))
        mkLabel({
            name   = "MPow",
            size   = UDim2.new(0, 70, 1, 0),
            pos    = UDim2.new(1, -74, 0, 0),
            text   = unlocked
                and (move.power .. "x" .. (move.accuracy and " · " .. math.floor(move.accuracy * 100 + 0.5) .. "%" or ""))
                or ("Lv" .. move.unlockLevel),
            color  = unlocked and C_ACCENT or C_SEC,
            font   = F_BODY,
            ts     = 13,
            xa     = Enum.TextXAlignment.Right,
            parent = mRow,
        })
        y = y + 28
    end
    y = y + 8

    -- EQUIP button (toggles equip/unequip for this stud)
    local isEquipped = equippedStudId ~= nil and stud.id == equippedStudId
    local equipBtn = mkBtn({
        name   = "EquipBtn",
        size   = UDim2.new(1, 0, 0, 36),
        pos    = UDim2.new(0, 0, 0, y),
        text   = isEquipped and "EQUIPPED" or "EQUIP",
        tc     = isEquipped and C_BG or C_WHITE,
        font   = F_BTN,
        ts     = 15,
        bg     = isEquipped and C_ACCENT or C_BTN_N,
        sc     = isEquipped and C_ACCENT or C_SEC,
        parent = detailContent,
    })
    y = y + 44

    equipBtn.MouseButton1Click:Connect(function()
        if isEquipped then return end -- already equipped, nothing to do
        setBtnDisabled(equipBtn, true)
        equipBtn.Text = "EQUIPPING..."
        local ok, result = pcall(function()
            return StudEvents.EquipStud:InvokeServer(stud.id)
        end)
        if ok and result and result.success then
            equippedStudId = stud.id
            -- Refresh grid (for the EQUIPPED tag) and re-render this detail panel
            populateGrid()
            showDetail(stud)
        else
            equipBtn.Text = "EQUIP FAILED"
            task.delay(1, function()
                setBtnDisabled(equipBtn, false)
                equipBtn.Text = "EQUIP"
            end)
        end
    end)

    -- ─── ABILITY (Rare/Legendary passive) ────────────────────────────────
    local ability = StudData.GetAbility(stud.id)
    if ability then
        mkLabel({
            size = UDim2.new(1, 0, 0, 20), pos = UDim2.new(0, 0, 0, y),
            text = "🧬 Ability · " .. ability.name, color = C_ACCENT,
            font = F_BTN, ts = 14, parent = detailContent,
        })
        y = y + 22
        local ad = mkLabel({
            size = UDim2.new(1, 0, 0, 32), pos = UDim2.new(0, 0, 0, y),
            text = ability.description, color = C_SEC, font = F_BODY, ts = 12,
            ya = Enum.TextYAlignment.Top, parent = detailContent,
        })
        ad.TextWrapped = true
        y = y + 36
    end

    -- ─── HELD ITEM slot (one permanent equip per species) ────────────────
    local equippedItemId = heldItems[stud.id]
    local equippedDef = equippedItemId and StudData.GetHeldItem(equippedItemId)
    mkLabel({
        size = UDim2.new(1, 0, 0, 20), pos = UDim2.new(0, 0, 0, y),
        text = "🎽 Held Item · " .. (equippedDef and (equippedDef.icon .. " " .. equippedDef.name) or "None"),
        color = C_WHITE, font = F_BTN, ts = 14, parent = detailContent,
    })
    y = y + 22
    if equippedDef then
        local hd = mkLabel({
            size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, y),
            text = equippedDef.description, color = C_SEC, font = F_BODY, ts = 12,
            ya = Enum.TextYAlignment.Top, parent = detailContent,
        })
        hd.TextWrapped = true
        y = y + 32
    end

    -- Applies the chosen item (or "" to unequip); the server returns the fresh
    -- heldItems/items maps, so we refresh those and re-render the panel.
    local function applyHeldItem(itemId, btn)
        setBtnDisabled(btn, true)
        local ok, result = pcall(function()
            return StudEvents.EquipHeldItem:InvokeServer(stud.id, itemId)
        end)
        if ok and result and result.success then
            heldItems = result.heldItems or heldItems
            ownedItems = result.items or ownedItems
            showDetail(stud)
        else
            setBtnDisabled(btn, false)
        end
    end

    -- Owned, unequipped items this species can legally hold (respects typeLock)
    local equippable = {}
    for itemId, count in pairs(ownedItems) do
        if count > 0 and StudData.GetHeldItem(itemId)
            and StudData.CanEquipHeldItem(itemId, stud.studType)
            and itemId ~= equippedItemId
        then
            table.insert(equippable, itemId)
        end
    end
    table.sort(equippable)

    for _, itemId in ipairs(equippable) do
        local def = StudData.GetHeldItem(itemId)
        local eb = mkBtn({
            size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, y),
            text = "Equip " .. def.icon .. " " .. def.name .. " (x" .. ownedItems[itemId] .. ")",
            tc = C_WHITE, font = F_BODY, ts = 12, bg = C_BTN_N, sc = C_SEC, parent = detailContent,
        })
        y = y + 34
        eb.MouseButton1Click:Connect(function() applyHeldItem(itemId, eb) end)
    end

    if equippedDef then
        local ub = mkBtn({
            size = UDim2.new(1, 0, 0, 30), pos = UDim2.new(0, 0, 0, y),
            text = "✖ Unequip " .. equippedDef.name, tc = C_WHITE, font = F_BODY,
            ts = 12, bg = C_BTN_N, sc = C_SEC, parent = detailContent,
        })
        y = y + 34
        ub.MouseButton1Click:Connect(function() applyHeldItem("", ub) end)
    end

    if not equippedDef and #equippable == 0 then
        local hint = mkLabel({
            size = UDim2.new(1, 0, 0, 28), pos = UDim2.new(0, 0, 0, y),
            text = "Buy held items at the Shop — some are exclusive to specific islands.",
            color = C_SEC, font = F_BODY, ts = 11, ya = Enum.TextYAlignment.Top, parent = detailContent,
        })
        hint.TextWrapped = true
        y = y + 30
    end
    y = y + 8

    -- RENAME row: nickname this species' best (highest-level) copy.
    -- The server filters the text and returns the renamed copy's caughtAt.
    local renameBox = Instance.new("TextBox")
    renameBox.Name = "RenameBox"
    renameBox.Size = UDim2.new(0.62, 0, 0, 32)
    renameBox.Position = UDim2.new(0, 0, 0, y)
    renameBox.BackgroundColor3 = C_BAR_BG
    renameBox.TextColor3 = C_WHITE
    renameBox.PlaceholderColor3 = C_SEC
    renameBox.PlaceholderText = stud.nickname and "Rename (blank clears)" or "Nickname..."
    renameBox.Text = ""
    renameBox.ClearTextOnFocus = false
    renameBox.TextSize = 13
    renameBox.Font = F_BODY
    renameBox.BorderSizePixel = 0
    renameBox.Parent = detailContent

    local renameBtn = mkBtn({
        name   = "RenameBtn",
        size   = UDim2.new(0.35, 0, 0, 32),
        pos    = UDim2.new(0.65, 0, 0, y),
        text   = "✏️ NAME",
        tc     = C_WHITE,
        font   = F_BTN,
        ts     = 13,
        bg     = C_BTN_N,
        sc     = C_SEC,
        parent = detailContent,
    })
    y = y + 40

    renameBtn.MouseButton1Click:Connect(function()
        setBtnDisabled(renameBtn, true)
        local ok, result = pcall(function()
            return StudEvents.RenameStud:InvokeServer(stud.id, renameBox.Text)
        end)
        setBtnDisabled(renameBtn, false)
        if ok and result and result.success then
            -- Update the exact copy the server renamed (entries share table
            -- refs with the detail view, so `stud` updates too if it's the one)
            for _, c in ipairs(collection) do
                if c.id == stud.id and c.caughtAt == result.caughtAt then
                    c.nickname = result.nickname
                end
            end
            populateGrid()
            showDetail(stud)
        else
            renameBox.Text = ""
            renameBox.PlaceholderText = "Name rejected"
        end
    end)

    -- SELL button (square, yellow). Names the copy that actually sells —
    -- the server picks the lowest-level duplicate, not the selected one.
    local sellText = "SELL Lv" .. sellLevel .. (sellEntry and sellEntry.isShiny and " ✨" or "") .. " FOR " .. price .. " COINS"
    local sellBtn = mkBtn({
        name   = "SellBtn",
        size   = UDim2.new(1, 0, 0, 40),
        pos    = UDim2.new(0, 0, 0, y),
        text   = sellText,
        tc     = C_BG,
        font   = F_BTN,
        ts     = 16,
        bg     = C_ACCENT,
        sc     = C_ACCENT,
        parent = detailContent,
    })

    sellBtn.MouseButton1Click:Connect(function()
        setBtnDisabled(sellBtn, true)
        sellBtn.Text = "SELLING..."
        local ok = pcall(function()
            StudEvents.SellStud:FireServer(stud.id)
        end)
        if ok then
            sellBtn.Text = "SOLD!"
            if equippedStudId == stud.id then
                equippedStudId = nil
            end
            -- Refresh inventory after short delay
            task.delay(0.5, function()
                requestCollection()
            end)
        else
            sellBtn.Text = "SELL FAILED"
            task.delay(1, function()
                setBtnDisabled(sellBtn, false)
                sellBtn.Text = sellText
            end)
        end
    end)
end

-- ─── REQUEST COLLECTION FROM SERVER ──────────────────────────────────────

function requestCollection()
    local ok, data, equippedId, heldMap, itemsMap = pcall(function()
        return StudEvents.RequestCollection:InvokeServer()
    end)
    -- pcall's first return is success; RequestCollection itself returns
    -- (caughtStuds, equippedStudId, heldItems, items), so re-unpack from the
    -- pcall results.
    if ok and data then
        equippedStudId = equippedId
        heldItems = heldMap or {}
        ownedItems = itemsMap or {}
        collection = {}
        for _, entry in ipairs(data) do
            -- Enrich with StudData
            local base = StudData.GetStudById(entry.id or "")
            if base then
                table.insert(collection, {
                    id       = base.id,
                    name     = base.name,
                    nickname = entry.nickname,
                    studType = base.studType,
                    rarity   = base.rarity,
                    isShiny  = entry.isShiny or false,
                    caughtAt = entry.caughtAt,
                    level    = entry.level or 1,
                    exp      = entry.exp or 0,
                    nature   = entry.nature,
                })
            end
        end
        populateGrid()
    end
end

-- ─── OPEN / CLOSE ──────────────────────────────────────────────────────

local function openInventory()
    if isOpen then return end
    isOpen = true
    selectedIdx = nil
    searchQuery = ""
    searchBox.Text = ""
    placeholder.Visible  = true
    detailContent.Visible = false

    -- Clear old detail
    for _, child in ipairs(detailContent:GetChildren()) do
        child:Destroy()
    end

    -- Show UI immediately so the player sees feedback
    main.Visible = true
    setOtherGuisHidden(true)  -- hide HUD, Coins, Quest/Settings/Stats buttons, etc.
    lockWalk()

    -- Fetch collection asynchronously so the UI appears instantly
    task.spawn(requestCollection)
end

function closeInventory()
    if not isOpen then return end
    isOpen = false
    main.Visible = false
    setOtherGuisHidden(false)
    unlockWalk()

    -- BUGFIX: if the search box still had keyboard focus when the player
    -- closed the inventory (Escape / E / X button), UserInputService:
    -- GetFocusedTextBox() kept returning it even after main.Visible was
    -- set to false. The E-key handler below bails out whenever a text
    -- box is focused, so this permanently blocked the "E" hotkey from
    -- ever reopening the inventory again for the rest of the session.
    -- Releasing focus here guarantees the hotkey keeps working.
    if searchBox and searchBox:IsFocused() then
        searchBox:ReleaseFocus()
    end
end

UIManager.Register("OpenInventory", openInventory)
UIManager.Register("CloseInventory", closeInventory)

-- ─── KEYBOARD SHORTCUTS ────────────────────────────────────────────────
UserInputService.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == Enum.KeyCode.Escape then
        if gpe then return end
        if isOpen then
            closeInventory()
        end
    elseif input.KeyCode == Enum.KeyCode.E then
        -- Never react while typing in a TextBox (search bar, chat, etc.)
        if UserInputService:GetFocusedTextBox() then return end
        -- NOTE: deliberately NOT bailing on `gpe` here. ProximityPrompts
        -- (NPCs, shops, the fountain, etc.) default to the E key and mark
        -- the input as "game processed" whenever one is in range, which
        -- was silently eating the inventory hotkey. The inventory toggle
        -- should always win regardless of nearby prompts.
        if isOpen then
            closeInventory()
        elseif UIManager.GetLockCount() == 0 and player:GetAttribute("GameStarted") then
            -- GameStarted gate: don't pop the inventory over the save/load menu
            openInventory()
        end
    end
end)

-- ─── LISTEN FOR COIN UPDATES (refresh inventory) ──────────────────────
if StudEvents:FindFirstChild("UpdateCoins") then
    StudEvents.UpdateCoins.OnClientEvent:Connect(function()
        if isOpen then requestCollection() end
    end)
end

-- ─── INIT ───────────────────────────────────────────────────────────────
buildUI()