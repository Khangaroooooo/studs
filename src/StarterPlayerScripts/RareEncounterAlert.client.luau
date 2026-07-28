-- RareEncounterAlert: Shows dramatic visual effects when rare/legendary studs appear
-- Implements _G.PlayEncounterFlash for the CatchingMinigame
-- Also listens for rare sighting announcements from other players

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

-- Rarity colors for effects
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(75, 200, 75),
	Rare = Color3.fromRGB(65, 105, 225),
	Epic = Color3.fromRGB(160, 32, 240),
	Legendary = Color3.fromRGB(255, 170, 0),
	Shadow = Color3.fromRGB(80, 0, 120),
	Shiny = Color3.fromRGB(255, 215, 0),
}

-- Create the ScreenGui for encounter effects
local effectGui = Instance.new("ScreenGui")
effectGui.Name = "RareEncounterAlert"
effectGui.ResetOnSpawn = false
effectGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
effectGui.IgnoreGuiInset = true
effectGui.Parent = playerGui

-- Full-screen flash overlay
local flashOverlay = Instance.new("Frame")
flashOverlay.Name = "FlashOverlay"
flashOverlay.Size = UDim2.new(1, 0, 1, 0)
flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
flashOverlay.BackgroundTransparency = 1
flashOverlay.BorderSizePixel = 0
flashOverlay.ZIndex = 50
flashOverlay.Parent = effectGui

-- Border glow frame (pulsing border for rare encounters)
local borderGlow = Instance.new("Frame")
borderGlow.Name = "BorderGlow"
borderGlow.Size = UDim2.new(1, 0, 1, 0)
borderGlow.BackgroundTransparency = 1
borderGlow.BorderSizePixel = 0
borderGlow.ZIndex = 49
borderGlow.Parent = effectGui

-- Top border
local borderTop = Instance.new("Frame")
borderTop.Name = "TopBorder"
borderTop.Size = UDim2.new(1, 0, 0, 6)
borderTop.Position = UDim2.new(0, 0, 0, 0)
borderTop.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
borderTop.BackgroundTransparency = 1
borderTop.BorderSizePixel = 0
borderTop.ZIndex = 51
borderTop.Parent = borderGlow

-- Bottom border
local borderBottom = Instance.new("Frame")
borderBottom.Name = "BottomBorder"
borderBottom.Size = UDim2.new(1, 0, 0, 6)
borderBottom.Position = UDim2.new(0, 0, 1, -6)
borderBottom.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
borderBottom.BackgroundTransparency = 1
borderBottom.BorderSizePixel = 0
borderBottom.ZIndex = 51
borderBottom.Parent = borderGlow

-- Left border
local borderLeft = Instance.new("Frame")
borderLeft.Name = "LeftBorder"
borderLeft.Size = UDim2.new(0, 6, 1, 0)
borderLeft.Position = UDim2.new(0, 0, 0, 0)
borderLeft.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
borderLeft.BackgroundTransparency = 1
borderLeft.BorderSizePixel = 0
borderLeft.ZIndex = 51
borderLeft.Parent = borderGlow

-- Right border
local borderRight = Instance.new("Frame")
borderRight.Name = "RightBorder"
borderRight.Size = UDim2.new(0, 6, 1, 0)
borderRight.Position = UDim2.new(1, -6, 0, 0)
borderRight.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
borderRight.BackgroundTransparency = 1
borderRight.BorderSizePixel = 0
borderRight.ZIndex = 51
borderRight.Parent = borderGlow

-- Rare encounter banner ("A RARE STUD APPEARED!")
local encounterBanner = Instance.new("Frame")
encounterBanner.Name = "EncounterBanner"
encounterBanner.Size = UDim2.new(0.6, 0, 0.12, 0)
encounterBanner.Position = UDim2.new(0.2, 0, 0.15, 0)
encounterBanner.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
encounterBanner.BackgroundTransparency = 1
encounterBanner.BorderSizePixel = 0
encounterBanner.ZIndex = 52
encounterBanner.Visible = false
encounterBanner.Parent = effectGui



local bannerStroke = Instance.new("UIStroke")
bannerStroke.Color = Color3.fromRGB(255, 170, 0)
bannerStroke.Thickness = 3
bannerStroke.Transparency = 1
bannerStroke.Parent = encounterBanner

local bannerLabel = Instance.new("TextLabel")
bannerLabel.Name = "BannerText"
bannerLabel.Size = UDim2.new(1, 0, 0.6, 0)
bannerLabel.Position = UDim2.new(0, 0, 0.05, 0)
bannerLabel.BackgroundTransparency = 1
bannerLabel.Text = "A RARE STUD APPEARED!"
bannerLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
bannerLabel.Font = Enum.Font.Arcade
bannerLabel.TextSize = 28
bannerLabel.TextStrokeTransparency = 0.5
bannerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
bannerLabel.ZIndex = 53
bannerLabel.Parent = encounterBanner

