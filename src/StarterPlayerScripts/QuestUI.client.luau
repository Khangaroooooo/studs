local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local studEvents = ReplicatedStorage:WaitForChild("StudEvents")
local questRequest = studEvents:WaitForChild("QuestRequest")
local questAction = studEvents:WaitForChild("QuestAction")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

-- Colors
local BG_COLOR = Color3.fromRGB(25, 25, 35)
local HEADER_COLOR = Color3.fromRGB(40, 40, 55)
local ACTIVE_COLOR = Color3.fromRGB(50, 120, 80)
local AVAILABLE_COLOR = Color3.fromRGB(50, 80, 140)
local COMPLETED_COLOR = Color3.fromRGB(80, 80, 80)
local PROGRESS_BG = Color3.fromRGB(30, 30, 40)
local PROGRESS_FILL = Color3.fromRGB(80, 200, 120)
local TEXT_COLOR = Color3.fromRGB(230, 230, 230)
local GOLD = Color3.fromRGB(255, 200, 50)
local ACCENT = Color3.fromRGB(100, 180, 255)

-- State
local questData = nil
local isOpen = false

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- IMPORTANT: no IgnoreGuiInset. The rest of the HUD rail (coins pill, gear,
-- leaderboard) lays out in inset space — this gui ignoring the ~58px topbar
-- inset is what made the coins pill overlap the Quest button and opened a
-- fake gap between Quest and Settings.
screenGui.IgnoreGuiInset = false
screenGui.Parent = playerGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 380, 0, 500)
mainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
mainFrame.BackgroundColor3 = BG_COLOR
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui



local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(80, 80, 100)
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = HEADER_COLOR
header.BorderSizePixel = 0
header.Parent = mainFrame



-- Fix bottom corners of header
local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = HEADER_COLOR
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Text = "📜 Quests"
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = GOLD
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header



-- Tab buttons
local tabFrame = Instance.new("Frame")
tabFrame.Name = "TabFrame"
tabFrame.Size = UDim2.new(1, -16, 0, 36)
tabFrame.Position = UDim2.new(0, 8, 0, 56)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = mainFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabFrame

local tabs = {"Daily", "Active", "Available", "Completed"}
local tabButtons = {}
local currentTab = "Daily"

for i, tabName in ipairs(tabs) do
    local btn = Instance.new("TextButton")
    btn.Name = tabName
    btn.Size = UDim2.new(0.24, 0, 1, 0)
    btn.BackgroundColor3 = (tabName == currentTab) and ACCENT or Color3.fromRGB(50, 50, 65)
    btn.TextColor3 = TEXT_COLOR
    btn.TextSize = 12
    btn.Font = Enum.Font.GothamBold
    btn.Text = tabName
    btn.BorderSizePixel = 0
    btn.LayoutOrder = i
    btn.Parent = tabFrame



    tabButtons[tabName] = btn

    btn.MouseButton1Click:Connect(function()
        currentTab = tabName
        for name, b in pairs(tabButtons) do
            b.BackgroundColor3 = (name == tabName) and ACCENT or Color3.fromRGB(50, 50, 65)
        end
        refreshContent()
    end)
end

-- Scroll content area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ContentScroll"
scrollFrame.Size = UDim2.new(1, -16, 1, -104)
scrollFrame.Position = UDim2.new(0, 8, 0, 96)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = ACCENT
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = scrollFrame

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 4)
contentPadding.PaddingBottom = UDim.new(0, 4)
contentPadding.Parent = scrollFrame

-- HUD quest tracker (always visible mini display)
local trackerFrame = Instance.new("Frame")
trackerFrame.Name = "QuestTracker"
trackerFrame.Size = UDim2.new(0, 240, 0, 20)
trackerFrame.Position = UDim2.new(0, 12, 0, 80)
trackerFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
trackerFrame.BackgroundTransparency = 0.3
trackerFrame.BorderSizePixel = 0
trackerFrame.Visible = false
trackerFrame.Parent = screenGui



