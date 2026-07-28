-- CatchingMinigame: The main catching UI
-- Shows the wild Stud, a catch bar at the bottom, and tap circles on screen
-- Rarer Studs = smaller circles, faster fade, harder bar to fill
-- Failed attempts make the Stud harder to catch

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

print("[CatchingMinigame] Script loaded, waiting for StudEvents...")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 30)
if not StudEvents then
	warn("[CatchingMinigame] Failed to find StudEvents folder!")
	return
end

local encounterEvent = StudEvents:WaitForChild("EncounterStart", 30)
if not encounterEvent then
	warn("[CatchingMinigame] Failed to find EncounterStart RemoteEvent!")
	return
end

local catchAttemptEvent = StudEvents:FindFirstChild("CatchAttempt")
local encounterActionFunc = StudEvents:FindFirstChild("EncounterAction")

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

print("[CatchingMinigame] All dependencies loaded successfully")

-- State
local isActive = false
local currentStud = nil
local currentRarityConfig = nil
local catchProgress = 0
local failCount = 0
local timeRemaining = 0
local TIME_LIMIT = 12
local typeAdvantage = 1.0
local currentIsShiny = false

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchingMinigame"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Helper: row of round "stud bumps" along the top of a panel, like the top
-- of a LEGO plate. Purely decorative; bumps are round, panels stay square.
local function addStudBumps(parent, count, zIndex)
	local strip = Instance.new("Frame")
	strip.Name = "StudBumps"
	strip.Size = UDim2.new(1, -16, 0, 10)
	strip.Position = UDim2.new(0, 8, 0, -5)
	strip.BackgroundTransparency = 1
	strip.ZIndex = zIndex or 2
	strip.Parent = parent
	for i = 1, count do
		local bump = Instance.new("Frame")
		bump.Name = "Bump" .. i
		bump.Size = UDim2.new(0, 14, 0, 14)
		bump.Position = UDim2.new((i - 0.5) / count, -7, 0, -2)
		bump.BackgroundColor3 = UITheme.C_PANEL
		bump.BorderSizePixel = 0
		bump.ZIndex = zIndex or 2
		bump.Parent = strip
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = bump
		local s = Instance.new("UIStroke")
		s.Color = UITheme.C_BORDER
		s.Thickness = 2
		s.Parent = bump
	end
	return strip
end

-- Dark overlay
local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = UITheme.C_BG
overlay.BackgroundTransparency = 0.35
overlay.Parent = screenGui

-- Stud display area (center top): retro cartridge panel with stud bumps
local studArea = UITheme.CreateRetroPanel({
	name = "StudArea",
	size = UDim2.new(0.4, 0, 0.35, 0),
	pos = UDim2.new(0.3, 0, 0.05, 0),
	bg = UITheme.C_PANEL,
	zIndex = 2,
	parent = screenGui,
})
addStudBumps(studArea, 6, 3)

-- The Stud visual (1x1 brick representation with a 2x2 stud top)
local studVisual = Instance.new("Frame")
studVisual.Name = "StudVisual"
studVisual.Size = UDim2.new(0, 64, 0, 64)
studVisual.Position = UDim2.new(0.5, -32, 0.3, -32)
studVisual.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
studVisual.BorderSizePixel = 0
studVisual.ZIndex = 3
studVisual.Parent = studArea
UITheme.ApplyStroke(studVisual, UITheme.C_BORDER, 3)

-- 2x2 stud bumps on top of the brick (tinted white so they read on any color)
for bx = 0, 1 do
	for by = 0, 1 do
		local bump = Instance.new("Frame")
		bump.Name = "BrickBump" .. bx .. by
		bump.Size = UDim2.new(0.3, 0, 0.3, 0)
		bump.Position = UDim2.new(0.125 + bx * 0.45, 0, 0.125 + by * 0.45, 0)
		bump.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		bump.BackgroundTransparency = 0.6
		bump.BorderSizePixel = 0
		bump.ZIndex = 4
		bump.Parent = studVisual
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = bump
	end
end

-- Stud name label
local studNameLabel = UITheme.CreateLabel({
	name = "StudName",
	size = UDim2.new(1, 0, 0.15, 0),
	pos = UDim2.new(0, 0, 0.62, 0),
	text = "???",
	color = UITheme.C_WHITE,
	font = UITheme.F_PIXEL,
	ts = 22,
	zIndex = 3,
	parent = studArea,
})

