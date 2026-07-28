-- WorldsUI: 🌍 button on the HUD rail opens a panel listing every island;
-- clicking one plays a short teleport cutscene (fade to black + world title
-- card, then a camera sweep down onto the character at the destination).
-- The server (WorldTeleport.server.luau) owns the actual teleport and the
-- authoritative 5 s cooldown; we mirror the cooldown here for button UX.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

local teleportEvent = StudEvents:WaitForChild("TeleportToWorld", 30)
if not teleportEvent then return end

local COOLDOWN_SECONDS = 5

-- Display order + flavor for each world (keys match Workspace folders and
-- StudData.WorldLevelBands, which supplies the level range shown per row)
local WORLD_INFO = {
	{ key = "Studville",       label = "Studville",        icon = "🏘️", tagline = "Where it all began",  color = Color3.fromRGB(120, 210, 100) },
	{ key = "TidepoolCove",    label = "Tidepool Cove",    icon = "🌊", tagline = "Sun, sand & studs",   color = Color3.fromRGB(90, 200, 235) },
	{ key = "Emberpeak",       label = "Emberpeak",        icon = "🌋", tagline = "Forged in fire",      color = Color3.fromRGB(255, 120, 60) },
	{ key = "VoltWasteland",   label = "Volt Wasteland",   icon = "⚡", tagline = "High voltage ahead",  color = Color3.fromRGB(255, 230, 70) },
	{ key = "CanyonDepths",    label = "Canyon Depths",    icon = "🏜️", tagline = "Carved by time",      color = Color3.fromRGB(230, 160, 90) },
	{ key = "FrostbiteTundra", label = "Frostbite Tundra", icon = "❄️", tagline = "Brave the cold",      color = Color3.fromRGB(150, 215, 255) },
	{ key = "DuskwoodHollow",  label = "Duskwood Hollow",  icon = "🌑", tagline = "Shadows stir here",   color = Color3.fromRGB(170, 120, 220) },
}

local lastTeleport = -math.huge -- os.clock() of last request we sent
local teleporting = false

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WorldsUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ── HUD rail toggle (below quests y60 / gear y112 / trophy y164 / shop y216)
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "WorldsToggle"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(1, -56, 0, 268)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
toggleBtn.BackgroundTransparency = 0.25
toggleBtn.TextColor3 = UITheme.C_ACCENT
toggleBtn.TextSize = 22
toggleBtn.Text = "🌍"
toggleBtn.Font = Enum.Font.Arcade
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = screenGui
UITheme.ApplyStroke(toggleBtn, UITheme.C_BORDER, 2)

-- ── PANEL ───────────────────────────────────────────────────────────────
local PANEL_W, ROW_H, ROW_PAD = 340, 52, 6
local rowCount = #WORLD_INFO
local PANEL_H = 48 + rowCount * (ROW_H + ROW_PAD) + 34

local panel = UITheme.CreateRetroPanel({
	name = "WorldsPanel",
	size = UDim2.new(0, PANEL_W, 0, PANEL_H),
	pos = UDim2.new(0.5, -PANEL_W / 2, 0.5, -PANEL_H / 2),
	bg = UITheme.C_PANEL,
	parent = screenGui,
	visible = false,
	zIndex = 5,
})
panel.Visible = false
-- CreateRetroPanel parents the drop shadow as a SIBLING, so it doesn't follow
-- panel.Visible — hide/show it alongside the panel or it sits on screen forever
local panelShadow = screenGui:FindFirstChild("WorldsPanelShadow")
if panelShadow then panelShadow.Visible = false end

UITheme.CreateLabel({
	name = "Title",
	size = UDim2.new(1, -50, 0, 40),
	pos = UDim2.new(0, 14, 0, 4),
	text = "WORLDS",
	color = UITheme.C_ACCENT,
	font = UITheme.F_PIXEL,
	ts = 18,
	xa = Enum.TextXAlignment.Left,
	zIndex = 6,
	parent = panel,
})

local closeBtn = UITheme.CreateButton({
	name = "Close",
	size = UDim2.new(0, 30, 0, 30),
	pos = UDim2.new(1, -38, 0, 8),
	text = "X",
	bg = UITheme.C_DANGER,
	tc = UITheme.C_WHITE,
	ts = 14,
	strokeColor = UITheme.C_BORDER,
	strokeThickness = 2,
	zIndex = 6,
	parent = panel,
})

-- Footer shows cooldown state ("Ready!" / "Ready in 3s")
local footerLabel = UITheme.CreateLabel({
	name = "Footer",
	size = UDim2.new(1, -20, 0, 22),
	pos = UDim2.new(0, 10, 1, -28),
	text = "",
	color = UITheme.C_SEC,
	font = UITheme.F_BODY,
	ts = 13,
	zIndex = 6,
	parent = panel,
})