local trackerStroke = Instance.new("UIStroke")
trackerStroke.Color = Color3.fromRGB(80, 80, 100)
trackerStroke.Thickness = 1
trackerStroke.Transparency = 0.5
trackerStroke.Parent = trackerFrame

local trackerLayout = Instance.new("UIListLayout")
trackerLayout.Padding = UDim.new(0, 2)
trackerLayout.SortOrder = Enum.SortOrder.LayoutOrder
trackerLayout.Parent = trackerFrame

-- Toggle button on HUD — sits in the top-right rail, directly below the
-- coins pill (GameHUD) and above the Settings gear (SettingsMenu).
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "QuestToggle"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(1, -56, 0, 60)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
toggleBtn.BackgroundTransparency = 0.25
toggleBtn.TextColor3 = GOLD
toggleBtn.TextSize = 22
toggleBtn.Text = "📜"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleBtn



local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(80, 80, 100)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = toggleBtn

-- Notification frame for quest completion. Hidden (Visible=false) while
-- parked: this gui respects the topbar inset, so a frame "hidden" at y=-80
-- still had its bottom half poking out under the top edge of the screen.
local notifFrame = Instance.new("Frame")
notifFrame.Name = "QuestNotification"
notifFrame.Size = UDim2.new(0, 320, 0, 64)
notifFrame.Position = UDim2.new(0.5, -160, 0, -120)
notifFrame.BackgroundColor3 = Color3.fromRGB(15, 25, 20)
notifFrame.BackgroundTransparency = 0.3
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
notifFrame.Parent = screenGui

local notifCorner = Instance.new("UICorner")
notifCorner.CornerRadius = UDim.new(0, 16)
notifCorner.Parent = notifFrame

local notifLabel = Instance.new("TextLabel")
notifLabel.Size = UDim2.new(1, -32, 0, 26)
notifLabel.Position = UDim2.new(0, 16, 0, 8)
notifLabel.BackgroundTransparency = 1
notifLabel.TextColor3 = GOLD
notifLabel.TextSize = 16
notifLabel.Font = Enum.Font.GothamBold
notifLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
notifLabel.TextStrokeTransparency = 0.8
notifLabel.Text = "Quest Complete!"
notifLabel.TextXAlignment = Enum.TextXAlignment.Left
notifLabel.Parent = notifFrame

local notifDetail = Instance.new("TextLabel")
notifDetail.Size = UDim2.new(1, -32, 0, 18)
notifDetail.Position = UDim2.new(0, 16, 0, 34)
notifDetail.BackgroundTransparency = 1
notifDetail.TextColor3 = TEXT_COLOR
notifDetail.TextSize = 13
notifDetail.Font = Enum.Font.Gotham
notifDetail.TextStrokeColor3 = Color3.new(0, 0, 0)
notifDetail.TextStrokeTransparency = 0.85
notifDetail.Text = ""
notifDetail.TextXAlignment = Enum.TextXAlignment.Left
notifDetail.Parent = notifFrame

