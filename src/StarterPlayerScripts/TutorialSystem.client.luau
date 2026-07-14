-- TutorialSystem: Guides new players through the basics of Stud Catcher.
-- Redesigned as a compact, non-blocking guide card docked at the bottom of
-- the screen: no full-screen dim overlay, no giant centered emoji — you can
-- walk around and try things WHILE reading each tip, which teaches better
-- than a modal wall of text. Advance with the button, Space/Enter, or Skip.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local tutorialSteps = {
	{ title = "Welcome to Studville", text = "This town is full of creatures called Studs. Your goal: catch them all." },
	{ title = "Finding Studs", text = "Walk through the tall grass outside town. Each zone hides different types." },
	{ title = "Catching", text = "Tap the circles to fill the catch bar. Rarer Studs = smaller, faster circles." },
	{ title = "Your StudDex", text = "Press C to track every Stud you've discovered. 24 species are out there." },
	{ title = "The Shop", text = "Sell duplicates for coins, then grab buffs like CatchBoost and StudLure." },
	{ title = "After Dark", text = "Shadow-type Studs only come out at night. Watch the day/night indicator." },
}

local currentStep = 1

local function startTutorial()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TutorialUI"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screenGui.Parent = playerGui

	-- Card docked bottom-center, slides up on show. Deliberately soft:
	-- translucent, no border, no filled buttons — reads as a floating hint,
	-- not a dialog window.
	local card = Instance.new("Frame")
	card.Name = "TutorialCard"
	card.Size = UDim2.new(0, 420, 0, 96)
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, 120) -- start off-screen
	card.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
	card.BackgroundTransparency = 0.35
	card.BorderSizePixel = 0
	card.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = card

	-- Step dots (●○○…) instead of a progress bar
	local dotsFrame = Instance.new("Frame")
	dotsFrame.Size = UDim2.new(0, #tutorialSteps * 14, 0, 8)
	dotsFrame.AnchorPoint = Vector2.new(0.5, 0)
	dotsFrame.Position = UDim2.new(0.5, 0, 0, 8)
	dotsFrame.BackgroundTransparency = 1
	dotsFrame.Parent = card
	local dotsLayout = Instance.new("UIListLayout")
	dotsLayout.FillDirection = Enum.FillDirection.Horizontal
	dotsLayout.Padding = UDim.new(0, 8)
	dotsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	dotsLayout.Parent = dotsFrame
	local dots = {}
	for i = 1, #tutorialSteps do
		local dot = Instance.new("Frame")
		dot.Size = UDim2.new(0, 6, 0, 6)
		dot.BackgroundColor3 = i == 1 and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(90, 90, 110)
		dot.BackgroundTransparency = i == 1 and 0 or 0.4
		dot.BorderSizePixel = 0
		dot.LayoutOrder = i
		dot.Parent = dotsFrame
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = dot
		dots[i] = dot
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -150, 0, 22)
	titleLabel.Position = UDim2.new(0, 20, 0, 20)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = tutorialSteps[1].title
	titleLabel.TextColor3 = Color3.fromRGB(255, 225, 140)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	titleLabel.TextStrokeTransparency = 0.75
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Parent = card

	local descLabel = Instance.new("TextLabel")
	descLabel.Size = UDim2.new(1, -150, 0, 44)
	descLabel.Position = UDim2.new(0, 20, 0, 44)
	descLabel.BackgroundTransparency = 1
	descLabel.Text = tutorialSteps[1].text
	descLabel.TextColor3 = Color3.fromRGB(215, 215, 225)
	descLabel.Font = Enum.Font.Gotham
	descLabel.TextSize = 13
	descLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	descLabel.TextStrokeTransparency = 0.8
	descLabel.TextWrapped = true
	descLabel.TextXAlignment = Enum.TextXAlignment.Left
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	descLabel.Parent = card

	-- Borderless text button — just gold text, no filled pill
	local nextButton = Instance.new("TextButton")
	nextButton.Size = UDim2.new(0, 110, 0, 30)
	nextButton.AnchorPoint = Vector2.new(1, 1)
	nextButton.Position = UDim2.new(1, -14, 1, -10)
	nextButton.BackgroundTransparency = 1
	nextButton.Text = "Continue  ▸"
	nextButton.TextColor3 = Color3.fromRGB(255, 215, 0)
	nextButton.Font = Enum.Font.GothamBold
	nextButton.TextSize = 15
	nextButton.TextXAlignment = Enum.TextXAlignment.Right
	nextButton.Parent = card

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.new(0, 110, 0, 12)
	hintLabel.AnchorPoint = Vector2.new(1, 1)
	hintLabel.Position = UDim2.new(1, -14, 1, -40)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Text = "space"
	hintLabel.TextColor3 = Color3.fromRGB(130, 130, 150)
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 11
	hintLabel.TextXAlignment = Enum.TextXAlignment.Right
	hintLabel.Parent = card

	local skipButton = Instance.new("TextButton")
	skipButton.Size = UDim2.new(0, 40, 0, 18)
	skipButton.AnchorPoint = Vector2.new(1, 0)
	skipButton.Position = UDim2.new(1, -14, 0, 8)
	skipButton.BackgroundTransparency = 1
	skipButton.Text = "skip"
	skipButton.TextColor3 = Color3.fromRGB(120, 120, 140)
	skipButton.Font = Enum.Font.Gotham
	skipButton.TextSize = 12
	skipButton.Parent = card

	-- Slide the card in
	TweenService:Create(card, TweenInfo.new(0.4, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 1, -20),
	}):Play()

	local finished = false
	local inputConn

	local function finish()
		if finished then return end
		finished = true
		if inputConn then inputConn:Disconnect() end
		-- Tell the server so it's written into this slot's save data —
		-- client-set attributes don't replicate, so a remote is required.
		StudEvents.TutorialComplete:FireServer()
		local out = TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.5, 0, 1, 120),
		})
		out:Play()
		out.Completed:Connect(function()
			screenGui:Destroy()
		end)
	end

	local function updateStep()
		local step = tutorialSteps[currentStep]
		titleLabel.Text = step.title
		descLabel.Text = step.text
		nextButton.Text = currentStep == #tutorialSteps and "Let's go!  ▸" or "Continue  ▸"
		for i, dot in ipairs(dots) do
			local reached = i <= currentStep
			TweenService:Create(dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundColor3 = reached and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(90, 90, 110),
				BackgroundTransparency = reached and 0 or 0.4,
			}):Play()
		end
	end

	local function advance()
		if finished then return end
		if currentStep < #tutorialSteps then
			currentStep += 1
			updateStep()
		else
			finish()
		end
	end

	nextButton.MouseButton1Click:Connect(advance)
	skipButton.MouseButton1Click:Connect(finish)

	-- Space / Enter also advance (event-driven; no polling)
	inputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return then
			advance()
		end
	end)
end

-- Trigger: ONLY once the player has actually entered a game AND picked their
-- starter. The server sets GameStarted=true on NewGame/LoadGame, TutorialSeen=false
-- only for brand new games, and StarterChosen=false while the starter pick is
-- on screen — so the starter choice is the only UI at first, and the tutorial
-- slides in right after the pick. Never replays on loaded saves (tutorialSeen
-- is persisted in the save slot).
local started = false
local function maybeStartTutorial()
	if started then return end
	if player:GetAttribute("GameStarted")
		and player:GetAttribute("TutorialSeen") == false
		and player:GetAttribute("StarterChosen") ~= false
	then
		started = true
		task.wait(1.5) -- brief beat after the starter card closes before the tutorial slides in
		startTutorial()
	end
end

player:GetAttributeChangedSignal("GameStarted"):Connect(maybeStartTutorial)
player:GetAttributeChangedSignal("TutorialSeen"):Connect(maybeStartTutorial)
player:GetAttributeChangedSignal("StarterChosen"):Connect(maybeStartTutorial)
maybeStartTutorial()