local rowButtons = {} -- [key] = TextButton
for i, info in ipairs(WORLD_INFO) do
	local row = UITheme.CreateButton({
		name = info.key .. "Row",
		size = UDim2.new(1, -20, 0, ROW_H),
		pos = UDim2.new(0, 10, 0, 48 + (i - 1) * (ROW_H + ROW_PAD)),
		text = "",
		bg = UITheme.C_BG,
		strokeColor = UITheme.C_BORDER,
		strokeThickness = 2,
		zIndex = 6,
		parent = panel,
	})
	rowButtons[info.key] = row

	UITheme.CreateLabel({
		name = "Icon",
		size = UDim2.new(0, 36, 1, 0),
		pos = UDim2.new(0, 4, 0, 0),
		text = info.icon,
		ts = 22,
		font = Enum.Font.Arcade,
		zIndex = 7,
		parent = row,
	})
	UITheme.CreateLabel({
		name = "WorldName",
		size = UDim2.new(1, -120, 0, 20),
		pos = UDim2.new(0, 44, 0, 7),
		text = info.label,
		color = info.color,
		font = UITheme.F_PIXEL,
		ts = 12,
		xa = Enum.TextXAlignment.Left,
		zIndex = 7,
		parent = row,
	})
	UITheme.CreateLabel({
		name = "Tagline",
		size = UDim2.new(1, -120, 0, 16),
		pos = UDim2.new(0, 44, 0, 29),
		text = info.tagline,
		color = UITheme.C_SEC,
		font = UITheme.F_BODY,
		ts = 12,
		xa = Enum.TextXAlignment.Left,
		zIndex = 7,
		parent = row,
	})
	local band = StudData.WorldLevelBands and StudData.WorldLevelBands[info.key]
	UITheme.CreateLabel({
		name = "Levels",
		size = UDim2.new(0, 70, 1, 0),
		pos = UDim2.new(1, -76, 0, 0),
		text = band and string.format("Lv %d-%d", band.min, band.max) or "",
		color = UITheme.C_ACCENT,
		font = UITheme.F_BODY,
		ts = 12,
		xa = Enum.TextXAlignment.Right,
		zIndex = 7,
		parent = row,
	})
end

-- ── CUTSCENE OVERLAY (own gui so it survives panel close, sits on top) ──
local cutsceneGui = Instance.new("ScreenGui")
cutsceneGui.Name = "WorldsCutscene"
cutsceneGui.ResetOnSpawn = false
cutsceneGui.IgnoreGuiInset = true
cutsceneGui.DisplayOrder = 50
cutsceneGui.Enabled = false
cutsceneGui.Parent = playerGui

local blackout = Instance.new("Frame")
blackout.Name = "Blackout"
blackout.Size = UDim2.new(1, 0, 1, 0)
blackout.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blackout.BackgroundTransparency = 1
blackout.BorderSizePixel = 0
blackout.Parent = cutsceneGui

local cardIcon = UITheme.CreateLabel({
	name = "CardIcon",
	size = UDim2.new(1, 0, 0, 60),
	pos = UDim2.new(0, 0, 0.36, 0),
	text = "",
	ts = 48,
	font = Enum.Font.Arcade,
	parent = blackout,
})
local cardTitle = UITheme.CreateLabel({
	name = "CardTitle",
	size = UDim2.new(1, 0, 0, 34),
	pos = UDim2.new(0, 0, 0.36, 66),
	text = "",
	font = UITheme.F_PIXEL,
	ts = 24,
	parent = blackout,
})
local cardTagline = UITheme.CreateLabel({
	name = "CardTagline",
	size = UDim2.new(1, 0, 0, 22),
	pos = UDim2.new(0, 0, 0.36, 104),
	text = "",
	color = UITheme.C_SEC,
	font = UITheme.F_BODY,
	ts = 16,
	parent = blackout,
})

local function setCardTransparency(t)
	cardIcon.TextTransparency = t
	cardTitle.TextTransparency = t
	cardTagline.TextTransparency = t
end

local function tweenTransparency(obj, prop, target, dur)
	local tween = TweenService:Create(obj, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { [prop] = target })
	tween:Play()
	return tween
end

-- ── PANEL OPEN/CLOSE ────────────────────────────────────────────────────
local isOpen = false

