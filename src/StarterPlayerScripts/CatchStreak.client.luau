-- CatchStreak: Tracks consecutive catches and shows a combo counter
-- Catching multiple Studs in a row without failing increases the streak

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchStreak"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Streak counter (right side)
local streakFrame = Instance.new("Frame")
streakFrame.Name = "StreakFrame"
streakFrame.Size = UDim2.new(0.1, 0, 0.08, 0)
streakFrame.Position = UDim2.new(0.88, 0, 0.06, 0)
streakFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
streakFrame.BackgroundTransparency = 0.3
streakFrame.BorderSizePixel = 0
streakFrame.Visible = false
streakFrame.Parent = screenGui



local streakLabel = Instance.new("TextLabel")
streakLabel.Name = "StreakText"
streakLabel.Size = UDim2.new(1, 0, 0.6, 0)
streakLabel.Position = UDim2.new(0, 0, 0, 0)
streakLabel.BackgroundTransparency = 1
streakLabel.Text = "0x Streak"
streakLabel.TextColor3 = Color3.fromRGB(255, 150, 50)
streakLabel.Font = Enum.Font.GothamBold
streakLabel.TextSize = 16
streakLabel.Parent = streakFrame

local streakSubLabel = Instance.new("TextLabel")
streakSubLabel.Name = "StreakSub"
streakSubLabel.Size = UDim2.new(1, 0, 0.4, 0)
streakSubLabel.Position = UDim2.new(0, 0, 0.6, 0)
streakSubLabel.BackgroundTransparency = 1
streakSubLabel.Text = "Nice!"
streakSubLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
streakSubLabel.Font = Enum.Font.Gotham
streakSubLabel.TextSize = 11
streakSubLabel.Parent = streakFrame

-- Chain pill (below the streak counter): shows the same-species catch chain
-- that multiplies shiny odds. Driven by the ChainSpecies/ChainCount player
-- attributes the server (EncounterSystem) maintains.
local chainFrame = Instance.new("Frame")
chainFrame.Name = "ChainFrame"
chainFrame.Size = UDim2.new(0.1, 0, 0, 26)
chainFrame.Position = UDim2.new(0.88, 0, 0.15, 0)
chainFrame.BackgroundColor3 = Color3.fromRGB(20, 35, 25)
chainFrame.BackgroundTransparency = 0.3
chainFrame.BorderSizePixel = 0
chainFrame.Visible = false
chainFrame.Parent = screenGui

local chainStroke = Instance.new("UIStroke")
chainStroke.Color = Color3.fromRGB(120, 220, 140)
chainStroke.Thickness = 1
chainStroke.Transparency = 0.4
chainStroke.Parent = chainFrame

local chainLabel = Instance.new("TextLabel")
chainLabel.Name = "ChainText"
chainLabel.Size = UDim2.new(1, 0, 1, 0)
chainLabel.BackgroundTransparency = 1
chainLabel.Text = ""
chainLabel.TextColor3 = Color3.fromRGB(150, 235, 165)
chainLabel.Font = Enum.Font.GothamBold
chainLabel.TextSize = 13
chainLabel.Parent = chainFrame

local function updateChainPill()
	local count = player:GetAttribute("ChainCount") or 0
	local speciesId = player:GetAttribute("ChainSpecies")
	-- A 1-chain is just "you caught something" — show from 2 links up,
	-- when the shiny bonus starts feeling real
	if count >= 2 and speciesId then
		local stud = StudData.GetStudById(speciesId)
		chainLabel.Text = "🔗 " .. (stud and stud.name or speciesId) .. " x" .. count
		chainFrame.Visible = true
		-- Pop on each link
		chainFrame.Size = UDim2.new(0.12, 0, 0, 30)
		TweenService:Create(chainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0.1, 0, 0, 26),
		}):Play()
	else
		chainFrame.Visible = false
	end
end

player:GetAttributeChangedSignal("ChainCount"):Connect(updateChainPill)
player:GetAttributeChangedSignal("ChainSpecies"):Connect(updateChainPill)
updateChainPill()

-- State
local currentStreak = 0
local streakMessages = {
	[1] = "Nice!",
	[2] = "Great!",
	[3] = "Awesome!",
	[5] = "Amazing!",
	[8] = "Incredible!",
	[10] = "LEGENDARY!",
}

local function getStreakMessage(streak)
	local best = "Nice!"
	for threshold, msg in streakMessages do
		if streak >= threshold then
			best = msg
		end
	end
	return best
end

local function getStreakColor(streak)
	if streak >= 10 then return Color3.fromRGB(255, 200, 0) end
	if streak >= 5 then return Color3.fromRGB(255, 100, 50) end
	if streak >= 3 then return Color3.fromRGB(255, 150, 50) end
	return Color3.fromRGB(200, 200, 200)
end

-- Expose functions for CatchingMinigame to call
UIManager.Register("OnCatchSuccess", function()
	currentStreak = currentStreak + 1

	streakFrame.Visible = true
	streakLabel.Text = currentStreak .. "x Streak"
	streakSubLabel.Text = getStreakMessage(currentStreak)
	streakLabel.TextColor3 = getStreakColor(currentStreak)

	-- Pop animation
	streakFrame.Size = UDim2.new(0.12, 0, 0.1, 0)
	TweenService:Create(streakFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0.1, 0, 0.08, 0),
	}):Play()
end)

UIManager.Register("OnCatchFail", function()
	currentStreak = 0
	streakFrame.Visible = false
end)

print("[CatchStreak] Initialized")