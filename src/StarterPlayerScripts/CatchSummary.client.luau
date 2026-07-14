if true then return end -- [Disabled] Consolidated into CatchResultUI
-- CatchSummary: Shows a detailed popup after each catch with rewards breakdown
-- Displays stud info, coins earned, and evoPoints for duplicates

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CatchSummary"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local COIN_REWARDS = { Common = 10, Uncommon = 25, Rare = 50, Legendary = 100 }
local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(50, 200, 50),
	Rare = Color3.fromRGB(50, 100, 255),
	Legendary = Color3.fromRGB(255, 200, 0),
}

local function showCatchSummary(studId, isNew, isShiny)
	local stud = StudData.GetStudById(studId)
	if not stud then return end

	local typeData = StudData.Types[stud.studType]
	local rarityColor = RARITY_COLORS[stud.rarity] or RARITY_COLORS.Common
	local coinReward = COIN_REWARDS[stud.rarity] or 10
	if not isNew then coinReward = math.floor(coinReward * 0.5) end

	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "CatchSummary_" .. studId
	panel.Size = UDim2.new(0, 300, 0, 200)
	panel.Position = UDim2.new(0.5, -150, 0.5, -100)
	panel.BackgroundColor3 = Color3.fromRGB(20, 20, 40)
	panel.BackgroundTransparency = 0.05
	panel.BorderSizePixel = 0
	panel.ZIndex = 30
	panel.Parent = screenGui



	local panelStroke = Instance.new("UIStroke")
	panelStroke.Color = rarityColor
	panelStroke.Thickness = 2
	panelStroke.Transparency = 0.2
	panelStroke.Parent = panel

	-- Header
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 36)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 55)
	header.BorderSizePixel = 0
	header.Parent = panel



	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(1, -10, 1, 0)
	headerLabel.Position = UDim2.new(0, 10, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = isNew and "New Stud Caught!" or "Duplicate Caught!"
	headerLabel.TextColor3 = isNew and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(180, 180, 200)
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 16
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Parent = header

	-- Stud info section
	local studInfoFrame = Instance.new("Frame")
	studInfoFrame.Size = UDim2.new(1, -20, 0, 50)
	studInfoFrame.Position = UDim2.new(0, 10, 0, 42)
	studInfoFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	studInfoFrame.BackgroundTransparency = 0.3
	studInfoFrame.BorderSizePixel = 0
	studInfoFrame.Parent = panel



	-- Type color bar
	local colorBar = Instance.new("Frame")
	colorBar.Size = UDim2.new(0, 4, 1, -8)
	colorBar.Position = UDim2.new(0, 4, 0, 4)
	colorBar.BackgroundColor3 = typeData and typeData.color or Color3.fromRGB(200, 200, 200)
	colorBar.BorderSizePixel = 0
	colorBar.Parent = studInfoFrame

	-- Stud name
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(0.7, 0, 0.5, 0)
	nameLabel.Position = UDim2.new(0, 14, 0, 2)
	nameLabel.BackgroundTransparency = 1
	local displayName = stud.name
	if isShiny then displayName = displayName .. " (Shiny!)" end
	nameLabel.Text = (typeData and typeData.icon or "?") .. " " .. displayName
	nameLabel.TextColor3 = isShiny and Color3.fromRGB(255, 215, 0) or (typeData and typeData.color or Color3.fromRGB(255, 255, 255))
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = studInfoFrame

	-- Rarity + type
	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(0.7, 0, 0.5, 0)
	rarityLabel.Position = UDim2.new(0, 14, 0.5, 0)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Text = stud.rarity .. " " .. stud.studType
	rarityLabel.TextColor3 = rarityColor
	rarityLabel.Font = Enum.Font.Gotham
	rarityLabel.TextSize = 12
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = studInfoFrame

	-- Rewards section
	local rewardsFrame = Instance.new("Frame")
	rewardsFrame.Size = UDim2.new(1, -20, 0, 70)
	rewardsFrame.Position = UDim2.new(0, 10, 0, 98)
	rewardsFrame.BackgroundTransparency = 1
	rewardsFrame.Parent = panel

	local rewardsLayout = Instance.new("UIListLayout")
	rewardsLayout.FillDirection = Enum.FillDirection.Vertical
	rewardsLayout.Padding = UDim.new(0, 4)
	rewardsLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rewardsLayout.Parent = rewardsFrame

	-- Coin reward
	local coinRow = Instance.new("Frame")
	coinRow.Size = UDim2.new(1, 0, 0, 22)
	coinRow.BackgroundTransparency = 1
	coinRow.LayoutOrder = 1
	coinRow.Parent = rewardsFrame

	local coinIcon = Instance.new("TextLabel")
	coinIcon.Size = UDim2.new(0, 24, 1, 0)
	coinIcon.BackgroundTransparency = 1
	coinIcon.Text = "💰"
	coinIcon.TextSize = 14
	coinIcon.Parent = coinRow

	local coinText = Instance.new("TextLabel")
	coinText.Size = UDim2.new(0.5, 0, 1, 0)
	coinText.Position = UDim2.new(0, 26, 0, 0)
	coinText.BackgroundTransparency = 1
	coinText.Text = "Coins"
	coinText.TextColor3 = Color3.fromRGB(200, 200, 220)
	coinText.Font = Enum.Font.Gotham
	coinText.TextSize = 12
	coinText.TextXAlignment = Enum.TextXAlignment.Left
	coinText.Parent = coinRow

	local coinValue = Instance.new("TextLabel")
	coinValue.Size = UDim2.new(0.4, 0, 1, 0)
	coinValue.Position = UDim2.new(0.6, 0, 0, 0)
	coinValue.BackgroundTransparency = 1
	coinValue.Text = "+" .. tostring(coinReward)
	coinValue.TextColor3 = Color3.fromRGB(255, 215, 0)
	coinValue.Font = Enum.Font.GothamBold
	coinValue.TextSize = 13
	coinValue.TextXAlignment = Enum.TextXAlignment.Right
	coinValue.Parent = coinRow

	-- EvoPoints reward (only for duplicates)
	if not isNew then
		local evoRow = Instance.new("Frame")
		evoRow.Size = UDim2.new(1, 0, 0, 22)
		evoRow.BackgroundTransparency = 1
		evoRow.LayoutOrder = 2
		evoRow.Parent = rewardsFrame

		local evoIcon = Instance.new("TextLabel")
		evoIcon.Size = UDim2.new(0, 24, 1, 0)
		evoIcon.BackgroundTransparency = 1
		evoIcon.Text = "\226\156\168"
		evoIcon.TextSize = 14
		evoIcon.Parent = evoRow

		local evoText = Instance.new("TextLabel")
		evoText.Size = UDim2.new(0.5, 0, 1, 0)
		evoText.Position = UDim2.new(0, 26, 0, 0)
		evoText.BackgroundTransparency = 1
		evoText.Text = "EvoPoints (" .. stud.studType .. ")"
		evoText.TextColor3 = Color3.fromRGB(200, 200, 220)
		evoText.Font = Enum.Font.Gotham
		evoText.TextSize = 12
		evoText.TextXAlignment = Enum.TextXAlignment.Left
		evoText.Parent = evoRow

		local evoValue = Instance.new("TextLabel")
		evoValue.Size = UDim2.new(0.4, 0, 1, 0)
		evoValue.Position = UDim2.new(0.6, 0, 0, 0)
		evoValue.BackgroundTransparency = 1
		evoValue.Text = "+1"
		evoValue.TextColor3 = Color3.fromRGB(100, 200, 255)
		evoValue.Font = Enum.Font.GothamBold
		evoValue.TextSize = 13
		evoValue.TextXAlignment = Enum.TextXAlignment.Right
		evoValue.Parent = evoRow
	end

	-- Shiny bonus indicator
	if isShiny then
		local shinyRow = Instance.new("Frame")
		shinyRow.Size = UDim2.new(1, 0, 0, 22)
		shinyRow.BackgroundTransparency = 1
		shinyRow.LayoutOrder = 3
		shinyRow.Parent = rewardsFrame

		local shinyIcon = Instance.new("TextLabel")
		shinyIcon.Size = UDim2.new(0, 24, 1, 0)
		shinyIcon.BackgroundTransparency = 1
		shinyIcon.Text = "\226\173\144"
		shinyIcon.TextSize = 14
		shinyIcon.Parent = shinyRow

		local shinyText = Instance.new("TextLabel")
		shinyText.Size = UDim2.new(0.5, 0, 1, 0)
		shinyText.Position = UDim2.new(0, 26, 0, 0)
		shinyText.BackgroundTransparency = 1
		shinyText.Text = "Shiny Bonus!"
		shinyText.TextColor3 = Color3.fromRGB(255, 215, 0)
		shinyText.Font = Enum.Font.GothamBold
		shinyText.TextSize = 12
		shinyText.TextXAlignment = Enum.TextXAlignment.Left
		shinyText.Parent = shinyRow

		local shinyValue = Instance.new("TextLabel")
		shinyValue.Size = UDim2.new(0.4, 0, 1, 0)
		shinyValue.Position = UDim2.new(0.6, 0, 0, 0)
		shinyValue.BackgroundTransparency = 1
		shinyValue.Text = "5x Coins!"
		shinyValue.TextColor3 = Color3.fromRGB(255, 215, 0)
		shinyValue.Font = Enum.Font.GothamBold
		shinyValue.TextSize = 13
		shinyValue.TextXAlignment = Enum.TextXAlignment.Right
		shinyValue.Parent = shinyRow
	end

	-- Dismiss button
	local dismissBtn = Instance.new("TextButton")
	dismissBtn.Size = UDim2.new(0.6, 0, 0, 28)
	dismissBtn.Position = UDim2.new(0.2, 0, 1, -36)
	dismissBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
	dismissBtn.BackgroundTransparency = 0.2
	dismissBtn.Text = "Nice!"
	dismissBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
	dismissBtn.Font = Enum.Font.GothamBold
	dismissBtn.TextSize = 13
	dismissBtn.BorderSizePixel = 0
	dismissBtn.Parent = panel



	-- Animate in
	panel.Position = UDim2.new(0.5, -150, 0.5, -80)
	panel.Size = UDim2.new(0, 300, 0, 0)
	panel.BackgroundTransparency = 0.5
	panel.ClipsDescendants = true

	local tweenIn = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 300, 0, 200),
		BackgroundTransparency = 0.05,
	})
	tweenIn:Play()

	-- Auto-dismiss after 5 seconds
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

-- Listen for catch success events
local catchSuccessEvent = StudEvents:WaitForChild("CatchSuccess", 15)
if catchSuccessEvent then
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
		showCatchSummary(studId, isNew, isShiny)
	end)
end

print("[CatchSummary] Initialized")