-- Helper: create quest card
local function createActiveCard(quest, order)
    local card = Instance.new("Frame")
    card.Name = quest.id
    card.Size = UDim2.new(1, 0, 0, 90)
    card.BackgroundColor3 = ACTIVE_COLOR
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = scrollFrame


    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -16, 0, 22)
    nameLbl.Position = UDim2.new(0, 8, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = TEXT_COLOR
    nameLbl.TextSize = 14
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = quest.name
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -16, 0, 18)
    descLbl.Position = UDim2.new(0, 8, 0, 26)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = Color3.fromRGB(180, 180, 180)
    descLbl.TextSize = 11
    descLbl.Font = Enum.Font.Gotham
    descLbl.Text = quest.description or ""
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = card

    -- Progress bar
    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, -16, 0, 14)
    progressBg.Position = UDim2.new(0, 8, 0, 48)
    progressBg.BackgroundColor3 = PROGRESS_BG
    progressBg.BorderSizePixel = 0
    progressBg.Parent = card



    local progress = quest.progress or 0
    local target = quest.target or 1
    local ratio = math.clamp(progress / target, 0, 1)

    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(ratio, 0, 1, 0)
    progressFill.BackgroundColor3 = PROGRESS_FILL
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg



    local progressLbl = Instance.new("TextLabel")
    progressLbl.Size = UDim2.new(1, 0, 1, 0)
    progressLbl.BackgroundTransparency = 1
    progressLbl.TextColor3 = TEXT_COLOR
    progressLbl.TextSize = 10
    progressLbl.Font = Enum.Font.GothamBold
    progressLbl.Text = progress .. "/" .. target
    progressLbl.Parent = progressBg

    -- Reward label
    local rewardLbl = Instance.new("TextLabel")
    rewardLbl.Size = UDim2.new(0.5, -8, 0, 18)
    rewardLbl.Position = UDim2.new(0, 8, 0, 68)
    rewardLbl.BackgroundTransparency = 1
    rewardLbl.TextColor3 = GOLD
    rewardLbl.TextSize = 12
    rewardLbl.Font = Enum.Font.GothamBold
    rewardLbl.Text = "💰 " .. quest.reward .. " coins"
    rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
    rewardLbl.Parent = card

    -- NPC label
    local npcLbl = Instance.new("TextLabel")
    npcLbl.Size = UDim2.new(0.5, -8, 0, 18)
    npcLbl.Position = UDim2.new(0.5, 0, 0, 68)
    npcLbl.BackgroundTransparency = 1
    npcLbl.TextColor3 = Color3.fromRGB(160, 160, 180)
    npcLbl.TextSize = 11
    npcLbl.Font = Enum.Font.Gotham
    npcLbl.Text = "From: " .. (quest.npc or "?")
    npcLbl.TextXAlignment = Enum.TextXAlignment.Right
    npcLbl.Parent = card

    return card
end

local function createAvailableCard(quest, order)
    local card = Instance.new("Frame")
    card.Name = quest.id
    card.Size = UDim2.new(1, 0, 0, 80)
    card.BackgroundColor3 = AVAILABLE_COLOR
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = scrollFrame


    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -16, 0, 22)
    nameLbl.Position = UDim2.new(0, 8, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = TEXT_COLOR
    nameLbl.TextSize = 14
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = quest.name
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -16, 0, 18)
    descLbl.Position = UDim2.new(0, 8, 0, 26)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = Color3.fromRGB(180, 180, 200)
    descLbl.TextSize = 11
    descLbl.Font = Enum.Font.Gotham
    descLbl.Text = quest.description or ""
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = card

    -- Reward
    local rewardLbl = Instance.new("TextLabel")
    rewardLbl.Size = UDim2.new(0.4, -8, 0, 18)
    rewardLbl.Position = UDim2.new(0, 8, 0, 50)
    rewardLbl.BackgroundTransparency = 1
    rewardLbl.TextColor3 = GOLD
    rewardLbl.TextSize = 12
    rewardLbl.Font = Enum.Font.GothamBold
    rewardLbl.Text = "💰 " .. quest.reward .. " coins"
    rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
    rewardLbl.Parent = card

    -- Accept button
    local acceptBtn = Instance.new("TextButton")
    acceptBtn.Size = UDim2.new(0, 80, 0, 28)
    acceptBtn.Position = UDim2.new(1, -90, 0, 46)
    acceptBtn.BackgroundColor3 = Color3.fromRGB(60, 160, 80)
    acceptBtn.TextColor3 = TEXT_COLOR
    acceptBtn.TextSize = 13
    acceptBtn.Font = Enum.Font.GothamBold
    acceptBtn.Text = "Accept"
    acceptBtn.BorderSizePixel = 0
    acceptBtn.Parent = card



    acceptBtn.MouseButton1Click:Connect(function()
        questAction:FireServer({ action = "accept", questId = quest.id })
        acceptBtn.Text = "..."
        acceptBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        task.wait(0.5)
        fetchQuestData()
    end)

    return card
end

