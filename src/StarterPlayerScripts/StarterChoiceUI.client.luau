-- StarterChoiceUI: one-time starter pick on a brand-new save.
-- The server (SaveManager) fires OfferStarter after New Game (or on load if
-- the save somehow never picked one); the choice goes back through the
-- ChooseStarter RemoteFunction, which validates everything server-side.
-- No close button on purpose — a fresh save needs a stud.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

local offerStarterEvent = StudEvents:WaitForChild("OfferStarter")
local chooseStarterFunc = StudEvents:WaitForChild("ChooseStarter")

local GOLD = Color3.fromRGB(255, 220, 100)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StarterChoiceUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 50 -- above the regular HUD
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Dim the world behind the choice
local dim = Instance.new("Frame")
dim.Size = UDim2.new(1, 0, 1, 0)
dim.BackgroundColor3 = Color3.new(0, 0, 0)
dim.BackgroundTransparency = 0.45
dim.BorderSizePixel = 0
dim.Parent = screenGui

local frame = Instance.new("Frame")
frame.Name = "StarterFrame"
frame.Size = UDim2.new(0, 640, 0, 330)
frame.Position = UDim2.new(0.5, -320, 0.5, -165)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
frame.BorderSizePixel = 0
frame.Parent = screenGui

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = GOLD
frameStroke.Thickness = 2
frameStroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Text = "CHOOSE YOUR FIRST STUD"
title.TextColor3 = GOLD
title.Font = Enum.Font.GothamBold
title.TextSize = 22
title.Parent = frame

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, 0, 0, 20)
subtitle.Position = UDim2.new(0, 0, 0, 38)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Your partner for the whole journey. Choose wisely. Or don't — they're all great."
subtitle.TextColor3 = Color3.fromRGB(180, 180, 195)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.Parent = frame

local cardHolder = Instance.new("Frame")
cardHolder.Size = UDim2.new(1, -30, 1, -80)
cardHolder.Position = UDim2.new(0, 15, 0, 66)
cardHolder.BackgroundTransparency = 1
cardHolder.Parent = frame

local choosing = false

local function buildCards()
	for _, child in cardHolder:GetChildren() do
		child:Destroy()
	end

	for i, starterId in ipairs(StudData.Starters) do
		local stud = StudData.GetStudById(starterId)
		if stud then
			local typeData = StudData.Types[stud.studType]
			local color = StudData.GetStudColor(stud)

			local card = Instance.new("TextButton")
			card.Name = stud.id
			card.Size = UDim2.new(0.31, 0, 1, 0)
			card.Position = UDim2.new((i - 1) * 0.345, 0, 0, 0)
			card.BackgroundColor3 = Color3.fromRGB(35, 35, 52)
			card.Text = ""
			card.AutoButtonColor = true
			card.BorderSizePixel = 0
			card.Parent = cardHolder

			local cardStroke = Instance.new("UIStroke")
			cardStroke.Color = color
			cardStroke.Thickness = 2
			cardStroke.Parent = card

			local tile = Instance.new("Frame")
			tile.Size = UDim2.new(0, 70, 0, 70)
			tile.Position = UDim2.new(0.5, -35, 0, 14)
			tile.BackgroundColor3 = color
			tile.BorderSizePixel = 0
			tile.Parent = card

			local initial = Instance.new("TextLabel")
			initial.Size = UDim2.new(1, 0, 1, 0)
			initial.BackgroundTransparency = 1
			initial.Text = stud.name:sub(1, 1)
			initial.TextColor3 = Color3.fromRGB(20, 20, 30)
			initial.Font = Enum.Font.GothamBold
			initial.TextSize = 38
			initial.Parent = tile

			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, 0, 0, 24)
			nameLbl.Position = UDim2.new(0, 0, 0, 90)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = stud.name
			nameLbl.TextColor3 = Color3.new(1, 1, 1)
			nameLbl.Font = Enum.Font.GothamBold
			nameLbl.TextSize = 20
			nameLbl.Parent = card

			local typeLbl = Instance.new("TextLabel")
			typeLbl.Size = UDim2.new(1, 0, 0, 18)
			typeLbl.Position = UDim2.new(0, 0, 0, 114)
			typeLbl.BackgroundTransparency = 1
			typeLbl.Text = (typeData and typeData.icon or "") .. " " .. stud.studType
			typeLbl.TextColor3 = color
			typeLbl.Font = Enum.Font.GothamBold
			typeLbl.TextSize = 14
			typeLbl.Parent = card

			local descLbl = Instance.new("TextLabel")
			descLbl.Size = UDim2.new(1, -16, 0, 54)
			descLbl.Position = UDim2.new(0, 8, 0, 136)
			descLbl.BackgroundTransparency = 1
			descLbl.Text = stud.description
			descLbl.TextColor3 = Color3.fromRGB(190, 190, 205)
			descLbl.Font = Enum.Font.Gotham
			descLbl.TextSize = 12
			descLbl.TextWrapped = true
			descLbl.TextYAlignment = Enum.TextYAlignment.Top
			descLbl.Parent = card

			local statsLbl = Instance.new("TextLabel")
			statsLbl.Size = UDim2.new(1, 0, 0, 16)
			statsLbl.Position = UDim2.new(0, 0, 1, -44)
			statsLbl.BackgroundTransparency = 1
			statsLbl.Text = "ATK " .. stud.stats.attack .. " · DEF " .. stud.stats.defense .. " · SPD " .. stud.stats.speed
			statsLbl.TextColor3 = Color3.fromRGB(160, 160, 175)
			statsLbl.Font = Enum.Font.Gotham
			statsLbl.TextSize = 12
			statsLbl.Parent = card

			local pickLbl = Instance.new("TextLabel")
			pickLbl.Size = UDim2.new(1, 0, 0, 20)
			pickLbl.Position = UDim2.new(0, 0, 1, -24)
			pickLbl.BackgroundTransparency = 1
			pickLbl.Text = "CHOOSE"
			pickLbl.TextColor3 = GOLD
			pickLbl.Font = Enum.Font.GothamBold
			pickLbl.TextSize = 14
			pickLbl.Parent = card

			card.MouseButton1Click:Connect(function()
				if choosing then return end
				choosing = true
				pickLbl.Text = "..."
				local ok, result = pcall(function()
					return chooseStarterFunc:InvokeServer(stud.id)
				end)
				if ok and result and result.success then
					pickLbl.Text = "YOURS!"
					task.wait(0.6)
					screenGui.Enabled = false
				else
					-- already_started etc: nothing to pick anymore
					if ok and result and result.reason == "already_started" then
						screenGui.Enabled = false
					else
						pickLbl.Text = "CHOOSE"
					end
					choosing = false
				end
			end)
		end
	end
end

offerStarterEvent.OnClientEvent:Connect(function()
	if screenGui.Enabled then return end
	choosing = false
	buildCards()
	screenGui.Enabled = true
	frame.Position = UDim2.new(0.5, -320, 0.6, -165)
	TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, -320, 0.5, -165),
	}):Play()
end)

print("[StarterChoiceUI] Initialized")