local bannerSubLabel = Instance.new("TextLabel")
bannerSubLabel.Name = "BannerSubText"
bannerSubLabel.Size = UDim2.new(1, 0, 0.35, 0)
bannerSubLabel.Position = UDim2.new(0, 0, 0.6, 0)
bannerSubLabel.BackgroundTransparency = 1
bannerSubLabel.Text = ""
bannerSubLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
bannerSubLabel.Font = Enum.Font.Arcade
bannerSubLabel.TextSize = 18
bannerSubLabel.ZIndex = 53
bannerSubLabel.Parent = encounterBanner

-- Sighting notification (for other players seeing rare announcements)
local sightingNotification = Instance.new("Frame")
sightingNotification.Name = "SightingNotification"
sightingNotification.Size = UDim2.new(0.5, 0, 0.08, 0)
sightingNotification.Position = UDim2.new(0.25, 0, -0.1, 0) -- starts off-screen
 sightingNotification.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
sightingNotification.BackgroundTransparency = 0.2
 sightingNotification.BorderSizePixel = 0
sightingNotification.ZIndex = 55
sightingNotification.Visible = false
sightingNotification.Parent = effectGui



local sightingStroke = Instance.new("UIStroke")
sightingStroke.Color = Color3.fromRGB(65, 105, 225)
sightingStroke.Thickness = 2
sightingStroke.Parent = sightingNotification

local sightingIcon = Instance.new("TextLabel")
sightingIcon.Name = "Icon"
sightingIcon.Size = UDim2.new(0.08, 0, 0.7, 0)
sightingIcon.Position = UDim2.new(0.02, 0, 0.15, 0)
sightingIcon.BackgroundTransparency = 1
sightingIcon.Text = "\xe2\x9c\xa8" -- sparkle emoji
sightingIcon.TextSize = 24
sightingIcon.Font = Enum.Font.Arcade
sightingIcon.ZIndex = 56
sightingIcon.Parent = sightingNotification

local sightingLabel = Instance.new("TextLabel")
sightingLabel.Name = "SightingText"
sightingLabel.Size = UDim2.new(0.85, 0, 1, 0)
sightingLabel.Position = UDim2.new(0.1, 0, 0, 0)
sightingLabel.BackgroundTransparency = 1
 sightingLabel.Text = ""
sightingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
sightingLabel.Font = Enum.Font.Arcade
 sightingLabel.TextSize = 16
sightingLabel.TextXAlignment = Enum.TextXAlignment.Left
sightingLabel.ZIndex = 56
sightingLabel.Parent = sightingNotification

-- Particle burst frames (decorative circles that fly outward)
local particleContainer = Instance.new("Frame")
particleContainer.Name = "ParticleContainer"
particleContainer.Size = UDim2.new(1, 0, 1, 0)
particleContainer.BackgroundTransparency = 1
particleContainer.ZIndex = 48
particleContainer.Parent = effectGui

-- Spawn UI particles that fly outward from center
local function spawnUIParticles(color, count)
	for i = 1, count do
		local particle = Instance.new("Frame")
		particle.Size = UDim2.new(0, math.random(4, 12), 0, math.random(4, 12))
		particle.Position = UDim2.new(0.5, 0, 0.5, 0)
		particle.BackgroundColor3 = color
		particle.BackgroundTransparency = 0.3
		particle.BorderSizePixel = 0

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = particle

		particle.Parent = particleContainer

		-- Random direction
		local angle = math.random() * math.pi * 2
		local distance = math.random(150, 400)
		local targetX = 0.5 + math.cos(angle) * (distance / particleContainer.AbsoluteSize.X)
		local targetY = 0.5 + math.sin(angle) * (distance / particleContainer.AbsoluteSize.Y)

		task.spawn(function()
			local tween = TweenService:Create(particle, TweenInfo.new(
				math.random(8, 15) / 10,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			), {
				Position = UDim2.new(targetX, 0, targetY, 0),
				BackgroundTransparency = 1,
			})
			tween:Play()
			tween.Completed:Connect(function()
				particle.Parent = nil
			end)
		end)
	end
end

