-- HUD: Shows basic info and hints during gameplay
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local player = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local playerGui = player:WaitForChild("PlayerGui")
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GameHUD"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── HUD RAIL (top-right) ────────────────────────────────────────────────
-- Coins pill sits at the top; the Quest (QuestUI) and Settings (SettingsMenu)
-- buttons stack directly below it in the same column, sharing this style:
-- retro cartridge card — square corners, thick black outline, offset drop
-- shadow, gold accents. Column right edge = -12px.
local coinsBadge = UITheme.CreateRetroPanel({
	name = "CoinsBadge",
	size = UDim2.new(0, 128, 0, 36),
	pos = UDim2.new(1, -140, 0, 12),
	bg = UITheme.C_PANEL,
	parent = screenGui,
	shadowOffset = 4,
})

local coinIcon = UITheme.CreateIconBadge({
	name = "CoinIcon",
	size = UDim2.new(0, 24, 0, 24),
	pos = UDim2.new(0, 6, 0.5, -12),
	text = "$",
	color = UITheme.C_ACCENT,
	parent = coinsBadge,
})

local coinsLabel = UITheme.CreateLabel({
	name = "CoinsText",
	size = UDim2.new(1, -38, 1, 0),
	pos = UDim2.new(0, 34, 0, 0),
	text = "0",
	color = UITheme.C_ACCENT,
	font = UITheme.F_PIXEL,
	ts = 13,
	xa = Enum.TextXAlignment.Left,
	parent = coinsBadge,
})
-- Sprint indicator (bottom left)
local sprintBadge = Instance.new("Frame")
sprintBadge.Name = "SprintBadge"
sprintBadge.Size = UDim2.new(0.08, 0, 0.04, 0)
sprintBadge.Position = UDim2.new(0.01, 0, 0.96, 0)
sprintBadge.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
sprintBadge.BackgroundTransparency = 0.3
sprintBadge.BorderSizePixel = 0
sprintBadge.Parent = screenGui

local sprintLabel = Instance.new("TextLabel")
sprintLabel.Name = "SprintText"
sprintLabel.Size = UDim2.new(1, 0, 1, 0)
sprintLabel.BackgroundTransparency = 1
sprintLabel.Text = "Sprint"
sprintLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
sprintLabel.Font = Enum.Font.Arcade
sprintLabel.TextSize = 14
sprintLabel.Parent = sprintBadge
-- Monitor sprint state
-- Event-driven instead of a 10x/sec polling loop: the badge only needs to
-- change when Shift actually goes down or up, which InputBegan/InputEnded
-- tell us for free. Zero per-frame cost while idle.
local UserInputService = game:GetService("UserInputService")

local function setSprintBadge(active)
	if active then
		sprintLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
		sprintBadge.BackgroundTransparency = 0.1
	else
		sprintLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
		sprintBadge.BackgroundTransparency = 0.3
	end
end

UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then setSprintBadge(true) end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then setSprintBadge(false) end
end)
setSprintBadge(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))

-- Update coins periodically

-- Listen for coin updates from server
StudEvents.UpdateCoins.OnClientEvent:Connect(function(coins)
	coinsLabel.Text = tostring(coins)
end)
-- Handle house rest bonus
player:GetAttributeChangedSignal("HouseRestBonus"):Connect(function()
	if player:GetAttribute("HouseRestBonus") == true then
		-- Show a brief notification
		local notif = Instance.new("TextLabel")
		notif.Name = "RestNotif"
		notif.Size = UDim2.new(0.3, 0, 0, 40)
		notif.Position = UDim2.new(0.35, 0, 0.15, 0)
		notif.BackgroundColor3 = Color3.fromRGB(40, 80, 40)
		notif.TextColor3 = Color3.fromRGB(100, 255, 100)
		notif.Text = "Rested at home! Cooldown reset."
		notif.Font = Enum.Font.Arcade
		notif.TextSize = 16
		notif.Parent = screenGui
		task.delay(2, function()
			if notif then notif:Destroy() end
		end)
	end
end)
-- Removed the every-5s GetPlayerStats:InvokeServer() polling loop. The server
-- already pushes coin changes via UpdateCoins (handled above), so the poll was
-- a redundant remote round-trip per player every 5 seconds — pure network/server
-- waste. We just do ONE initial fetch so the badge is correct on load.
task.spawn(function()
	local ok, stats = pcall(function()
		return StudEvents.GetPlayerStats:InvokeServer()
	end)
	if ok and stats then
		coinsLabel.Text = tostring(stats.coins or 0)
	end
end)
-- Buff indicators (bottom left, above sprint badge)
local buffFrame = Instance.new("Frame")
buffFrame.Name = "BuffFrame"
buffFrame.Size = UDim2.new(0, 200, 0, 24)
buffFrame.Position = UDim2.new(0.01, 0, 0.91, 0)
buffFrame.BackgroundTransparency = 1
buffFrame.Parent = screenGui
local buffLayout = Instance.new("UIListLayout")
buffLayout.FillDirection = Enum.FillDirection.Horizontal
buffLayout.Padding = UDim.new(0, 4)
buffLayout.SortOrder = Enum.SortOrder.LayoutOrder
buffLayout.Parent = buffFrame
local function updateBuffDisplay()
	for _, child in buffFrame:GetChildren() do
		if child:IsA("Frame") then child:Destroy() end
	end
	local buffs = {
		{attr = "CatchBoost", name = "🎯 Catch+", color = Color3.fromRGB(80, 200, 80)},
		{attr = "LuckyCharm", name = "🍀 Lucky", color = Color3.fromRGB(200, 200, 50)},
		{attr = "StudLure", name = "🧲 Lure", color = Color3.fromRGB(100, 150, 255)},
	}
	local order = 0
	for _, buff in ipairs(buffs) do
		if player:GetAttribute(buff.attr) then
			order = order + 1
			local badge = Instance.new("Frame")
			badge.Size = UDim2.new(0, 66, 0, 22)
			badge.BackgroundColor3 = buff.color
			badge.BorderSizePixel = 0
			badge.LayoutOrder = order
			badge.Parent = buffFrame
			UITheme.ApplyStroke(badge, UITheme.C_BORDER, 2)
			local badgeLabel = Instance.new("TextLabel")
			badgeLabel.Size = UDim2.new(1, -4, 1, -4)
			badgeLabel.Position = UDim2.new(0, 2, 0, 2)
			badgeLabel.BackgroundTransparency = 1
			badgeLabel.Text = buff.name
			badgeLabel.TextColor3 = UITheme.C_BORDER
			badgeLabel.TextScaled = true
			badgeLabel.Font = UITheme.F_PIXEL
			badgeLabel.Parent = badge
		end
	end
end
-- Monitor buff attribute changes
for _, attr in ipairs({"CatchBoost", "LuckyCharm", "StudLure"}) do
	player:GetAttributeChangedSignal(attr):Connect(updateBuffDisplay)
end
-- Initial check
task.delay(3, updateBuffDisplay)

-- (Catch streak HUD removed by request)

print("[GameHUD] Initialized")