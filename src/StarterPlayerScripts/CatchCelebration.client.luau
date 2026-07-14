if true then return end -- [Disabled] Consolidated into CatchResultUI
-- CatchCelebration: Visual particle burst and screen flash when catching a Stud
-- Listens for the CatchingMinigame result and adds celebratory effects

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create a ScreenGui for celebration effects
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchCelebration"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Flash frame (brief white flash on catch)
local flashFrame = Instance.new("Frame")
flashFrame.Name = "Flash"
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
flashFrame.BackgroundTransparency = 1
flashFrame.ZIndex = 50
flashFrame.Parent = screenGui

-- Sparkle particles container (centered)
local sparkleContainer = Instance.new("Frame")
sparkleContainer.Name = "SparkleContainer"
sparkleContainer.Size = UDim2.new(0.4, 0, 0.35, 0)
sparkleContainer.Position = UDim2.new(0.3, 0, 0.05, 0)
sparkleContainer.BackgroundTransparency = 1
sparkleContainer.ClipsDescendants = false
sparkleContainer.Parent = screenGui

-- Create sparkle UI elements
local sparkles = {}
for i = 1, 12 do
	local sparkle = Instance.new("Frame")
	sparkle.Name = "Sparkle" .. i
	sparkle.Size = UDim2.new(0, 8, 0, 8)
	sparkle.Position = UDim2.new(0.5, -4, 0.5, -4)
	sparkle.BackgroundColor3 = Color3.fromRGB(255, 220, 100)
	sparkle.BackgroundTransparency = 1
	sparkle.BorderSizePixel = 0
	sparkle.ZIndex = 51
	sparkle.Parent = sparkleContainer



	table.insert(sparkles, sparkle)
end

-- "NEW!" badge that appears for first-time catches
local newBadge = Instance.new("TextLabel")
newBadge.Name = "NewBadge"
newBadge.Size = UDim2.new(0.15, 0, 0.06, 0)
newBadge.Position = UDim2.new(0.55, 0, 0.35, 0)
newBadge.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
newBadge.Text = "NEW!"
newBadge.TextColor3 = Color3.fromRGB(40, 20, 0)
newBadge.Font = Enum.Font.GothamBold
newBadge.TextSize = 20
newBadge.BackgroundTransparency = 1
newBadge.TextTransparency = 1
newBadge.ZIndex = 52
newBadge.Parent = screenGui



local function playCatchCelebration(isNew)
	-- White flash
	TweenService:Create(flashFrame, TweenInfo.new(0.15), {
		BackgroundTransparency = 0.5,
	}):Play()

	task.delay(0.15, function()
		TweenService:Create(flashFrame, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	-- Sparkle burst
	for i, sparkle in sparkles do
		sparkle.Position = UDim2.new(0.5, -4, 0.5, -4)
		sparkle.BackgroundTransparency = 0

		local angle = (i / #sparkles) * math.pi * 2
		local distance = 0.3 + math.random() * 0.2
		local targetX = 0.5 + math.cos(angle) * distance
		local targetY = 0.5 + math.sin(angle) * distance

		-- Random color from warm palette
		local colors = {
			Color3.fromRGB(255, 220, 100),
			Color3.fromRGB(255, 180, 50),
			Color3.fromRGB(255, 255, 150),
			Color3.fromRGB(255, 150, 50),
		}
		sparkle.BackgroundColor3 = colors[math.random(#colors)]

		task.delay(math.random() * 0.1, function()
			TweenService:Create(sparkle, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Position = UDim2.new(targetX, -4, targetY, -4),
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 12, 0, 12),
			}):Play()
		end)
	end

	-- Show "NEW!" badge if first-time catch
	if isNew then
		newBadge.BackgroundTransparency = 0
		newBadge.TextTransparency = 0
		TweenService:Create(newBadge, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.55, 0, 0.32, 0),
		}):Play()

		task.delay(2, function()
			TweenService:Create(newBadge, TweenInfo.new(0.5), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
		end)
	end
end

-- Expose the celebration function globally so CatchingMinigame can call it
_G.PlayCatchCelebration = playCatchCelebration

print("[CatchCelebration] Initialized")