-- Stud type + rarity label
local studTypeLabel = UITheme.CreateLabel({
	name = "StudType",
	size = UDim2.new(1, 0, 0.1, 0),
	pos = UDim2.new(0, 0, 0.78, 0),
	text = "??? Stud",
	color = UITheme.C_SEC,
	font = UITheme.F_BODY,
	ts = 16,
	zIndex = 3,
	parent = studArea,
})

-- Rarity badge: square tag with chunky border
local rarityBadge = Instance.new("Frame")
rarityBadge.Name = "RarityBadge"
rarityBadge.Size = UDim2.new(0.3, 0, 0.09, 0)
rarityBadge.Position = UDim2.new(0.35, 0, 0.89, 0)
rarityBadge.BackgroundColor3 = Color3.fromRGB(180, 180, 180)
rarityBadge.BorderSizePixel = 0
rarityBadge.ZIndex = 3
rarityBadge.Parent = studArea
UITheme.ApplyStroke(rarityBadge, UITheme.C_BORDER, 2)

local rarityLabel = UITheme.CreateLabel({
	name = "RarityText",
	text = "Common",
	color = UITheme.C_BORDER,
	font = UITheme.F_PIXEL,
	ts = 12,
	zIndex = 4,
	parent = rarityBadge,
})

-- Shiny indicator (shown when encountering a shiny stud)
local shinyIndicator = Instance.new("Frame")
shinyIndicator.Name = "ShinyIndicator"
shinyIndicator.Size = UDim2.new(0.25, 0, 0.08, 0)
shinyIndicator.Position = UDim2.new(0.375, 0, 0.02, 0)
shinyIndicator.BackgroundColor3 = UITheme.C_ACCENT
shinyIndicator.BackgroundTransparency = 1
shinyIndicator.BorderSizePixel = 0
shinyIndicator.Visible = false
shinyIndicator.ZIndex = 10
shinyIndicator.Parent = screenGui

local shinyStroke = Instance.new("UIStroke")
shinyStroke.Color = UITheme.C_BORDER
shinyStroke.Thickness = 3
shinyStroke.Transparency = 1
shinyStroke.Parent = shinyIndicator

local shinyLabel = UITheme.CreateLabel({
	name = "ShinyText",
	text = "SHINY!",
	color = UITheme.C_BORDER,
	font = UITheme.F_PIXEL,
	ts = 20,
	zIndex = 11,
	parent = shinyIndicator,
})

-- CATCH BAR (bottom of screen): chunky cartridge meter
local catchBarContainer = UITheme.CreateRetroPanel({
	name = "CatchBarContainer",
	size = UDim2.new(0.7, 0, 0.06, 0),
	pos = UDim2.new(0.15, 0, 0.88, 0),
	bg = Color3.fromRGB(24, 20, 34),
	zIndex = 2,
	shadowOffset = 4,
	parent = screenGui,
})

-- The fill bar (grows gold as progress builds)
local catchBarFill = Instance.new("Frame")
catchBarFill.Name = "CatchBarFill"
catchBarFill.Size = UDim2.new(0, 0, 1, -8)
catchBarFill.Position = UDim2.new(0, 4, 0, 4)
catchBarFill.BackgroundColor3 = UITheme.C_ACCENT
catchBarFill.BorderSizePixel = 0
catchBarFill.ZIndex = 3
catchBarFill.Parent = catchBarContainer

-- Segment ticks so the bar reads like a pixel meter
for i = 1, 9 do
	local tick = Instance.new("Frame")
	tick.Name = "Tick" .. i
	tick.Size = UDim2.new(0, 2, 1, 0)
	tick.Position = UDim2.new(i * 0.1, -1, 0, 0)
	tick.BackgroundColor3 = UITheme.C_BORDER
	tick.BackgroundTransparency = 0.4
	tick.BorderSizePixel = 0
	tick.ZIndex = 4
	tick.Parent = catchBarContainer
end