-- Play the encounter flash effect (called by CatchingMinigame via _G)
local function playEncounterFlash(rarity)
	local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common
	local isRare = rarity == "Rare" or rarity == "Epic"
	local isLegendary = rarity == "Legendary"
	local isShadow = rarity == "Shadow"

	if not (isRare or isLegendary or isShadow) then
		-- Common/Uncommon: just a subtle flash
		flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		TweenService:Create(flashOverlay, TweenInfo.new(0.15), {
			BackgroundTransparency = 0.7,
		}):Play()
		task.delay(0.15, function()
			TweenService:Create(flashOverlay, TweenInfo.new(0.3), {
				BackgroundTransparency = 1,
			}):Play()
		end)
		return
	end

	-- RARE encounter: dramatic flash + border glow + banner

	-- Step 1: Screen flash
	flashOverlay.BackgroundColor3 = isLegendary and Color3.fromRGB(255, 200, 50) or isShadow and Color3.fromRGB(100, 0, 180) or color
	TweenService:Create(flashOverlay, TweenInfo.new(0.1), {
		BackgroundTransparency = 0.3,
	}):Play()

	task.delay(0.15, function()
		TweenService:Create(flashOverlay, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
	end)

	-- Step 2: Second flash for legendary
	if isLegendary then
		task.delay(0.2, function()
			flashOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
			TweenService:Create(flashOverlay, TweenInfo.new(0.08), {
				BackgroundTransparency = 0.2,
			}):Play()
			task.delay(0.1, function()
				TweenService:Create(flashOverlay, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				}):Play()
			end)
		end)
	end

	-- Step 3: Border glow
	local borderTransparency = 0
	for _, border in {borderTop, borderBottom, borderLeft, borderRight} do
		border.BackgroundColor3 = color
		TweenService:Create(border, TweenInfo.new(0.3), {
			BackgroundTransparency = borderTransparency,
		}):Play()
	end

	-- Pulse the borders
	task.spawn(function()
		for pulse = 1, (isLegendary and 6 or 3) do
			task.wait(0.5)
			local pulseTrans = pulse % 2 == 0 and 0 or 0.5
			for _, border in {borderTop, borderBottom, borderLeft, borderRight} do
				TweenService:Create(border, TweenInfo.new(0.25), {
					BackgroundTransparency = pulseTrans,
				}):Play()
			end
		end
		-- Fade out borders
		for _, border in {borderTop, borderBottom, borderLeft, borderRight} do
			TweenService:Create(border, TweenInfo.new(0.5), {
				BackgroundTransparency = 1,
			}):Play()
		end
	end)

	-- Step 4: UI particles
	spawnUIParticles(color, isLegendary and 30 or isShadow and 20 or 15)

	-- Step 5: Encounter banner
	local bannerText = isLegendary and "A LEGENDARY STUD APPEARED!" or isShadow and "A SHADOW STUD EMERGES!" or "A RARE STUD APPEARED!"
	bannerLabel.Text = bannerText
	bannerLabel.TextColor3 = color
	bannerSubLabel.Text = isLegendary and "This is extremely rare - don't let it escape!" or isShadow and "It only appears at night..." or "Stay focused!"

	encounterBanner.Visible = true
	encounterBanner.BackgroundTransparency = 1
	bannerStroke.Transparency = 1
	bannerStroke.Color = color

	-- Animate banner in
	TweenService:Create(encounterBanner, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.15,
	}):Play()
	TweenService:Create(bannerStroke, TweenInfo.new(0.3), {
		Transparency = 0,
	}):Play()

	-- Animate banner out after delay
	task.delay(isLegendary and 4 or 3, function()
		TweenService:Create(encounterBanner, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(bannerStroke, TweenInfo.new(0.5), {
			Transparency = 1,
		}):Play()
		task.delay(0.5, function()
			encounterBanner.Visible = false
		end)
	end)

	-- Step 6: Camera shake for legendary
	if isLegendary then
		task.spawn(function()
			local originalCFrame = camera.CFrame
			for shake = 1, 10 do
				local offsetX = (math.random() - 0.5) * 0.3
				local offsetY = (math.random() - 0.5) * 0.3
				-- Offset from where the camera started, not from wherever the
				-- last nudge left it: compounding turns a shake into a drift.
				camera.CFrame = originalCFrame * CFrame.new(offsetX, offsetY, 0)
				task.wait(0.03)
			end
			camera.CFrame = originalCFrame
		end)
	end
end

-- Show sighting notification for other players
local function showSightingNotification(playerName, studName, rarity, isShiny)
	local color = RARITY_COLORS[rarity] or RARITY_COLORS.Common

	sightingLabel.Text = isShiny and (playerName .. " found a SHINY " .. studName .. "!") or (playerName .. " encountered a " .. rarity .. " stud: " .. studName .. "!")
	sightingStroke.Color = isShiny and Color3.fromRGB(255, 215, 0) or color
	sightingNotification.Visible = true

	-- Slide in from top
	sightingNotification.Position = UDim2.new(0.25, 0, -0.1, 0)
	TweenService:Create(sightingNotification, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.25, 0, 0.02, 0),
	}):Play()

	-- Slide out after delay
	task.delay(5, function()
		TweenService:Create(sightingNotification, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.new(0.25, 0, -0.1, 0),
		}):Play()
		task.delay(0.5, function()
			sightingNotification.Visible = false
		end)
	end)

	-- Small particle burst for the notification
	spawnUIParticles(color, 8)
end

-- Register global function for CatchingMinigame
UIManager.Register("PlayEncounterFlash", playEncounterFlash)

-- Listen for rare sighting announcements from other players
local StudEvents = ReplicatedStorage:FindFirstChild("StudEvents")
if StudEvents then
	local encounterResult = StudEvents:FindFirstChild("EncounterResult")
	if encounterResult then
		encounterResult.OnClientEvent:Connect(function(data)
			if data and data.type == "rareSighting" then
				showSightingNotification(data.playerName, data.studName, data.rarity)
			end
		end)
	end
end

print("[RareEncounterAlert] Initialized - rare encounter effects ready")