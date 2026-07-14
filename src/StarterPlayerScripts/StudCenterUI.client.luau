-- StudCenterUI: Shows player collection stats when visiting the Stud Center
-- Displays unique studs caught, total catches, coins, and completion percentage

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

-- Create the StudCenter ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StudCenterUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Main frame
local frame = Instance.new("Frame")
frame.Name = "CenterFrame"
frame.Size = UDim2.new(0.5, 0, 0.6, 0)
frame.Position = UDim2.new(0.25, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
frame.BorderSizePixel = 0
frame.Visible = false
frame.Parent = screenGui



local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(100, 180, 255)
frameStroke.Thickness = 2
frameStroke.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 50)
title.BackgroundTransparency = 1
title.Text = "STUD CENTER"
title.TextColor3 = Color3.fromRGB(100, 180, 255)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.Parent = frame



-- Stats container
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, -20, 1, -120)
statsFrame.Position = UDim2.new(0, 10, 0, 60)
statsFrame.BackgroundTransparency = 1
statsFrame.Parent = frame

local statsLayout = Instance.new("UIListLayout")
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Padding = UDim.new(0, 8)
statsLayout.Parent = statsFrame

-- Helper to create a stat row
local function createStatRow(name, value, order, color)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
	row.LayoutOrder = order
	row.Parent = statsFrame



	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.6, 0, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = name
	nameLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local valueLabel = Instance.new("TextLabel")
	valueLabel.Name = "Value"
	valueLabel.Size = UDim2.new(0.35, 0, 1, 0)
	valueLabel.Position = UDim2.new(0.6, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = value
	valueLabel.TextColor3 = color or Color3.new(1, 1, 1)
	valueLabel.TextScaled = true
	valueLabel.Font = Enum.Font.GothamBold
	valueLabel.TextXAlignment = Enum.TextXAlignment.Right
	valueLabel.Parent = row

	return valueLabel
end

-- Create stat rows
local uniqueLabel = createStatRow("Unique Studs", "0 / 24", 1, Color3.fromRGB(100, 255, 100))
local totalLabel = createStatRow("Total Catches", "0", 2, Color3.fromRGB(255, 255, 255))
local coinsLabel = createStatRow("Coins", "0", 3, Color3.fromRGB(255, 215, 0))
local completionLabel = createStatRow("Completion", "0%", 4, Color3.fromRGB(100, 180, 255))

-- Progress bar
local progressFrame = Instance.new("Frame")
progressFrame.Size = UDim2.new(1, 0, 0, 24)
progressFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
progressFrame.LayoutOrder = 5
progressFrame.Parent = statsFrame



local progressBar = Instance.new("Frame")
progressBar.Size = UDim2.new(0, 0, 1, 0)
progressBar.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
progressBar.BorderSizePixel = 0
progressBar.Parent = progressFrame



-- Heal message
local healLabel = Instance.new("TextLabel")
healLabel.Size = UDim2.new(1, 0, 0, 30)
healLabel.BackgroundTransparency = 1
healLabel.Text = "Your encounter cooldown has been reset!"
healLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
healLabel.TextScaled = true
healLabel.Font = Enum.Font.GothamBold
healLabel.LayoutOrder = 6
healLabel.Parent = statsFrame

screenGui.Parent = player:WaitForChild("PlayerGui")

-- State
local isOpen = false

-- Update stats display
local function updateStats()
	local stats = StudEvents.GetPlayerStats:InvokeServer()
	local collection = StudEvents.RequestCollection:InvokeServer()

	-- Count unique studs
	local uniqueSet = {}
	for _, caught in ipairs(collection) do
		uniqueSet[caught.id] = true
	end
	local uniqueCount = 0
	for _ in pairs(uniqueSet) do
		uniqueCount += 1
	end

	local maxStuds = #StudData.Studs
	local pct = math.floor((uniqueCount / maxStuds) * 100)

	uniqueLabel.Text = uniqueCount .. " / " .. maxStuds
	totalLabel.Text = tostring(stats.totalCount or 0)
	coinsLabel.Text = tostring(stats.coins or 0)
	completionLabel.Text = pct .. "%"

	-- Animate progress bar
	local targetWidth = uniqueCount / maxStuds
	local tween = TweenService:Create(progressBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Size = UDim2.new(targetWidth, 0, 1, 0)
	})
	tween:Play()

	-- Color the bar based on completion
	if pct >= 100 then
		progressBar.BackgroundColor3 = Color3.fromRGB(255, 215, 0) -- Gold for complete
		healLabel.Text = "You caught them all! Congratulations!"
	elseif pct >= 75 then
		progressBar.BackgroundColor3 = Color3.fromRGB(100, 255, 100)
		healLabel.Text = "Almost there! Keep exploring!"
	else
		progressBar.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
		healLabel.Text = "Your encounter cooldown has been reset!"
	end
end

-- Toggle visibility
local function openCenter()
	if isOpen then return end
	isOpen = true
	frame.Visible = true
	updateStats()

	-- Animate in
	frame.Position = UDim2.new(0.25, 0, -0.6, 0)
	local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.25, 0, 0.2, 0)
	})
	tween:Play()
end

local function closeCenter()
	if not isOpen then return end
	isOpen = false

	local tween = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.25, 0, -0.6, 0)
	})
	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
	end)
end

-- Close button
closeBtn.MouseButton1Click:Connect(closeCenter)

-- Listen for heal trigger from server
StudEvents.HealPlayer.OnClientEvent:Connect(function()
	openCenter()
end)

-- Close on ESC
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeCenter()
	end
end)

print("[StudCenterUI] Initialized")