-- Progress text on bar
local progressLabel = UITheme.CreateLabel({
	name = "ProgressText",
	text = "0%",
	color = UITheme.C_WHITE,
	font = UITheme.F_PIXEL,
	ts = 16,
	zIndex = 10,
	parent = catchBarContainer,
})

-- Timer label
local timerLabel = UITheme.CreateLabel({
	name = "Timer",
	size = UDim2.new(0.15, 0, 0.04, 0),
	pos = UDim2.new(0.425, 0, 0.82, 0),
	text = "12s",
	color = UITheme.C_ACCENT,
	font = UITheme.F_PIXEL,
	ts = 20,
	parent = screenGui,
})

-- Tap instruction
local tapInstruction = UITheme.CreateLabel({
	name = "TapInstruction",
	size = UDim2.new(0.5, 0, 0.04, 0),
	pos = UDim2.new(0.25, 0, 0.78, 0),
	text = "TAP THE STUDS TO FILL THE BAR!",
	color = UITheme.C_SEC,
	font = UITheme.F_BODY,
	ts = 16,
	parent = screenGui,
})

-- Circle container (tap targets spawn here)
local circleContainer = Instance.new("Frame")
circleContainer.Name = "CircleContainer"
circleContainer.Size = UDim2.new(1, 0, 0.75, 0)
circleContainer.Position = UDim2.new(0, 0, 0.02, 0)
circleContainer.BackgroundTransparency = 1
circleContainer.Parent = screenGui

-- Result overlay (shown when encounter ends)
local resultOverlay = Instance.new("Frame")
resultOverlay.Name = "ResultOverlay"
resultOverlay.Size = UDim2.new(1, 0, 1, 0)
resultOverlay.BackgroundColor3 = UITheme.C_BG
resultOverlay.BackgroundTransparency = 0.45
resultOverlay.Visible = false
resultOverlay.ZIndex = 20
resultOverlay.Parent = screenGui

local resultLabel = UITheme.CreateLabel({
	name = "ResultText",
	size = UDim2.new(0.6, 0, 0.15, 0),
	pos = UDim2.new(0.2, 0, 0.4, 0),
	text = "",
	color = UITheme.C_WHITE,
	font = UITheme.F_PIXEL,
	ts = 32,
	zIndex = 21,
	parent = resultOverlay,
})

-- Forward declarations for local functions (needed since spawnCircle references them)
local updateCatchBar
local endEncounter
local startEncounter