local function createCompletedCard(quest, order)
    -- Server sends {id, name}; tolerate plain-id entries from older saves
    local questId = type(quest) == "table" and quest.id or quest
    local questName = type(quest) == "table" and quest.name or quest

    local card = Instance.new("Frame")
    card.Name = questId
    card.Size = UDim2.new(1, 0, 0, 40)
    card.BackgroundColor3 = COMPLETED_COLOR
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = scrollFrame



    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -40, 1, 0)
    lbl.Position = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3 = Color3.fromRGB(160, 160, 160)
    lbl.TextSize = 12
    lbl.Font = Enum.Font.Gotham
    lbl.Text = "✅ " .. questName
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.Parent = card

    return card
end

-- Clear scroll content
local function clearContent()
    -- GuiObject covers Frames AND the TextLabel empty-states/headers
    -- (UIListLayout/UIPadding aren't GuiObjects, so they survive)
    for _, child in ipairs(scrollFrame:GetChildren()) do
        if child:IsA("GuiObject") then
            child:Destroy()
        end
    end
end

-- Daily quest card (no accept button — dailies are always running)
local function createDailyCard(quest, order)
    local card = Instance.new("Frame")
    card.Name = "Daily_" .. order
    card.Size = UDim2.new(1, 0, 0, 84)
    card.BackgroundColor3 = quest.done and COMPLETED_COLOR or Color3.fromRGB(90, 70, 30)
    card.BorderSizePixel = 0
    card.LayoutOrder = order
    card.Parent = scrollFrame

    local nameLbl = Instance.new("TextLabel")
    nameLbl.Size = UDim2.new(1, -16, 0, 22)
    nameLbl.Position = UDim2.new(0, 8, 0, 6)
    nameLbl.BackgroundTransparency = 1
    nameLbl.TextColor3 = quest.done and Color3.fromRGB(190, 190, 190) or GOLD
    nameLbl.TextSize = 14
    nameLbl.Font = Enum.Font.GothamBold
    nameLbl.Text = (quest.done and "✅ " or "") .. quest.name
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
    nameLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Size = UDim2.new(1, -16, 0, 18)
    descLbl.Position = UDim2.new(0, 8, 0, 26)
    descLbl.BackgroundTransparency = 1
    descLbl.TextColor3 = Color3.fromRGB(200, 195, 180)
    descLbl.TextSize = 11
    descLbl.Font = Enum.Font.Gotham
    descLbl.Text = quest.desc or ""
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextTruncate = Enum.TextTruncate.AtEnd
    descLbl.Parent = card

    local progressBg = Instance.new("Frame")
    progressBg.Size = UDim2.new(1, -16, 0, 14)
    progressBg.Position = UDim2.new(0, 8, 0, 46)
    progressBg.BackgroundColor3 = PROGRESS_BG
    progressBg.BorderSizePixel = 0
    progressBg.Parent = card

    local progress = quest.progress or 0
    local target = quest.target or 1
    local progressFill = Instance.new("Frame")
    progressFill.Size = UDim2.new(math.clamp(progress / target, 0, 1), 0, 1, 0)
    progressFill.BackgroundColor3 = quest.done and Color3.fromRGB(120, 120, 120) or PROGRESS_FILL
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg

    local progressLbl = Instance.new("TextLabel")
    progressLbl.Size = UDim2.new(1, 0, 1, 0)
    progressLbl.BackgroundTransparency = 1
    progressLbl.TextColor3 = TEXT_COLOR
    progressLbl.TextSize = 10
    progressLbl.Font = Enum.Font.GothamBold
    progressLbl.Text = math.min(progress, target) .. "/" .. target
    progressLbl.Parent = progressBg

    local rewardLbl = Instance.new("TextLabel")
    rewardLbl.Size = UDim2.new(1, -16, 0, 18)
    rewardLbl.Position = UDim2.new(0, 8, 0, 62)
    rewardLbl.BackgroundTransparency = 1
    rewardLbl.TextColor3 = GOLD
    rewardLbl.TextSize = 12
    rewardLbl.Font = Enum.Font.GothamBold
    rewardLbl.Text = "💰 " .. (quest.reward or 0) .. " coins"
    rewardLbl.TextXAlignment = Enum.TextXAlignment.Left
    rewardLbl.Parent = card

    return card
end

-- Refresh content based on current tab
function refreshContent()
    clearContent()
    if not questData then return end

    if currentTab == "Daily" then
        local daily = questData.daily
        if not daily or #(daily.quests or {}) == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 60)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
            emptyLbl.TextSize = 14
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.Text = "Daily quests unlock\nonce your game loads!"
            emptyLbl.Parent = scrollFrame
        else
            -- Header: reset countdown + bonus status
            local hours = math.floor((daily.resetsIn or 0) / 3600)
            local mins = math.floor(((daily.resetsIn or 0) % 3600) / 60)
            local headerLbl = Instance.new("TextLabel")
            headerLbl.Size = UDim2.new(1, 0, 0, 30)
            headerLbl.BackgroundTransparency = 1
            headerLbl.TextColor3 = daily.bonusClaimed and PROGRESS_FILL or Color3.fromRGB(180, 180, 200)
            headerLbl.TextSize = 11
            headerLbl.Font = Enum.Font.Gotham
            headerLbl.LayoutOrder = 0
            headerLbl.Text = daily.bonusClaimed
                and ("🎉 All dailies done! New quests in " .. hours .. "h " .. mins .. "m")
                or ("Resets in " .. hours .. "h " .. mins .. "m  |  Complete all 3: +" .. (daily.bonus or 100) .. " bonus coins")
            headerLbl.Parent = scrollFrame

            for i, quest in ipairs(daily.quests) do
                createDailyCard(quest, i)
            end
        end
    elseif currentTab == "Active" then
        local active = questData.active or {}
        if #active == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 60)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
            emptyLbl.TextSize = 14
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.Text = "No active quests.\nCheck Available tab!"
            emptyLbl.Parent = scrollFrame
        else
            for i, quest in ipairs(active) do
                createActiveCard(quest, i)
            end
        end
    elseif currentTab == "Available" then
        local available = questData.available or {}
        if #available == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 60)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
            emptyLbl.TextSize = 14
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.Text = "No quests available.\nComplete your active ones first!"
            emptyLbl.Parent = scrollFrame
        else
            for i, quest in ipairs(available) do
                createAvailableCard(quest, i)
            end
        end
    elseif currentTab == "Completed" then
        local completed = questData.completed or {}
        if #completed == 0 then
            local emptyLbl = Instance.new("TextLabel")
            emptyLbl.Size = UDim2.new(1, 0, 0, 60)
            emptyLbl.BackgroundTransparency = 1
            emptyLbl.TextColor3 = Color3.fromRGB(140, 140, 160)
            emptyLbl.TextSize = 14
            emptyLbl.Font = Enum.Font.Gotham
            emptyLbl.Text = "No completed quests yet.\nKeep catching Studs!"
            emptyLbl.Parent = scrollFrame
        else
            for i, questId in ipairs(completed) do
                createCompletedCard(questId, i)
            end
        end
    end
end

-- Update the HUD tracker
local function updateTracker()
    -- Clear existing tracker entries
    for _, child in ipairs(trackerFrame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end

    if not questData or not questData.active or #questData.active == 0 then
        trackerFrame.Visible = false
        return
    end

    trackerFrame.Visible = true

    -- Header for tracker
    local headerLbl = Instance.new("TextLabel")
    headerLbl.Size = UDim2.new(1, -8, 0, 18)
    headerLbl.Position = UDim2.new(0, 4, 0, 0)
    headerLbl.BackgroundTransparency = 1
    headerLbl.TextColor3 = GOLD
    headerLbl.TextSize = 11
    headerLbl.Font = Enum.Font.GothamBold
    headerLbl.Text = "📜 Quests"
    headerLbl.TextXAlignment = Enum.TextXAlignment.Left
    headerLbl.LayoutOrder = 0
    headerLbl.Parent = trackerFrame

    local totalHeight = 22

    for i, quest in ipairs(questData.active) do
        local progress = quest.progress or 0
        local target = quest.target or 1
        local entry = Instance.new("TextLabel")
        entry.Size = UDim2.new(1, -8, 0, 16)
        entry.Position = UDim2.new(0, 4, 0, 0)
        entry.BackgroundTransparency = 1
        entry.TextColor3 = TEXT_COLOR
        entry.TextSize = 10
        entry.Font = Enum.Font.Gotham
        entry.Text = quest.name .. " (" .. progress .. "/" .. target .. ")"
        entry.TextXAlignment = Enum.TextXAlignment.Left
        entry.TextTruncate = Enum.TextTruncate.AtEnd
        entry.LayoutOrder = i
        entry.Parent = trackerFrame
        totalHeight = totalHeight + 18
    end

    trackerFrame.Size = UDim2.new(0, 240, 0, totalHeight)
end

-- Fetch quest data from server
function fetchQuestData()
    local success, data = pcall(function()
        return questRequest:InvokeServer({ action = "check" })
    end)
    if success and data then
        questData = data
        refreshContent()
        updateTracker()
    end
end

-- Toggle main panel
local function toggleUI()
    isOpen = not isOpen
    if isOpen then
        UIManager.CloseOtherPanels("Quests")
        mainFrame.Visible = true
        mainFrame.Position = UDim2.new(0.5, -190, 0.5, -250)
        mainFrame.BackgroundTransparency = 1
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            BackgroundTransparency = 0
        })
        tween:Play()
        fetchQuestData()
    else
        local tween = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1
        })
        tween:Play()
        tween.Completed:Connect(function()
            mainFrame.Visible = false
        end)
    end
