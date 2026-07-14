-- TitleOverhead: shows a player's equipped dex-completion title (the
-- "DexTitle" attribute set by SaveManager, e.g. "Friend of Steve") on a
-- small billboard above their character's head.

local Players = game:GetService("Players")

local GOLD = Color3.fromRGB(255, 220, 100)

local function updateTitle(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end

	local title = player:GetAttribute("DexTitle")
	local existing = head:FindFirstChild("TitleOverhead")

	if not title or title == "" then
		if existing then existing:Destroy() end
		return
	end

	if not existing then
		existing = Instance.new("BillboardGui")
		existing.Name = "TitleOverhead"
		existing.Size = UDim2.new(0, 200, 0, 24)
		existing.StudsOffset = Vector3.new(0, 2.4, 0) -- above the name display
		existing.AlwaysOnTop = false
		existing.MaxDistance = 60
		existing.Parent = head

		local label = Instance.new("TextLabel")
		label.Name = "TitleText"
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = GOLD
		label.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
		label.TextStrokeTransparency = 0.3
		label.Font = Enum.Font.GothamBold
		label.TextSize = 14
		label.Parent = existing
	end

	local label = existing:FindFirstChild("TitleText")
	if label then
		label.Text = "✦ " .. title .. " ✦"
	end
end

local function onPlayerAdded(player)
	player:GetAttributeChangedSignal("DexTitle"):Connect(function()
		updateTitle(player)
	end)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head", 10)
		updateTitle(player)
	end)
	if player.Character then
		updateTitle(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[TitleOverhead] Initialized")