-- Spawn a tap circle at a random position
local function spawnCircle()
	if not isActive then return end

	local config = currentRarityConfig
	if not config then return end

	local size = config.circleSize
	local lifespan = config.circleLifespan

	-- Increase difficulty per fail
	local failPenalty = failCount * 0.1
	lifespan = math.max(0.3, lifespan - failPenalty * 0.5)
	size = math.max(16, size - failCount * 4)

	-- Tap target: a square "TAP!" tile. Glows green while live; expiring
	-- untapped flashes red and fades out.
	local GREEN = Color3.fromRGB(50, 190, 80)
	local GLOW_GREEN = Color3.fromRGB(130, 255, 150)
	local RED = Color3.fromRGB(220, 55, 45)
	local GLOW_RED = Color3.fromRGB(255, 120, 110)

	local circle = Instance.new("TextButton")
	circle.Name = "TapCircle"
	circle.Size = UDim2.new(0, size, 0, size)
	circle.BackgroundColor3 = GREEN
	circle.BackgroundTransparency = 0.15
	circle.Text = "TAP!"
	circle.TextColor3 = Color3.new(1, 1, 1)
	circle.TextStrokeColor3 = Color3.fromRGB(15, 60, 25)
	circle.TextStrokeTransparency = 0.2
	circle.Font = Enum.Font.Arcade
	circle.TextScaled = true
	circle.BorderSizePixel = 0
	circle.ZIndex = 5

	local tapTextPadding = Instance.new("UIPadding")
	tapTextPadding.PaddingLeft = UDim.new(0.12, 0)
	tapTextPadding.PaddingRight = UDim.new(0.12, 0)
	tapTextPadding.PaddingTop = UDim.new(0.22, 0)
	tapTextPadding.PaddingBottom = UDim.new(0.22, 0)
	tapTextPadding.Parent = circle

	-- Random position within the circle container
	local containerAbsX = circleContainer.AbsoluteSize.X
	local containerAbsY = circleContainer.AbsoluteSize.Y
	if containerAbsX > 0 and containerAbsY > 0 then
		local maxX = math.max(0, 1 - (size / containerAbsX))
		local maxY = math.max(0, 1 - (size / containerAbsY))
		circle.Position = UDim2.new(math.random() * maxX, 0, math.random() * maxY, 0)
	else
		circle.Position = UDim2.new(math.random() * 0.8, 0, math.random() * 0.8, 0)
	end

	-- Glow: bright green outline that pulses while the tile is live
	local stroke = Instance.new("UIStroke")
	stroke.Color = GLOW_GREEN
	stroke.Thickness = 3
	stroke.Transparency = 1
	stroke.Parent = circle

	circle.Parent = circleContainer

	-- Glow in (green): fade the tile and its glow up together
	circle.BackgroundTransparency = 0.9
	circle.TextTransparency = 1
	TweenService:Create(circle, TweenInfo.new(0.2), {
		BackgroundTransparency = 0.15,
		TextTransparency = 0,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2), {
		Transparency = 0,
	}):Play()

	-- Gentle glow pulse for the tile's lifetime (dies with the instance)
	local pulse = TweenService:Create(stroke,
		TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.6, Thickness = 5 })
	task.delay(0.2, function()
		if circle.Parent then pulse:Play() end
	end)

	local tapped = false

	circle.MouseButton1Click:Connect(function()
		if tapped or not isActive then return end
		tapped = true

		-- Report the tap so the server can validate the catch was earned
		local tapEvent = StudEvents:FindFirstChild("CatchTap")
		if tapEvent then
			tapEvent:FireServer()
		end

		local catchBoostMultiplier = player:GetAttribute("CatchBoost") and 1.5 or 1.0
		local fillAmount = config.barFillRate * (1 - failPenalty * 0.5) * typeAdvantage * catchBoostMultiplier
		fillAmount = math.max(0.05, fillAmount)
		catchProgress = math.min(currentRarityConfig.catchBarTarget, catchProgress + fillAmount * 15)

		-- Tapped: bright flash and fade out
		pulse:Cancel()
		circle.BackgroundColor3 = Color3.fromRGB(235, 255, 235)
		circle.TextColor3 = Color3.fromRGB(30, 140, 60)
		TweenService:Create(circle, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.3), {
			Transparency = 1,
		}):Play()

		task.delay(0.3, function()
			circle:Destroy()
		end)

		updateCatchBar()

		if catchProgress >= currentRarityConfig.catchBarTarget then
			endEncounter(true)
		end
	end)

	-- Expired untapped: flash red, then fade away
	task.delay(lifespan, function()
		if not tapped and circle.Parent then
			pulse:Cancel()
			-- Snap to red for the flash...
			circle.BackgroundColor3 = RED
			circle.BackgroundTransparency = 0
			circle.TextStrokeColor3 = Color3.fromRGB(80, 15, 10)
			stroke.Color = GLOW_RED
			stroke.Transparency = 0
			-- ...then fade everything out
			TweenService:Create(circle, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
				TextTransparency = 1,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.4), {
				Transparency = 1,
			}):Play()
			task.delay(0.4, function()
				circle:Destroy()
			end)
		end
	end)
end

-- Update the catch bar visual
function updateCatchBar()
	local target = currentRarityConfig.catchBarTarget
	local percent = math.clamp(catchProgress / target, 0, 1)
	catchBarFill.Size = UDim2.new(percent, -8, 1, -8)

	-- Lerp the fill from arcade gold toward success green as the bar fills
	catchBarFill.BackgroundColor3 = UITheme.C_ACCENT:Lerp(UITheme.C_SUCCESS, percent)

	progressLabel.Text = math.floor(percent * 100) .. "%"
end

