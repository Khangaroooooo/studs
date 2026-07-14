-- TownWelcome: Shows a welcome message when players first enter Studville
-- Also shows area-specific messages when entering different zones

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WELCOME_SHOWN_KEY = "StudvilleWelcomeShown"

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TownWelcomeUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Welcome frame
local welcomeFrame = Instance.new("Frame")
welcomeFrame.Name = "WelcomeFrame"
welcomeFrame.Size = UDim2.new(0, 500, 0, 120)
welcomeFrame.Position = UDim2.new(0.5, -250, 0.3, 0)
welcomeFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
welcomeFrame.BorderSizePixel = 0
welcomeFrame.BackgroundTransparency = 1
welcomeFrame.ClipsDescendants = true
welcomeFrame.Visible = false
welcomeFrame.Parent = screenGui



local welcomeStroke = Instance.new("UIStroke")
welcomeStroke.Color = Color3.fromRGB(255, 200, 50)
welcomeStroke.Thickness = 2
welcomeStroke.Transparency = 1
welcomeStroke.Parent = welcomeFrame

-- Title
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -20, 0, 40)
titleLabel.Position = UDim2.new(0, 20, 0, 10)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 200, 50)
titleLabel.TextSize = 28
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "Welcome to Studville!"
titleLabel.TextTransparency = 1
titleLabel.Parent = welcomeFrame

-- Subtitle
local subLabel = Instance.new("TextLabel")
subLabel.Size = UDim2.new(1, -20, 0, 25)
subLabel.Position = UDim2.new(0, 20, 0, 50)
subLabel.BackgroundTransparency = 1
subLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
subLabel.TextSize = 16
subLabel.Font = Enum.Font.Gotham
subLabel.Text = "Your adventure as a Stud Catcher begins here!"
subLabel.TextTransparency = 1
subLabel.Parent = welcomeFrame

-- Tips
local tipLabel = Instance.new("TextLabel")
tipLabel.Size = UDim2.new(1, -20, 0, 30)
tipLabel.Position = UDim2.new(0, 20, 0, 80)
tipLabel.BackgroundTransparency = 1
tipLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
tipLabel.TextSize = 13
tipLabel.Font = Enum.Font.Gotham
tipLabel.Text = "Walk in tall grass to find Studs | Press C for StudDex | Press Q for Quests"
tipLabel.TextTransparency = 1
tipLabel.Parent = welcomeFrame

-- Show welcome animation
local function showWelcome()
	welcomeFrame.Visible = true

	-- Fade in
	local fadeIn = TweenService:Create(welcomeFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 0
	})
	local strokeIn = TweenService:Create(welcomeStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		Transparency = 0
	})
	local titleIn = TweenService:Create(titleLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad), {
		TextTransparency = 0
	})
	local subIn = TweenService:Create(subLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0
	})
	local tipIn = TweenService:Create(tipLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		TextTransparency = 0
	})

	fadeIn:Play()
	strokeIn:Play()
	task.wait(0.3)
	titleIn:Play()
	task.wait(0.2)
	subIn:Play()
	task.wait(0.2)
	tipIn:Play()

	-- Hold for a few seconds
	task.wait(5)

	-- Fade out
	local fadeOut = TweenService:Create(welcomeFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
		BackgroundTransparency = 1
	})
	local strokeOut = TweenService:Create(welcomeStroke, TweenInfo.new(0.8, Enum.EasingStyle.Quad), {
		Transparency = 1
	})
	local titleOut = TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		TextTransparency = 1
	})
	local subOut = TweenService:Create(subLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		TextTransparency = 1
	})
	local tipOut = TweenService:Create(tipLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
		TextTransparency = 1
	})

	tipOut:Play()
	subOut:Play()
	titleOut:Play()
	strokeOut:Play()
	fadeOut:Play()

	fadeOut.Completed:Wait()
	welcomeFrame.Visible = false
end

-- Show welcome only once the player is actually in the world AND the tutorial
-- is out of the way: GameStarted is set on NewGame/LoadGame, and TutorialSeen
-- flips true when the tutorial finishes (it's already true on loaded saves).
-- This keeps the new-game order strict: starter pick → tutorial → welcome.
local function maybeShowWelcome()
	if player:GetAttribute(WELCOME_SHOWN_KEY) then return end
	if player:GetAttribute("GameStarted") and player:GetAttribute("TutorialSeen") == true then
		player:SetAttribute(WELCOME_SHOWN_KEY, true)
		task.wait(2) -- breathe before the banner fades in
		showWelcome()
	end
end

player:GetAttributeChangedSignal("GameStarted"):Connect(maybeShowWelcome)
player:GetAttributeChangedSignal("TutorialSeen"):Connect(maybeShowWelcome)
maybeShowWelcome()

print("[TownWelcome] Initialized")