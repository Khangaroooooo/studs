-- ProfileUI: shown when you click a player (ProfileSystem ClickDetector),
-- including yourself. Displays their name, equipped stud, and collection
-- stats, with TRADE and BATTLE buttons (hidden on your own profile) that
-- fire the TradeSystem / PvPSystem remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local profileEvent = StudEvents:WaitForChild("ProfileData", 30)
if not profileEvent then return end
-- Trade/PvP remotes are created by their systems at startup
local tradeAction = StudEvents:WaitForChild("TradeAction", 30)
local pvpAction = StudEvents:WaitForChild("PvPAction", 30)

local BG = Color3.fromRGB(25, 25, 35)
local HEADER = Color3.fromRGB(40, 40, 55)
local GOLD = Color3.fromRGB(255, 200, 50)
local TEXT = Color3.fromRGB(230, 230, 230)
local MUTED = Color3.fromRGB(150, 150, 170)
local GREEN = Color3.fromRGB(60, 160, 90)
local RED = Color3.fromRGB(190, 70, 60)

local currentProfile = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ProfileUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 300, 0, 330)
panel.Position = UDim2.new(0.5, -150, 0.5, -165)
panel.BackgroundColor3 = BG
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 80, 100)
stroke.Thickness = 2
stroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = HEADER
header.BorderSizePixel = 0
header.Parent = panel

local nameLbl = Instance.new("TextLabel")
nameLbl.Size = UDim2.new(1, -54, 1, 0)
nameLbl.Position = UDim2.new(0, 12, 0, 0)
nameLbl.BackgroundTransparency = 1
nameLbl.TextColor3 = GOLD
nameLbl.TextSize = 17
nameLbl.Font = Enum.Font.GothamBold
nameLbl.TextXAlignment = Enum.TextXAlignment.Left
nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
nameLbl.Parent = header

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -38, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.TextSize = 16
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header

-- Equipped stud card
local studCard = Instance.new("Frame")
studCard.Size = UDim2.new(1, -24, 0, 84)
studCard.Position = UDim2.new(0, 12, 0, 54)
studCard.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
studCard.BorderSizePixel = 0
studCard.Parent = panel

local studColor = Instance.new("Frame")
studColor.Size = UDim2.new(0, 56, 0, 56)
studColor.Position = UDim2.new(0, 12, 0, 14)
studColor.BorderSizePixel = 0
studColor.Parent = studCard

local studColorStroke = Instance.new("UIStroke")
studColorStroke.Color = Color3.fromRGB(10, 8, 14)
studColorStroke.Thickness = 2
studColorStroke.Parent = studColor

local studName = Instance.new("TextLabel")
studName.Size = UDim2.new(1, -88, 0, 22)
studName.Position = UDim2.new(0, 80, 0, 12)
studName.BackgroundTransparency = 1
studName.TextColor3 = TEXT
studName.TextSize = 15
studName.Font = Enum.Font.GothamBold
studName.TextXAlignment = Enum.TextXAlignment.Left
studName.TextTruncate = Enum.TextTruncate.AtEnd
studName.Parent = studCard

local studMeta = Instance.new("TextLabel")
studMeta.Size = UDim2.new(1, -88, 0, 18)
studMeta.Position = UDim2.new(0, 80, 0, 34)
studMeta.BackgroundTransparency = 1
studMeta.TextColor3 = MUTED
studMeta.TextSize = 12
studMeta.Font = Enum.Font.Gotham
studMeta.TextXAlignment = Enum.TextXAlignment.Left
studMeta.Parent = studCard

local studNature = Instance.new("TextLabel")
studNature.Size = UDim2.new(1, -88, 0, 16)
studNature.Position = UDim2.new(0, 80, 0, 52)
studNature.BackgroundTransparency = 1
studNature.TextColor3 = MUTED
studNature.TextSize = 11
studNature.Font = Enum.Font.Gotham
studNature.TextXAlignment = Enum.TextXAlignment.Left
studNature.Parent = studCard