-- Start the encounter
function startEncounter(studInfo)
	if isActive then return end
	isActive = true
	currentStud = studInfo

	-- Play encounter flash effect
	UIManager.Call("PlayEncounterFlash", studInfo.rarity)

	-- Look up rarity config locally from StudData
	print("[CatchingMinigame] Starting encounter with", studInfo.name, "rarity:", studInfo.rarity)

	currentRarityConfig = StudData.GetRarityConfig(studInfo.rarity)
	if not currentRarityConfig then
		warn("[CatchingMinigame] No rarity config found for", studInfo.rarity)
		isActive = false
		return
	end

	-- Catch ball bonus (consumed server-side at CatchStart): shrink the bar
	-- target for this attempt. Clone so the shared StudData table stays pure.
	if studInfo.ballMult and studInfo.ballMult < 1 then
		local scaled = table.clone(currentRarityConfig)
		scaled.catchBarTarget = math.max(20, math.floor(scaled.catchBarTarget * studInfo.ballMult + 0.5))
		currentRarityConfig = scaled
	end

	-- FTUE: the very first catch succeeds on near-any input (small bar, fast
	-- fill) — first-catch-in-60s design. Server's min-tap floor matches.
	if studInfo.ftueEasyCatch then
		local scaled = table.clone(currentRarityConfig)
		scaled.catchBarTarget = 40
		scaled.barFillRate = 1.3
		currentRarityConfig = scaled
	end

	print("[CatchingMinigame] Rarity config loaded, showing minigame UI")

	catchProgress = 0
	failCount = 0
	timeRemaining = TIME_LIMIT
	typeAdvantage = studInfo.typeAdvantage or 1.0

	-- Show type advantage indicator
	if typeAdvantage > 1.0 then
		studTypeLabel.Text = studInfo.studType .. " Stud (Advantage!)"
		studTypeLabel.TextColor3 = UITheme.C_SUCCESS
	elseif typeAdvantage < 1.0 then
		studTypeLabel.Text = studInfo.studType .. " Stud (Disadvantage)"
		studTypeLabel.TextColor3 = UITheme.C_DANGER
	else
		studTypeLabel.Text = studInfo.studType .. " Stud"
		studTypeLabel.TextColor3 = UITheme.C_SEC
	end

	screenGui.Enabled = true
	resultOverlay.Visible = false

	-- Reconstruct color from RGB values sent by server
	studVisual.BackgroundColor3 = Color3.fromRGB(studInfo.colorR, studInfo.colorG, studInfo.colorB)
	studNameLabel.Text = studInfo.name
	studTypeLabel.Text = studInfo.studType .. " Stud"
	rarityLabel.Text = studInfo.rarity
	rarityBadge.BackgroundColor3 = currentRarityConfig.color

	-- Handle shiny encounter
	currentIsShiny = studInfo.isShiny or false
	if currentIsShiny then
		shinyIndicator.Visible = true
		shinyIndicator.BackgroundTransparency = 0.3
		shinyStroke.Transparency = 0

		-- Sparkle animation on the shiny indicator
		task.spawn(function()
			while isActive and currentIsShiny do
				task.wait(0.5)
				TweenService:Create(shinyIndicator, TweenInfo.new(0.25), {
					BackgroundTransparency = 0.1,
				}):Play()
				task.wait(0.25)
				TweenService:Create(shinyIndicator, TweenInfo.new(0.25), {
					BackgroundTransparency = 0.4,
				}):Play()
			end
			shinyIndicator.Visible = false
		end)

		-- Add sparkle effect to stud visual
		local sparkle = Instance.new("ImageLabel")
		sparkle.Name = "ShinySparkle"
		sparkle.Size = UDim2.new(2, 0, 2, 0)
		sparkle.Position = UDim2.new(-0.5, 0, -0.5, 0)
		sparkle.BackgroundTransparency = 1
		sparkle.Image = "rbxassetid://297688811"
		sparkle.ImageTransparency = 0.3
		sparkle.Parent = studVisual

		task.spawn(function()
			while isActive and sparkle.Parent do
				task.wait(0.05)
				sparkle.Rotation = sparkle.Rotation + 5
			end
			if sparkle.Parent then sparkle.Parent = nil end
		end)
	else
		shinyIndicator.Visible = false
	end

	updateCatchBar()

	-- Clear old circles (Destroy, not Parent=nil — detached tiles kept
	-- their click connections and pulse tweens alive)
	for _, c in circleContainer:GetChildren() do
		c:Destroy()
	end

	-- Circle spawning loop
	task.spawn(function()
		while isActive and timeRemaining > 0 do
			spawnCircle()
			local rate = currentRarityConfig.circleSpawnRate
			local urgency = 1 - (timeRemaining / TIME_LIMIT) * 0.3
			task.wait(rate * urgency)
		end
	end)

	-- Stud visual animation (bouncing and glowing)
	task.spawn(function()
		local bounceAngle = 0
		while isActive do
			task.wait(0.03)
			bounceAngle = bounceAngle + 3
			local bounce = math.abs(math.sin(bounceAngle / 30)) * 8
			studVisual.Position = UDim2.new(0.5, -32, 0.3, -32 - bounce)

			-- Glow effect based on catch progress
			local percent = catchProgress / currentRarityConfig.catchBarTarget
			local glowSize = 64 + percent * 20
			studVisual.Size = UDim2.new(0, glowSize, 0, glowSize)
			studVisual.Position = UDim2.new(0.5, -glowSize/2, 0.3, -glowSize/2 - bounce)
		end
		-- Reset position when done
		studVisual.Size = UDim2.new(0, 64, 0, 64)
		studVisual.Position = UDim2.new(0.5, -32, 0.3, -32)
	end)

	-- Timer countdown
	task.spawn(function()
		while isActive and timeRemaining > 0 do
			task.wait(1)
			if not isActive then break end
			timeRemaining = timeRemaining - 1
			timerLabel.Text = math.ceil(timeRemaining) .. "s"
			if timeRemaining <= 3 then
				timerLabel.TextColor3 = UITheme.C_DANGER
			end
		end
		if isActive then endEncounter(false) end
	end)

	-- Bar decay over time
	task.spawn(function()
		while isActive and timeRemaining > 0 do
			task.wait(0.5)
			if not isActive then break end
			catchProgress = math.max(0, catchProgress - 1)
			updateCatchBar()
			if catchProgress >= currentRarityConfig.catchBarTarget then
				endEncounter(true)
			end
		end
	end)