end

-- Exclusive-panel registration: other panels (Shop, Settings, Leaderboard)
-- close this one when they open, and vice versa
UIManager.RegisterPanel("Quests", function()
    if isOpen then
        isOpen = false
        mainFrame.Visible = false
    end
end)

-- Show quest completion notification. The generation counter makes
-- back-to-back completions (e.g. a daily + the all-dailies bonus) safe: a
-- newer notification restarts the text/slide, and only the latest call is
-- allowed to slide the frame back out.
local notifGeneration = 0
local function showCompletionNotif(questName, reward)
    notifGeneration += 1
    local myGeneration = notifGeneration

    notifLabel.Text = "🎉 Quest Complete!"
    -- "added" because rewards are auto-deposited — there is nothing to claim
    notifDetail.Text = questName .. "  ·  +" .. reward .. " coins added"
    notifFrame.Position = UDim2.new(0.5, -160, 0, -120)
    notifFrame.Visible = true

    local slideIn = TweenService:Create(notifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Position = UDim2.new(0.5, -160, 0, 12)
    })
    slideIn:Play()

    task.wait(3)
    if notifGeneration ~= myGeneration then return end

    local slideOut = TweenService:Create(notifFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Position = UDim2.new(0.5, -160, 0, -120)
    })
    slideOut:Play()
    slideOut.Completed:Connect(function()
        if notifGeneration == myGeneration then
            notifFrame.Visible = false
        end
    end)
end

-- Event connections
toggleBtn.MouseButton1Click:Connect(toggleUI)
closeBtn.MouseButton1Click:Connect(function()
    if isOpen then toggleUI() end
end)

-- Listen for quest updates from server
questAction.OnClientEvent:Connect(function(data)
    if data.action == "completed" then
        showCompletionNotif(data.questName or data.questId or "Quest", data.reward or 0)
        fetchQuestData()
    elseif data.action == "progress" then
        -- Update progress in local data if we have it
        if questData and questData.active then
            for _, quest in ipairs(questData.active) do
                if quest.id == data.questId then
                    quest.progress = data.progress
                    break
                end
            end
        end
        refreshContent()
        updateTracker()
    elseif data.action == "error" then
        -- Could show error notification if desired
    end
end)

-- Keyboard shortcut: Q to toggle quest UI
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.Q then
        toggleUI()
    end
end)

-- Initial fetch after a short delay to let game load
task.delay(3, fetchQuestData)

-- Auto-refresh every 30 seconds while open
task.spawn(function()
    while true do
        task.wait(30)
        if isOpen then
            fetchQuestData()
        end
    end
end)