--[[
    NotificationUI.lua — Toast Notification System for Stud Catcher
    Retro pixel-art style · Instance.new() only · No UICorner · No external assets

    Usage:  _G.Notify(type, title, subtitle)
            type = "success" | "warning" | "info" | "fail"

    Banners slide in from top-right, stack vertically, auto-dismiss after 3s with fade.
    Border colour by type: success=green, warning=yellow, info=blue, fail=red.
]]

-- ─── SERVICES ──────────────────────────────────────────────────────────────
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UIManager          = require(ReplicatedStorage:WaitForChild("UIManager"))

-- ─── REFERENCES ──────────────────────────────────────────────────────────
local player     = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData   = require(ReplicatedStorage:WaitForChild("StudData"))

-- ─── PALETTE ─────────────────────────────────────────────────────────────
local C_BG        = Color3.fromRGB(18, 20, 28)
local C_PANEL     = Color3.fromRGB(28, 31, 42)
local C_ACCENT    = Color3.fromRGB(255, 220, 60)
local C_WHITE     = Color3.fromRGB(255, 255, 255)
local C_SEC       = Color3.fromRGB(140, 140, 160)

-- Notification type colours
local TYPE_COLORS = {
    success = Color3.fromRGB(50, 200, 50),
    warning = Color3.fromRGB(255, 220, 60),
    info    = Color3.fromRGB(50, 100, 255),
    fail    = Color3.fromRGB(230, 60, 40),
}

-- Notification type icons (text characters)
local TYPE_ICONS = {
    success = "+",
    warning = "!",
    info    = "i",
    fail    = "x",
}

-- ─── FONTS ───────────────────────────────────────────────────────────────
local F_HEAD = Enum.Font.Code
local F_BODY = Enum.Font.RobotoMono

-- ─── STATE ───────────────────────────────────────────────────────────────
local gui
local container       -- Frame that holds all banners (top-right anchored)
local notifications   = {}  -- active notification frames
local MAX_NOTIFICATIONS = 5
local DISMISS_TIME     = 3   -- seconds
local BANNER_W         = 240
local BANNER_H         = 46
local BANNER_GAP       = 6

-- ─── HELPERS ─────────────────────────────────────────────────────────────
local function tw(obj, props, dur)
    dur = dur or 0.15
    TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Linear), props):Play()
end

local function typeColor(nType)
    return TYPE_COLORS[nType] or TYPE_COLORS.info
end

local function typeIcon(nType)
    return TYPE_ICONS[nType] or "i"
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

-- ─── BUILD CONTAINER ────────────────────────────────────────────────────
local function buildUI()
    gui = Instance.new("ScreenGui")
    gui.Name           = "NotificationUI"
    gui.ResetOnSpawn   = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent         = player:WaitForChild("PlayerGui")

    -- Container anchored top-right
    container = mkFrame({
        name   = "Container",
        size   = UDim2.new(0, BANNER_W + 16, 1, 0),
        pos    = UDim2.new(1, -(BANNER_W + 16), 0, 0),
        parent = gui,
    })
    container.BackgroundTransparency = 1

    -- Vertical list layout for stacking
    local layout = Instance.new("UIListLayout")
    layout.FillDirection      = Enum.FillDirection.Vertical
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment  = Enum.VerticalAlignment.Top
    layout.Padding            = UDim.new(0, BANNER_GAP)
    layout.SortOrder          = Enum.SortOrder.LayoutOrder
    layout.Parent             = container

    -- Top padding
    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 8)
    pad.Parent     = container
end

-- ─── REPOSITION NOTIFICATIONS ───────────────────────────────────────────
-- After a notification is removed, remaining ones slide up
local function reposition()
    local children = {}
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("Frame") and child.Name:find("Notif_") then
            table.insert(children, child)
        end
    end
    table.sort(children, function(a, b)
        return a.LayoutOrder < b.LayoutOrder
    end)
    for i, child in ipairs(children) do
        child.LayoutOrder = i
    end
end

-- ─── SHOW NOTIFICATION ──────────────────────────────────────────────────
local notifCounter = 0

