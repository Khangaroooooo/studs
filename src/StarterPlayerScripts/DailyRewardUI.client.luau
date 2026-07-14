-- DailyRewardUI: Shows daily reward notification when player logs in
-- Displays streak count and coins earned

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 10)
if not StudEvents then return end

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DailyRewardUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Main reward frame
local rewardFrame = Instance.new("Frame")
rewardFrame.Name = "RewardFrame"
rewardFrame.Size = UDim2.new(0.4, 0, 0.25, 0)
rewardFrame.Position = UDim2.new(0.3, 0, -0.3, 0) -- starts off-screen
rewardFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
rewardFrame.BackgroundTransparency = 0.1
rewardFrame.BorderSizePixel = 0
rewardFrame.Visible = false
rewardFrame.Parent = screenGui



local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(255, 200, 50)
frameStroke.Thickness = 3
frameStroke.Parent = rewardFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, 0, 0.25, 0)
titleLabel.Position = UDim2.new(0, 0, 0.05, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "DAILY REWARD!"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 32
titleLabel.TextStrokeTransparency = 0.3
titleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
titleLabel.Parent = rewardFrame

-- Coin amount
local coinLabel = Instance.new("TextLabel")
coinLabel.Name = "CoinAmount"
coinLabel.Size = UDim2.new(1, 0, 0.25, 0)
coinLabel.Position = UDim2.new(0, 0, 0.35, 0)
coinLabel.BackgroundTransparency = 1
coinLabel.Text = "+50 Coins"
coinLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
coinLabel.Font = Enum.Font.GothamBold
coinLabel.TextSize = 28
coinLabel.Parent = rewardFrame

-- Streak display
local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "Streak"
streakLabel.Size = UDim2.new(1, 0, 0.2, 0)
streakLabel.Position = UDim2.new(0, 0, 0.6, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.Text = "Streak: Day 1"
streakLabel.TextColor3 = Color3.fromRGB(200, 180, 100)
streakLabel.Font = Enum.Font.Gotham
streakLabel.TextSize = 18
streakLabel.Parent = rewardFrame

-- Streak dots (visual indicator of streak progress)
local streakDots = Instance.new("Frame")
streakDots.Name = "StreakDots"
streakDots.Size = UDim2.new(0.6, 0, 0.08, 0)
streakDots.Position = UDim2.new(0.2, 0, 0.82, 0)
streakDots.BackgroundTransparency = 1
streakDots.Parent = rewardFrame

local dotLayout = Instance.new("UIListLayout")
dotLayout.FillDirection = Enum.FillDirection.Horizontal
dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
dotLayout.Padding = UDim.new(0, 8)
dotLayout.Parent = streakDots

-- Create 5 streak dots
local streakDotFrames = {}
for i = 1, 5 do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 20, 0, 20)
	dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
	dot.BorderSizePixel = 0



	dot.Parent = streakDots
	streakDotFrames[i] = dot
end

-- Collect button
local collectBtn = Instance.new("TextButton")
collectBtn.Name = "CollectBtn"
collectBtn.Size = UDim2.new(0.4, 0, 0.12, 0)
collectBtn.Position = UDim2.new(0.3, 0, 0.92, 0)
collectBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
collectBtn.Text = "Collect!"
collectBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
collectBtn.Font = Enum.Font.GothamBold
collectBtn.TextSize = 20
collectBtn.Visible = false
collectBtn.Parent = rewardFrame



-- Show the daily reward popup
local function showDailyReward(coins, streak)
	coinLabel.Text = "+" .. coins .. " Coins"
	streakLabel.Text = "Streak: Day " .. streak

	-- Light up streak dots
	for i, dot in ipairs(streakDotFrames) do
		if i <= streak then
			dot.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		else
			dot.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		end
	end

	rewardFrame.Visible = true
	collectBtn.Visible = true

	-- Slide in from top
	rewardFrame.Position = UDim2.new(0.3, 0, -0.3, 0)
	TweenService:Create(rewardFrame, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.3, 0, 0.15, 0),
	}):Play()

	-- Handle collect button click
	local connection
	connection = collectBtn.MouseButton1Click:Connect(function()
		if connection then connection:Disconnect() end
		collectBtn.Visible = false

		-- Slide out
		TweenService:Create(rewardFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.3, 0, -0.3, 0),
		}):Play()

		task.delay(0.5, function()
			rewardFrame.Visible = false
		end)
	end)
end

-- Listen for daily reward events from server
local encounterResult = StudEvents:FindFirstChild("EncounterResult")
if encounterResult then
	encounterResult.OnClientEvent:Connect(function(data)
		if data and data.type == "dailyReward" then
			showDailyReward(data.coins, data.streak)
		end
	end)
end

print("[DailyRewardUI] Initialized")