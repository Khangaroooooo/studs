--[[
	CatchResultUI.lua — Consolidated catch celebration + summary popup
	Replaces the separate CatchCelebration and CatchSummary scripts.

	On a successful catch, this script:
	  1. Plays a white screen flash + sparkle burst (celebration)
	  2. Shows a "NEW!" badge if it's a first-time catch
	  3. Displays a detailed summary panel with stud info and rewards

	Registers PlayCatchCelebration with UIManager for other scripts to call.
	Listens to StudEvents.CatchSuccess for the summary popup.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

-- ─── CONSTANTS ───────────────────────────────────────────────────────────
local COIN_REWARDS = { Common = 10, Uncommon = 25, Rare = 50, Legendary = 100 }

-- ─── SCREEN GUI ──────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchResultUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ─── CELEBRATION ELEMENTS ───────────────────────────────────────────────

-- White flash frame
local flashFrame = Instance.new("Frame")
flashFrame.Name = "Flash"
flashFrame.Size = UDim2.new(1, 0, 1, 0)
flashFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 200)
flashFrame.BackgroundTransparency = 1
flashFrame.ZIndex = 50
flashFrame.Parent = screenGui

-- Sparkle particle container
local sparkleContainer = Instance.new("Frame")
sparkleContainer.Name = "SparkleContainer"
sparkleContainer.Size = UDim2.new(0.4, 0, 0.35, 0)
sparkleContainer.Position = UDim2.new(0.3, 0, 0.05, 0)
sparkleContainer.BackgroundTransparency = 1
sparkleContainer.Parent = screenGui

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

-- "NEW!" badge for first-time catches
local newBadge = Instance.new("TextLabel")
newBadge.Name = "NewBadge"
newBadge.Size = UDim2.new(0.15, 0, 0.06, 0)
newBadge.Position = UDim2.new(0.55, 0, 0.35, 0)
newBadge.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
newBadge.Text = "NEW!"
newBadge.TextColor3 = Color3.fromRGB(40, 20, 0)
newBadge.Font = Enum.Font.Arcade
newBadge.TextSize = 20
newBadge.BackgroundTransparency = 1
newBadge.TextTransparency = 1
newBadge.ZIndex = 52
newBadge.Parent = screenGui

-- ─── CELEBRATION EFFECTS ────────────────────────────────────────────────

local function playCelebration(isNew)
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

-- ─── SUMMARY POPUP ──────────────────────────────────────────────────────

local function showSummary(studId, isNew, isShiny)
	local stud = StudData.GetStudById(studId)
	if not stud then return end

	local typeData = StudData.Types[stud.studType]
	local rarityColor = UITheme.RARITY_COLORS[stud.rarity] or UITheme.RARITY_COLORS.Common
	local coinReward = COIN_REWARDS[stud.rarity] or 10
	if not isNew then coinReward = math.floor(coinReward * 0.5) end

	-- Main panel
	local panel = UITheme.CreateFrame({
		name = "CatchSummary_" .. studId,
		size = UDim2.new(0, 300, 0, 200),
		pos = UDim2.new(0.5, -150, 0.5, -100),
		bg = Color3.fromRGB(20, 20, 40),
		transparency = 0.05,
		zIndex = 30,
		parent = screenGui,
		stroke = true,
		strokeColor = rarityColor,
		strokeThickness = 2,
		strokeTransparency = 0.2,
	})

	-- Header
	local header = UITheme.CreateFrame({
		name = "Header",
		size = UDim2.new(1, 0, 0, 36),
		bg = Color3.fromRGB(30, 30, 55),
		parent = panel,
	})

	UITheme.CreateLabel({
		name = "HeaderLabel",
		size = UDim2.new(1, -10, 1, 0),
		pos = UDim2.new(0, 10, 0, 0),
		text = isNew and "New Stud Caught!" or "Duplicate Caught!",
		color = isNew and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(180, 180, 200),
		font = Enum.Font.Arcade,
		ts = 16,
		xa = Enum.TextXAlignment.Left,
		parent = header,
	})

	-- Stud info section
	local studInfoFrame = UITheme.CreateFrame({
		name = "StudInfo",
		size = UDim2.new(1, -20, 0, 50),
		pos = UDim2.new(0, 10, 0, 42),
		bg = Color3.fromRGB(30, 30, 50),
		transparency = 0.3,
		parent = panel,
	})

	-- Type color bar
	local colorBar = UITheme.CreateFrame({
		name = "ColorBar",
		size = UDim2.new(0, 4, 1, -8),
		pos = UDim2.new(0, 4, 0, 4),
		bg = typeData and typeData.color or Color3.fromRGB(200, 200, 200),
		parent = studInfoFrame,
	})

	-- Stud name
	local displayName = stud.name
	if isShiny then displayName = displayName .. " (Shiny!)" end
	UITheme.CreateLabel({
		name = "NameLabel",
		size = UDim2.new(0.7, 0, 0.5, 0),
		pos = UDim2.new(0, 14, 0, 2),
		text = (typeData and typeData.icon or "?") .. " " .. displayName,
		color = isShiny and Color3.fromRGB(255, 215, 0) or (typeData and typeData.color or Color3.fromRGB(255, 255, 255)),
		font = Enum.Font.Arcade,
		ts = 15,
		xa = Enum.TextXAlignment.Left,
		parent = studInfoFrame,
	})

	-- Rarity + type
	UITheme.CreateLabel({
		name = "RarityLabel",
		size = UDim2.new(0.7, 0, 0.5, 0),
		pos = UDim2.new(0, 14, 0.5, 0),
		text = stud.rarity .. " " .. stud.studType,
		color = rarityColor,
		font = Enum.Font.Arcade,
		ts = 12,
		xa = Enum.TextXAlignment.Left,
		parent = studInfoFrame,
	})

	-- Rewards section
	local rewardsFrame = UITheme.CreateFrame({
		name = "Rewards",
		size = UDim2.new(1, -20, 0, 70),
		pos = UDim2.new(0, 10, 0, 98),
		transparency = 1,
		parent = panel,
	})

	local rewardsLayout = Instance.new("UIListLayout")
	rewardsLayout.FillDirection = Enum.FillDirection.Vertical
	rewardsLayout.Padding = UDim.new(0, 4)
	rewardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardsLayout.Parent = rewardsFrame

	-- Helper to create a reward row
	local function makeRewardRow(layoutOrder, icon, label, value, valueColor)
		local row = UITheme.CreateFrame({
			name = "RewardRow_" .. layoutOrder,
			size = UDim2.new(1, 0, 0, 22),
			transparency = 1,
			layoutOrder = layoutOrder,
			parent = rewardsFrame,
		})

		UITheme.CreateLabel({
			name = "Icon",
			size = UDim2.new(0, 24, 1, 0),
			text = icon,
			ts = 14,
			parent = row,
		})

		UITheme.CreateLabel({
			name = "Label",
			size = UDim2.new(0.5, 0, 1, 0),
			pos = UDim2.new(0, 26, 0, 0),
			text = label,
			color = Color3.fromRGB(200, 200, 220),
			font = Enum.Font.Arcade,
			ts = 12,
			xa = Enum.TextXAlignment.Left,
			parent = row,
		})

		UITheme.CreateLabel({
			name = "Value",
			size = UDim2.new(0.4, 0, 1, 0),
			pos = UDim2.new(0.6, 0, 0, 0),
			text = value,
			color = valueColor or Color3.fromRGB(255, 215, 0),
			font = Enum.Font.Arcade,
			ts = 13,
			xa = Enum.TextXAlignment.Right,
			parent = row,
		})
	end

	-- Coin reward
	makeRewardRow(1, "\240\159\165\136", "Coins", "+" .. tostring(coinReward))

	-- EvoPoints reward (duplicates only)
	if not isNew then
		makeRewardRow(2, "\226\156\168", "EvoPoints (" .. stud.studType .. ")", "+1", Color3.fromRGB(100, 200, 255))
	end

	-- Shiny bonus indicator
	if isShiny then
		makeRewardRow(3, "\226\173\144", "Shiny Bonus!", "5x Coins!", Color3.fromRGB(255, 215, 0))
	end

	-- Dismiss button
	local dismissBtn = UITheme.CreateButton({
		name = "DismissBtn",
		size = UDim2.new(0.6, 0, 0, 28),
		pos = UDim2.new(0.2, 0, 1, -36),
		bg = Color3.fromRGB(50, 50, 80),
		transparency = 0.2,
		text = "Nice!",
		tc = Color3.fromRGB(200, 200, 255),
		font = Enum.Font.Arcade,
		ts = 13,
		parent = panel,
	})

	-- Animate in
	panel.Position = UDim2.new(0.5, -150, 0.5, -80)
	panel.Size = UDim2.new(0, 300, 0, 0)
	panel.BackgroundTransparency = 0.5
	panel.ClipsDescendants = true

	TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 300, 0, 200),
		BackgroundTransparency = 0.05,
	}):Play()

	-- Dismiss logic
	local function dismiss()
		local tweenOut = TweenService:Create(panel, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 300, 0, 0),
			BackgroundTransparency = 1,
		})
		tweenOut:Play()
		tweenOut.Completed:Connect(function()
			panel:Destroy()
		end)
	end

	dismissBtn.MouseButton1Click:Connect(dismiss)
	task.delay(5, dismiss)
end

-- ─── REGISTRATION ────────────────────────────────────────────────────────

-- Register celebration function with UIManager (replaces _G.PlayCatchCelebration)
UIManager.Register("PlayCatchCelebration", playCelebration)

-- ─── EVENT LISTENERS ─────────────────────────────────────────────────────

-- Listen for catch success events to show the summary popup
local catchSuccessEvent = StudEvents:FindFirstChild("CatchSuccess")
if catchSuccessEvent and catchSuccessEvent:IsA("RemoteEvent") then
	catchSuccessEvent.OnClientEvent:Connect(function(studId)
		-- Get current collection to determine if new or duplicate
		local collection = StudEvents.RequestCollection:InvokeServer()
		local count = 0
		for _, caught in ipairs(collection) do
			local id = type(caught) == "table" and caught.id or caught
			if id == studId then count = count + 1 end
		end
		local isNew = count <= 1
		local isShiny = false
		for _, caught in ipairs(collection) do
			if type(caught) == "table" and caught.id == studId and caught.isShiny then
				isShiny = true
				break
			end
		end
		showSummary(studId, isNew, isShiny)
	end)
end

print("[CatchResultUI] Initialized — consolidated celebration + summary")