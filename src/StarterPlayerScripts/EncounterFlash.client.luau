-- EncounterFlash: Visual effect when a wild Stud encounter triggers
-- Classic Pokemon-style screen flash and shake

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EncounterFlash"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Black bars (top and bottom) for cinematic effect
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0.15, 0)
topBar.Position = UDim2.new(0, 0, -0.15, 0)
topBar.BackgroundColor3 = Color3.new(0, 0, 0)
topBar.BorderSizePixel = 0
topBar.ZIndex = 30
topBar.Parent = screenGui

local bottomBar = Instance.new("Frame")
bottomBar.Name = "BottomBar"
bottomBar.Size = UDim2.new(1, 0, 0.15, 0)
bottomBar.Position = UDim2.new(0, 0, 1, 0)
bottomBar.BackgroundColor3 = Color3.new(0, 0, 0)
bottomBar.BorderSizePixel = 0
bottomBar.ZIndex = 30
bottomBar.Parent = screenGui

-- Flash overlay
local flashOverlay = Instance.new("Frame")
flashOverlay.Name = "Flash"
flashOverlay.Size = UDim2.new(1, 0, 1, 0)
flashOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
flashOverlay.BackgroundTransparency = 1
flashOverlay.ZIndex = 31
flashOverlay.Parent = screenGui

-- "Wild Stud!" text
local encounterText = Instance.new("TextLabel")
encounterText.Name = "EncounterText"
encounterText.Size = UDim2.new(0.6, 0, 0.12, 0)
encounterText.Position = UDim2.new(0.2, 0, 0.44, 0)
encounterText.BackgroundTransparency = 1
encounterText.Text = "Wild Stud!"
encounterText.TextColor3 = Color3.fromRGB(255, 255, 255)
encounterText.Font = Enum.Font.GothamBold
encounterText.TextSize = 48
encounterText.TextTransparency = 1
encounterText.ZIndex = 32
encounterText.Parent = screenGui

-- Expose function for CatchingMinigame to call
UIManager.Register("PlayEncounterFlash", function(rarity)
	local isLegendary = rarity == "Legendary"
	local isRare = rarity == "Rare"

	-- Screen flash (golden for legendary, blue for rare, white for others)
	if isLegendary then
		flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
	elseif isRare then
		flashOverlay.BackgroundColor3 = Color3.fromRGB(100, 150, 255)
	else
		flashOverlay.BackgroundColor3 = Color3.new(1, 1, 1)
	end

	local flashDuration = isLegendary and 0.2 or 0.1
	TweenService:Create(flashOverlay, TweenInfo.new(flashDuration), {
		BackgroundTransparency = 0,
	}):Play()

	task.delay(flashDuration, function()
		TweenService:Create(flashOverlay, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	-- Cinematic bars slide in
	TweenService:Create(topBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0, 0),
	}):Play()
	TweenService:Create(bottomBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0, 0, 0.85, 0),
	}):Play()

	-- "Wild Stud!" text (special for legendary)
	if isLegendary then
		encounterText.Text = "LEGENDARY Stud!"
		encounterText.TextColor3 = Color3.fromRGB(255, 200, 50)
		encounterText.TextSize = 44
	elseif isRare then
		encounterText.Text = "Rare Stud!"
		encounterText.TextColor3 = Color3.fromRGB(100, 150, 255)
		encounterText.TextSize = 46
	else
		encounterText.Text = "Wild Stud!"
		encounterText.TextColor3 = Color3.fromRGB(255, 255, 255)
		encounterText.TextSize = 48
	end

	encounterText.TextTransparency = 1
	task.delay(0.3, function()
		TweenService:Create(encounterText, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			TextTransparency = 0,
		}):Play()

		task.delay(1.2, function()
			TweenService:Create(encounterText, TweenInfo.new(0.3), {
				TextTransparency = 1,
			}):Play()

			-- Slide bars out
			TweenService:Create(topBar, TweenInfo.new(0.3), {
				Position = UDim2.new(0, 0, -0.15, 0),
			}):Play()
			TweenService:Create(bottomBar, TweenInfo.new(0.3), {
				Position = UDim2.new(0, 0, 1, 0),
			}):Play()
		end)
	end)

	-- Camera shake effect (stronger for rarer)
	local camera = game.Workspace.CurrentCamera
	local originalCFrame = camera.CFrame
	local shakeIntensity = isLegendary and 1.0 or isRare and 0.7 or 0.5
	local shakeCount = isLegendary and 10 or 6
	task.spawn(function()
		for i = 1, shakeCount do
			local offset = CFrame.new(
				(math.random() - 0.5) * shakeIntensity,
				(math.random() - 0.5) * shakeIntensity * 0.6,
				0
			)
			camera.CFrame = originalCFrame * offset
			task.wait(0.03)
		end
		camera.CFrame = originalCFrame
	end)
end)

print("[EncounterFlash] Initialized")