-- Stats rows
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(1, -24, 0, 96)
statsFrame.Position = UDim2.new(0, 12, 0, 148)
statsFrame.BackgroundTransparency = 1
statsFrame.Parent = panel

local statLabels = {}
for i = 1, 4 do
	local row = Instance.new("TextLabel")
	row.Size = UDim2.new(1, 0, 0, 22)
	row.Position = UDim2.new(0, 0, 0, (i - 1) * 24)
	row.BackgroundTransparency = 1
	row.TextColor3 = TEXT
	row.TextSize = 13
	row.Font = Enum.Font.Gotham
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = statsFrame
	statLabels[i] = row
end

-- Action buttons
local tradeBtn = Instance.new("TextButton")
tradeBtn.Size = UDim2.new(0.48, 0, 0, 40)
tradeBtn.Position = UDim2.new(0, 12, 1, -52)
tradeBtn.BackgroundColor3 = GREEN
tradeBtn.Text = "🔄 TRADE"
tradeBtn.TextColor3 = Color3.new(1, 1, 1)
tradeBtn.TextSize = 15
tradeBtn.Font = Enum.Font.GothamBold
tradeBtn.BorderSizePixel = 0
tradeBtn.Parent = panel

local battleBtn = Instance.new("TextButton")
battleBtn.Size = UDim2.new(0.48, 0, 0, 40)
battleBtn.Position = UDim2.new(0.52, 0, 1, -52)
battleBtn.BackgroundColor3 = RED
battleBtn.Text = "⚔️ BATTLE"
battleBtn.TextColor3 = Color3.new(1, 1, 1)
battleBtn.TextSize = 15
battleBtn.Font = Enum.Font.GothamBold
battleBtn.BorderSizePixel = 0
battleBtn.Parent = panel

local function closeProfile()
	panel.Visible = false
	currentProfile = nil
end

profileEvent.OnClientEvent:Connect(function(profile)
	if type(profile) ~= "table" then return end
	currentProfile = profile

	nameLbl.Text = profile.displayName .. " (@" .. profile.name .. ")"

	if profile.equipped then
		local eq = profile.equipped
		local stud = StudData.GetStudById(eq.id)
		local color = stud and StudData.GetStudColor(stud) or Color3.fromRGB(120, 120, 120)
		if eq.isShiny then
			color = StudData.GetShinyColor(color)
		end
		studColor.BackgroundColor3 = color
		studName.Text = (eq.isShiny and "✨ " or "") .. eq.name .. "  Lv" .. (eq.level or 1)
		studMeta.Text = eq.studType .. " · " .. eq.rarity
		local nature = eq.nature and StudData.GetNature(eq.nature)
		studNature.Text = nature and ("Nature: " .. nature.name) or ""
	else
		studColor.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		studName.Text = "No equipped Stud"
		studMeta.Text = ""
		studNature.Text = ""
	end

	statLabels[1].Text = "📦 Total caught: " .. (profile.totalCaught or 0)
	statLabels[2].Text = "📖 Dex: " .. (profile.uniqueCount or 0) .. "/" .. (profile.maxSpecies or 28)
	statLabels[3].Text = "✨ Shinies: " .. (profile.shinyCount or 0)
	statLabels[4].Text = "🔥 Catch streak: " .. (profile.catchStreak or 0)

	-- No Trade/Battle with yourself
	local isSelf = profile.userId == player.UserId
	tradeBtn.Visible = not isSelf
	battleBtn.Visible = not isSelf

	panel.Visible = true
end)

closeBtn.MouseButton1Click:Connect(closeProfile)

tradeBtn.MouseButton1Click:Connect(function()
	if currentProfile and tradeAction then
		tradeAction:FireServer("request", currentProfile.userId)
		closeProfile()
	end
end)

battleBtn.MouseButton1Click:Connect(function()
	if currentProfile and pvpAction then
		pvpAction:FireServer("challenge", currentProfile.userId)
		closeProfile()
	end
end)

UIManager.Register("CloseProfile", closeProfile)

print("[ProfileUI] Initialized")