local function showNotification(nType, title, subtitle)
    notifCounter = notifCounter + 1
    local id    = notifCounter
    local color = typeColor(nType)
    local icon  = typeIcon(nType)

    -- Banner: soft translucent pill — no border box, no icon square. A small
    -- coloured dot carries the type; text gets a faint shadow so it floats
    -- over the world instead of sitting in a window.
    local banner = mkFrame({
        name   = "Notif_" .. id,
        size   = UDim2.new(0, BANNER_W, 0, BANNER_H),
        bg     = C_BG,
        parent = container,
    })
    banner.LayoutOrder = id
    banner.BackgroundTransparency = 0.35
    local pill = Instance.new("UICorner")
    pill.CornerRadius = UDim.new(1, 0)
    pill.Parent = banner

    -- Start off-screen right, then slide in
    banner.Position = UDim2.new(1, 0, 0, 0)
    tw(banner, { Position = UDim2.new(0, 0, 0, 0) }, 0.2)

    -- Type dot
    local dot = mkFrame({
        name   = "Dot",
        size   = UDim2.new(0, 10, 0, 10),
        pos    = UDim2.new(0, 16, 0.5, -5),
        bg     = color,
        parent = banner,
    })
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = dot

    -- Title (bold)
    local titleLbl = mkLabel({
        name   = "Title",
        size   = UDim2.new(1, -50, 0, 20),
        pos    = UDim2.new(0, 36, 0, subtitle and subtitle ~= "" and 4 or 0),
        text   = title or "Notification",
        color  = C_WHITE,
        font   = Enum.Font.GothamBold,
        ts     = 14,
        parent = banner,
    })
    if not (subtitle and subtitle ~= "") then
        titleLbl.Size = UDim2.new(1, -50, 1, 0)
    end
    titleLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
    titleLbl.TextStrokeTransparency = 0.8

    -- Subtitle
    if subtitle and subtitle ~= "" then
        local subLbl = mkLabel({
            name   = "Subtitle",
            size   = UDim2.new(1, -50, 0, 16),
            pos    = UDim2.new(0, 36, 0, 24),
            text   = subtitle,
            color  = C_SEC,
            font   = Enum.Font.Gotham,
            ts     = 12,
            parent = banner,
        })
        subLbl.TextStrokeColor3 = Color3.new(0, 0, 0)
        subLbl.TextStrokeTransparency = 0.85
    end

    -- Track notification
    table.insert(notifications, banner)

    -- Limit max notifications — remove oldest if over limit
    while #notifications > MAX_NOTIFICATIONS do
        local oldest = table.remove(notifications, 1)
        if oldest and oldest.Parent then
            oldest.Parent = nil
        end
    end

    -- Auto-dismiss after DISMISS_TIME seconds
    task.delay(DISMISS_TIME, function()
        if banner.Parent == nil then return end
        -- Fade out
        tw(banner, { BackgroundTransparency = 1 }, 0.2)
        for _, desc in ipairs(banner:GetDescendants()) do
            if desc:IsA("TextLabel") then
                tw(desc, { TextTransparency = 1, TextStrokeTransparency = 1 }, 0.2)
            elseif desc:IsA("Frame") and desc.Name ~= "Notif_" .. id then
                tw(desc, { BackgroundTransparency = 1 }, 0.2)
            end
            if desc:IsA("UIStroke") then
                tw(desc, { Transparency = 1 }, 0.2)
            end
        end
        task.delay(0.25, function()
            if banner.Parent then
                banner.Parent = nil
            end
            -- Remove from tracking
            for i, n in ipairs(notifications) do
                if n == banner then
                    table.remove(notifications, i)
                    break
                end
            end
            reposition()
        end)
    end)
end

-- ─── GLOBAL NOTIFY FUNCTION ────────────────────────────────────────────
UIManager.Register("Notify", showNotification)

-- ─── EVENT LISTENERS ──────────────────────────────────────────────────

-- Catch success notification (CatchSuccess is a RemoteEvent fired by server after catch)
if StudEvents:FindFirstChild("CatchSuccess") and StudEvents.CatchSuccess:IsA("RemoteEvent") then
    StudEvents.CatchSuccess.OnClientEvent:Connect(function(studId)
        local stud = StudData.GetStudById(studId)
        if stud then
            showNotification("success", "Caught " .. stud.name .. "!", stud.rarity .. " " .. stud.studType .. " type")
        else
            showNotification("success", "Stud Caught!", "")
        end
    end)
end

-- Evolution result notification (guard against RemoteFunction type)
if StudEvents:FindFirstChild("EvolutionResult") and StudEvents.EvolutionResult:IsA("RemoteEvent") then
    StudEvents.EvolutionResult.OnClientEvent:Connect(function(data)
        if data and data.studName then
            showNotification("warning", "Evolution!", data.studName .. " has evolved!")
        else
            showNotification("warning", "Evolution!", "A stud has evolved!")
        end
    end)
end

-- NOTE: no toast for UpdateCoins — the HUD coin pill (GameHUD) already
-- reflects every balance change live, and a "Coins Updated" banner on top of
-- every catch/sell/quest reward doubled up the notification noise.

-- Encounter result (other player rare sighting)
if StudEvents:FindFirstChild("EncounterResult") then
    StudEvents.EncounterResult.OnClientEvent:Connect(function(data)
        if data and data.rarity and (data.rarity == "Rare" or data.rarity == "Legendary") then
            showNotification("warning", "Rare Sighting!", (data.playerName or "Someone") .. " found a " .. (data.studName or "rare stud"))
        end
    end)
end

-- ─── INIT ───────────────────────────────────────────────────────────────
buildUI()