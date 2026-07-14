-- LeaderboardUI: trophy button on the HUD rail opens a panel with
-- This-Server and Global (cross-server) top-10 boards.
-- Data comes from LeaderboardSystem via LeaderboardUpdate broadcasts and
-- the RequestLeaderboard RemoteFunction.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local leaderboardEvent = StudEvents:WaitForChild("LeaderboardUpdate", 30)
local requestLeaderboard = StudEvents:WaitForChild("RequestLeaderboard", 30)
if not leaderboardEvent or not requestLeaderboard then return end

local BG = Color3.fromRGB(25, 25, 35)
local HEADER = Color3.fromRGB(40, 40, 55)
local GOLD = Color3.fromRGB(255, 200, 50)
local TEXT = Color3.fromRGB(230, 230, 230)
local MUTED = Color3.fromRGB(150, 150, 170)
local ACCENT = Color3.fromRGB(100, 180, 255)
local ROW_A = Color3.fromRGB(35, 35, 48)
local ROW_B = Color3.fromRGB(30, 30, 42)

local boardData = nil
local isOpen = false
local currentScope = "server" -- "server" | "global"
local currentCategory = "catches"

-- Categories per scope (server boards have coins; global has shinies)
local CATEGORIES = {
	server = {
		{ key = "catches", label = "Catches" },
		{ key = "coins", label = "Coins" },
		{ key = "dex", label = "Dex" },
	},
	global = {
		{ key = "catches", label = "Catches" },
		{ key = "dex", label = "Dex" },
		{ key = "shinies", label = "Shinies" },
	},
}

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LeaderboardUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Toggle button on the right HUD rail (below quests y=60 and gear y=112)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "LeaderboardToggle"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(1, -56, 0, 164)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
toggleBtn.BackgroundTransparency = 0.25
toggleBtn.TextColor3 = GOLD
toggleBtn.TextSize = 22
toggleBtn.Text = "🏆"
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

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 340, 0, 430)
panel.Position = UDim2.new(0.5, -170, 0.5, -215)
panel.BackgroundColor3 = BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(80, 80, 100)
panelStroke.Thickness = 2
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = HEADER
header.BorderSizePixel = 0
header.Parent = panel

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = GOLD
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "🏆 Leaderboards"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

-- Scope toggle (This Server / Global)
local scopeFrame = Instance.new("Frame")
scopeFrame.Size = UDim2.new(1, -16, 0, 30)
scopeFrame.Position = UDim2.new(0, 8, 0, 50)
scopeFrame.BackgroundTransparency = 1
scopeFrame.Parent = panel

local scopeButtons = {}
local refreshBoard -- forward declaration

local function styleScopeButtons()
	for scope, btn in pairs(scopeButtons) do
		btn.BackgroundColor3 = (scope == currentScope) and ACCENT or Color3.fromRGB(50, 50, 65)
	end
end

for i, scope in ipairs({ "server", "global" }) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.49, 0, 1, 0)
	btn.Position = UDim2.new((i - 1) * 0.51, 0, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	btn.TextColor3 = TEXT
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamBold
	btn.Text = scope == "server" and "THIS SERVER" or "GLOBAL"
	btn.BorderSizePixel = 0
	btn.Parent = scopeFrame
	scopeButtons[scope] = btn
	btn.MouseButton1Click:Connect(function()
		currentScope = scope
		-- Ensure the category exists in this scope
		local valid = false
		for _, cat in ipairs(CATEGORIES[scope]) do
			if cat.key == currentCategory then
				valid = true
				break
			end
		end
		if not valid then currentCategory = CATEGORIES[scope][1].key end
		refreshBoard()
	end)
end

-- Category buttons
local catFrame = Instance.new("Frame")
catFrame.Size = UDim2.new(1, -16, 0, 28)
catFrame.Position = UDim2.new(0, 8, 0, 86)
catFrame.BackgroundTransparency = 1
catFrame.Parent = panel

-- Rows container
local rowsFrame = Instance.new("ScrollingFrame")
rowsFrame.Size = UDim2.new(1, -16, 1, -128)
rowsFrame.Position = UDim2.new(0, 8, 0, 120)
rowsFrame.BackgroundTransparency = 1
rowsFrame.BorderSizePixel = 0
rowsFrame.ScrollBarThickness = 4
rowsFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
rowsFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
rowsFrame.Parent = panel

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 3)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rowsFrame