end

-- End the encounter
function endEncounter(wasCaught)
	if not isActive then return end
	isActive = false

	resultOverlay.Visible = true

	-- Function-scoped: the task.delay at the bottom passes this to
	-- OnCatchingMinigameEnd — as a block-local it was always nil there,
	-- so BattleUI never logged the caught stud's name/coins.
	local result = nil

	if wasCaught then
		-- Ask the server FIRST — only celebrate if it actually granted the
		-- stud. Previously "Caught!" showed unconditionally even when the
		-- server rejected the request, so players saw a catch that never
		-- reached their inventory.
		if encounterActionFunc then
			local ok, res = pcall(function()
				return encounterActionFunc:InvokeServer("CatchSuccess")
			end)
			if ok then result = res end
		end

		if result and result.success then
			resultLabel.Text = "Caught!"
			resultLabel.TextColor3 = UITheme.C_SUCCESS
			UIManager.Call("PlayCatchCelebration", result.isNew)
			UIManager.Call("OnCatchSuccess")
		else
			-- Server rejected the catch (encounter already ended server-side),
			-- so no retry is possible — close out as an escape.
			resultLabel.Text = "It broke free and fled!"
			resultLabel.TextColor3 = UITheme.C_DANGER
			UIManager.Call("OnCatchFail")
			task.delay(2, function()
				screenGui.Enabled = false
				resultOverlay.Visible = false
				for _, c in circleContainer:GetChildren() do
					c.Parent = nil
				end
				UIManager.Call("OnCatchingMinigameEnd", false, { result = "escaped" })
			end)
			return
		end
	else
		failCount = failCount + 1
		resultLabel.Text = "It escaped! Try again?"
		resultLabel.TextColor3 = UITheme.C_DANGER

		-- Tell server the catch failed (wild stud counter-attacks)
		local failResult = nil
		if encounterActionFunc then
			local ok, res = pcall(function()
				return encounterActionFunc:InvokeServer("CatchFail")
			end)
			if ok then failResult = res end
		end

		-- Reset catch streak on fail
		UIManager.Call("OnCatchFail")

		-- If player fainted from counter-attack, close everything
		if failResult and failResult.result == "player_fainted" then
			task.delay(1.5, function()
				screenGui.Enabled = false
				resultOverlay.Visible = false
				for _, c in circleContainer:GetChildren() do
					c.Parent = nil
				end
				UIManager.Call("OnCatchingMinigameEnd", false, failResult)
			end)
			return
		end

		task.delay(1.5, function()
			if not resultOverlay.Visible then return end

			local retryBtn = UITheme.CreateButton({
				name = "RetryBtn",
				size = UDim2.new(0.3, 0, 0.08, 0),
				pos = UDim2.new(0.35, 0, 0.55, 0),
				bg = UITheme.C_ACCENT,
				text = "RETRY (HARDER!)",
				tc = UITheme.C_BORDER,
				ts = 18,
				zIndex = 22,
				strokeColor = UITheme.C_BORDER,
				strokeThickness = 3,
				parent = resultOverlay,
			})

			local giveUpBtn = UITheme.CreateButton({
				name = "GiveUpBtn",
				size = UDim2.new(0.3, 0, 0.08, 0),
				pos = UDim2.new(0.35, 0, 0.65, 0),
				bg = UITheme.C_DANGER,
				text = "GIVE UP",
				tc = UITheme.C_WHITE,
				ts = 18,
				zIndex = 22,
				strokeColor = UITheme.C_BORDER,
				strokeThickness = 3,
				parent = resultOverlay,
			})



			retryBtn.MouseButton1Click:Connect(function()
				retryBtn.Parent = nil
				giveUpBtn.Parent = nil
				resultOverlay.Visible = false
				isActive = true
				catchProgress = 0
				timeRemaining = TIME_LIMIT
				timerLabel.TextColor3 = UITheme.C_ACCENT
				updateCatchBar()

				task.spawn(function()
					while isActive and timeRemaining > 0 do
						spawnCircle()
						local rate = currentRarityConfig.circleSpawnRate
						local urgency = 1 - (timeRemaining / TIME_LIMIT) * 0.3
						task.wait(rate * urgency)
					end
				end)

				task.spawn(function()
					while isActive and timeRemaining > 0 do
						task.wait(1)
						if not isActive then break end
						timeRemaining = timeRemaining - 1
						timerLabel.Text = math.ceil(timeRemaining) .. "s"
						if timeRemaining <= 3 then
							timerLabel.TextColor3 = UITheme.C_DANGER
						end
					end
					if isActive then endEncounter(false) end
				end)

				task.spawn(function()
					while isActive and timeRemaining > 0 do
						task.wait(0.5)
						if not isActive then break end
						catchProgress = math.max(0, catchProgress - 1)
						updateCatchBar()
						if catchProgress >= currentRarityConfig.catchBarTarget then
							endEncounter(true)
						end
					end
				end)
			end)

			giveUpBtn.MouseButton1Click:Connect(function()
				screenGui.Enabled = false
				resultOverlay.Visible = false
				retryBtn.Parent = nil
				giveUpBtn.Parent = nil
				for _, c in circleContainer:GetChildren() do
					c.Parent = nil
				end
				-- Tell server player is running away
				if encounterActionFunc then
					pcall(function()
						encounterActionFunc:InvokeServer("Run")
					end)
				end
				UIManager.Call("OnCatchingMinigameEnd", false, { result = "escaped" })
			end)
		end)
	end

	if wasCaught then
		task.delay(2, function()
			screenGui.Enabled = false
			resultOverlay.Visible = false
			for _, c in circleContainer:GetChildren() do
				c.Parent = nil
			end
			UIManager.Call("OnCatchingMinigameEnd", true, result)
		end)
	end
end

-- Auto-start on EncounterStart is DISABLED - EncounterUI now handles the encounter flow
-- encounterEvent.OnClientEvent:Connect(function(studInfo)
-- 	print("[CatchingMinigame] Received encounter event for", studInfo.name, "type:", studInfo.studType)
-- 	startEncounter(studInfo)
-- end)

-- Expose startEncounter via UIManager so other scripts can trigger it
UIManager.Register("StartCatchingMinigame", startEncounter)
UIManager.Unregister("OnCatchingMinigameEnd")  -- Callback set by BattleUI before starting

print("[CatchingMinigame] Initialized (triggered via UIManager.Call(\"StartCatchingMinigame\") from BattleUI)")