local function updateCooldownUI()
	local remaining = COOLDOWN_SECONDS - (os.clock() - lastTeleport)
	local cooling = remaining > 0
	for _, row in pairs(rowButtons) do
		row.AutoButtonColor = not cooling and not teleporting
		row.BackgroundTransparency = (cooling or teleporting) and 0.5 or 0
	end
	if teleporting then
		footerLabel.Text = "Teleporting..."
	elseif cooling then
		footerLabel.Text = string.format("Ready in %ds", math.ceil(remaining))
	else
		footerLabel.Text = "Pick a destination!"
	end
	return cooling
end

local function closePanel()
	if not isOpen then return end
	isOpen = false
	panel.Visible = false
	if panelShadow then panelShadow.Visible = false end
end

local function openPanel()
	if isOpen then return end
	UIManager.CloseOtherPanels("Worlds")
	isOpen = true
	panel.Visible = true
	if panelShadow then panelShadow.Visible = true end
	updateCooldownUI()
	-- Tick the footer countdown while the panel is open and cooling
	task.spawn(function()
		while isOpen and updateCooldownUI() do
			task.wait(0.25)
		end
	end)
end

UIManager.RegisterPanel("Worlds", closePanel)
toggleBtn.MouseButton1Click:Connect(function()
	if isOpen then closePanel() else openPanel() end
end)
closeBtn.MouseButton1Click:Connect(closePanel)

-- ── TELEPORT + CUTSCENE ─────────────────────────────────────────────────
-- Departure: fade to black with the destination's title card, then ask the
-- server. Arrival (server fired back): sweep the camera down onto the
-- character, fade back in. If the server rejects (cooldown race), a 3 s
-- watchdog fades back in so the player is never stuck on black.
local pendingWorld = nil

local function beginDeparture(info)
	teleporting = true
	pendingWorld = info.key
	lastTeleport = os.clock()
	closePanel()
	UIManager.AcquireLock()

	cardIcon.Text = info.icon
	cardTitle.Text = info.label:upper()
	cardTitle.TextColor3 = info.color
	cardTagline.Text = info.tagline
	setCardTransparency(1)
	blackout.BackgroundTransparency = 1
	cutsceneGui.Enabled = true

	tweenTransparency(blackout, "BackgroundTransparency", 0, 0.4)
	task.wait(0.4)
	tweenTransparency(cardIcon, "TextTransparency", 0, 0.3)
	tweenTransparency(cardTitle, "TextTransparency", 0, 0.3)
	tweenTransparency(cardTagline, "TextTransparency", 0, 0.3)

	teleportEvent:FireServer(info.key)

	-- Watchdog: server never answered (rejected / no character) — recover
	task.delay(3, function()
		if pendingWorld == info.key then
			pendingWorld = nil
			teleporting = false
			tweenTransparency(blackout, "BackgroundTransparency", 1, 0.4)
			setCardTransparency(1)
			task.delay(0.4, function() cutsceneGui.Enabled = false end)
			UIManager.ReleaseLock()
		end
	end)
end

teleportEvent.OnClientEvent:Connect(function(worldName)
	if pendingWorld ~= worldName then return end
	pendingWorld = nil

	-- Hold the title card a beat while the teleport replicates
	task.wait(0.9)

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera

	if hrp and camera then
		local target = hrp.Position
		camera.CameraType = Enum.CameraType.Scriptable
		local back = -hrp.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0, 70, 0) + back * 45, target)

		-- Reveal the world mid-sweep
		tweenTransparency(cardIcon, "TextTransparency", 1, 0.3)
		tweenTransparency(cardTitle, "TextTransparency", 1, 0.3)
		tweenTransparency(cardTagline, "TextTransparency", 1, 0.3)
		tweenTransparency(blackout, "BackgroundTransparency", 1, 0.5)

		local endCF = CFrame.lookAt(target + back * 12 + Vector3.new(0, 6, 0), target + Vector3.new(0, 2, 0))
		local sweep = TweenService:Create(camera, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = endCF })
		sweep:Play()
		sweep.Completed:Wait()
		camera.CameraType = Enum.CameraType.Custom
	else
		tweenTransparency(blackout, "BackgroundTransparency", 1, 0.5)
		setCardTransparency(1)
		task.wait(0.5)
	end

	cutsceneGui.Enabled = false
	teleporting = false
	UIManager.ReleaseLock()
end)

for _, info in ipairs(WORLD_INFO) do
	rowButtons[info.key].MouseButton1Click:Connect(function()
		if teleporting then return end
		if os.clock() - lastTeleport < COOLDOWN_SECONDS then
			updateCooldownUI()
			return
		end
		beginDeparture(info)
	end)
end

print("[WorldsUI] Initialized")