local function rebuildCategoryButtons()
	for _, child in ipairs(catFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local cats = CATEGORIES[currentScope]
	for i, cat in ipairs(cats) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1 / #cats, -4, 1, 0)
		btn.Position = UDim2.new((i - 1) / #cats, 2, 0, 0)
		btn.BackgroundColor3 = (cat.key == currentCategory) and GOLD or Color3.fromRGB(50, 50, 65)
		btn.TextColor3 = (cat.key == currentCategory) and Color3.fromRGB(30, 30, 40) or TEXT
		btn.TextSize = 11
		btn.Font = Enum.Font.GothamBold
		btn.Text = cat.label
		btn.BorderSizePixel = 0
		btn.Parent = catFrame
		btn.MouseButton1Click:Connect(function()
			currentCategory = cat.key
			refreshBoard()
		end)
	end
end

refreshBoard = function()
	styleScopeButtons()
	rebuildCategoryButtons()

	for _, child in ipairs(rowsFrame:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local source
	if currentScope == "global" then
		source = boardData and boardData.global and boardData.global[currentCategory]
	else
		source = boardData and boardData[currentCategory]
	end
	source = source or {}

	if #source == 0 then
		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Size = UDim2.new(1, 0, 0, 50)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.TextColor3 = MUTED
		emptyLbl.TextSize = 13
		emptyLbl.Font = Enum.Font.Gotham
		emptyLbl.Text = currentScope == "global"
			and "No global scores yet.\nBe the first on the board!"
			or "No scores yet this server."
		emptyLbl.Parent = rowsFrame
		return
	end

	for rank, entry in ipairs(source) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 30)
		row.BackgroundColor3 = rank % 2 == 1 and ROW_A or ROW_B
		row.BorderSizePixel = 0
		row.LayoutOrder = rank
		row.Parent = rowsFrame

		local rankLbl = Instance.new("TextLabel")
		rankLbl.Size = UDim2.new(0, 34, 1, 0)
		rankLbl.BackgroundTransparency = 1
		rankLbl.TextColor3 = rank <= 3 and GOLD or MUTED
		rankLbl.TextSize = 13
		rankLbl.Font = Enum.Font.GothamBold
		rankLbl.Text = rank <= 3 and ({ "🥇", "🥈", "🥉" })[rank] or ("#" .. rank)
		rankLbl.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -110, 1, 0)
		nameLbl.Position = UDim2.new(0, 38, 0, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.TextColor3 = entry.name == player.Name and ACCENT or TEXT
		nameLbl.TextSize = 13
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.Text = entry.name or "?"
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.Parent = row

		local valueLbl = Instance.new("TextLabel")
		valueLbl.Size = UDim2.new(0, 64, 1, 0)
		valueLbl.Position = UDim2.new(1, -70, 0, 0)
		valueLbl.BackgroundTransparency = 1
		valueLbl.TextColor3 = GOLD
		valueLbl.TextSize = 13
		valueLbl.Font = Enum.Font.GothamBold
		valueLbl.Text = tostring(entry.value or 0)
		valueLbl.TextXAlignment = Enum.TextXAlignment.Right
		valueLbl.Parent = row
	end
end

local function openPanel()
	UIManager.CloseOtherPanels("Leaderboard")
	isOpen = true
	panel.Visible = true
	task.spawn(function()
		local ok, data = pcall(function()
			return requestLeaderboard:InvokeServer()
		end)
		if ok and data then
			boardData = data
			if isOpen then refreshBoard() end
		end
	end)
	refreshBoard()
end

local function closePanel()
	isOpen = false
	panel.Visible = false
end

toggleBtn.MouseButton1Click:Connect(function()
	if isOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

leaderboardEvent.OnClientEvent:Connect(function(data)
	boardData = data
	if isOpen then refreshBoard() end
end)

UIManager.Register("OpenLeaderboard", openPanel)
-- Exclusive-panel registration (Shop/Quests/Settings close this on open)
UIManager.RegisterPanel("Leaderboard", closePanel)

print("[LeaderboardUI] Initialized")
