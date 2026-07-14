-- Settings Menu: Volume controls, notification toggles, and preferences

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

-- Settings state (saved to player attributes for persistence)
local settings = {
	musicVolume = player:GetAttribute("SettingMusicVolume") or 0.5,
	sfxVolume = player:GetAttribute("SettingSFXVolume") or 0.7,
	notificationsEnabled = player:GetAttribute("SettingNotifications") ~= false,
	showDexTracker = player:GetAttribute("SettingDexTracker") ~= false,
	showZoneIndicator = player:GetAttribute("SettingZoneIndicator") ~= false,
	showDayNight = player:GetAttribute("SettingDayNight") ~= false,
	screenShake = player:GetAttribute("SettingScreenShake") ~= false,
}

-- Save settings to attributes
local function saveSettings()
	player:SetAttribute("SettingMusicVolume", settings.musicVolume)
	player:SetAttribute("SettingSFXVolume", settings.sfxVolume)
	player:SetAttribute("SettingNotifications", settings.notificationsEnabled)
	player:SetAttribute("SettingDexTracker", settings.showDexTracker)
	player:SetAttribute("SettingZoneIndicator", settings.showZoneIndicator)
	player:SetAttribute("SettingDayNight", settings.showDayNight)
	player:SetAttribute("SettingScreenShake", settings.screenShake)
end

-- Create the ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsMenu"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Main panel (centered, hidden by default)
local panel = Instance.new("Frame")
panel.Name = "SettingsPanel"
panel.Size = UDim2.new(0, 360, 0, 420)
panel.Position = UDim2.new(0.5, -180, 0.5, -210)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 35)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.Visible = false
panel.ZIndex = 50
panel.Parent = screenGui



local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(100, 100, 160)
panelStroke.Thickness = 2
panelStroke.Transparency = 0.3
panelStroke.Parent = panel

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 40)
titleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = panel



local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Settings"
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 30, 0, 30)
closeBtn.Position = UDim2.new(1, -40, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 2
closeBtn.Parent = titleBar



-- Scrollable content area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -50)
scrollFrame.Position = UDim2.new(0, 10, 0, 45)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 160)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = panel

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.Padding = UDim.new(0, 8)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = scrollFrame

-- Helper: Create a section header
local function createSectionHeader(text, order)
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, 0, 0, 24)
	header.BackgroundTransparency = 1
	header.Text = text
	header.TextColor3 = Color3.fromRGB(180, 180, 220)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 13
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.LayoutOrder = order
	header.Parent = scrollFrame
	return header
end

-- Helper: Create a slider control
local function createSlider(labelText, initialValue, order, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 36)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = scrollFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.45, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(200, 200, 220)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- Slider track
	local track = Instance.new("Frame")
	track.Size = UDim2.new(0.45, 0, 0, 8)
	track.Position = UDim2.new(0.5, 0, 0.5, -4)
	track.BackgroundColor3 = Color3.fromRGB(50, 50, 80)
	track.BorderSizePixel = 0
	track.Parent = row



	-- Fill
	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(initialValue, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(100, 180, 255)
	fill.BorderSizePixel = 0
	fill.ClipsDescendants = true
	fill.Parent = track



	-- Value label
	local valueLabel = Instance.new("TextLabel")
	valueLabel.Size = UDim2.new(0.1, 0, 1, 0)
	valueLabel.Position = UDim2.new(0.96, 0, 0, 0)
	valueLabel.BackgroundTransparency = 1
	valueLabel.Text = tostring(math.floor(initialValue * 100)) .. "%"
	valueLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
	valueLabel.Font = Enum.Font.Gotham
	valueLabel.TextSize = 11
	valueLabel.Parent = row

	-- Drag handling
	local dragging = false

	local function updateSlider(input)
		local relX = math.clamp((input.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		fill.Size = UDim2.new(relX, 0, 1, 0)
		valueLabel.Text = tostring(math.floor(relX * 100)) .. "%"
		onChange(relX)
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			updateSlider(input)
		end
	end)

	track.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			updateSlider(input)
		end
	end)

	return fill, valueLabel
end

-- Helper: Create a toggle control
local function createToggle(labelText, initialState, order, onChange)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 30)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = scrollFrame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = labelText
	label.TextColor3 = Color3.fromRGB(200, 200, 220)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- Toggle button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Size = UDim2.new(0, 44, 0, 22)
	toggleBtn.Position = UDim2.new(1, -50, 0.5, -11)
	toggleBtn.BackgroundColor3 = initialState and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(80, 80, 100)
	toggleBtn.Text = initialState and "ON" or "OFF"
	toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 10
	toggleBtn.BorderSizePixel = 0
	toggleBtn.Parent = row



	local state = initialState
	toggleBtn.MouseButton1Click:Connect(function()
		state = not state
		toggleBtn.BackgroundColor3 = state and Color3.fromRGB(60, 160, 60) or Color3.fromRGB(80, 80, 100)
		toggleBtn.Text = state and "ON" or "OFF"
		onChange(state)
	end)

	return toggleBtn
end

-- Build the settings UI
createSectionHeader("Audio", 1)

createSlider("Music Volume", settings.musicVolume, 2, function(value)
	settings.musicVolume = value
	saveSettings()
end)

createSlider("SFX Volume", settings.sfxVolume, 3, function(value)
	settings.sfxVolume = value
	saveSettings()
end)

createSectionHeader("Display", 4)

createToggle("Notifications", settings.notificationsEnabled, 5, function(state)
	settings.notificationsEnabled = state
	saveSettings()
end)

createToggle("Dex Tracker", settings.showDexTracker, 6, function(state)
	settings.showDexTracker = state
	saveSettings()
	-- Toggle the dex panel visibility setting
	local hud = playerGui:FindFirstChild("GameHUD")
	if hud then
		local dexToggle = hud:FindFirstChild("DexToggle", true)
		if dexToggle then
			dexToggle.Visible = state
		end
	end
end)

createToggle("Zone Indicator", settings.showZoneIndicator, 7, function(state)
	settings.showZoneIndicator = state
	saveSettings()
	local hud = playerGui:FindFirstChild("GameHUD")
	if hud then
		local zoneBadge = hud:FindFirstChild("ZoneBadge", true)
		if zoneBadge then
			zoneBadge.Visible = state
		end
	end
end)

createToggle("Day/Night Display", settings.showDayNight, 8, function(state)
	settings.showDayNight = state
	saveSettings()
	local hud = playerGui:FindFirstChild("GameHUD")
	if hud then
		local dayNightBadge = hud:FindFirstChild("DayNightBadge", true)
		if dayNightBadge then
			dayNightBadge.Visible = state
		end
	end
end)

createToggle("Screen Shake", settings.screenShake, 9, function(state)
	settings.screenShake = state
	saveSettings()
end)

createSectionHeader("Game", 10)

-- Manual save button — fires the same SaveData remote the autosave loop and
-- PlayerRemoving/BindToClose paths use on the server, so players can force
-- a save on demand instead of only relying on the 60s autosave tick.
local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, 0, 0, 32)
saveBtn.BackgroundColor3 = Color3.fromRGB(40, 60, 45)
saveBtn.BackgroundTransparency = 0.3
saveBtn.Text = "Save Game"
saveBtn.TextColor3 = Color3.fromRGB(150, 255, 170)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 12
saveBtn.BorderSizePixel = 0
saveBtn.LayoutOrder = 11
saveBtn.Parent = scrollFrame

local saveCooldown = false
saveBtn.MouseButton1Click:Connect(function()
	if saveCooldown then return end
	saveCooldown = true

	StudEvents.SaveData:FireServer()

	local originalText = "Save Game"
	saveBtn.Text = "Saved!"
	task.delay(1.5, function()
		saveBtn.Text = originalText
		saveCooldown = false
	end)
end)

createSectionHeader("Controls", 12)

-- Reset settings button
local resetBtn = Instance.new("TextButton")
resetBtn.Size = UDim2.new(1, 0, 0, 32)
resetBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 40)
resetBtn.BackgroundTransparency = 0.3
resetBtn.Text = "Reset to Defaults"
resetBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 12
resetBtn.BorderSizePixel = 0
resetBtn.LayoutOrder = 13
resetBtn.Parent = scrollFrame



resetBtn.MouseButton1Click:Connect(function()
	settings.musicVolume = 0.5
	settings.sfxVolume = 0.7
	settings.notificationsEnabled = true
	settings.showDexTracker = true
	settings.showZoneIndicator = true
	settings.showDayNight = true
	settings.screenShake = true
	saveSettings()
	-- Close and reopen to refresh UI
	panel.Visible = false
	task.wait(0.1)
	panel.Visible = true
end)

-- Keybind hint at bottom
local keybindLabel = Instance.new("TextLabel")
keybindLabel.Size = UDim2.new(1, 0, 0, 20)
keybindLabel.BackgroundTransparency = 1
keybindLabel.Text = "Press ESC or P to close"
keybindLabel.TextColor3 = Color3.fromRGB(120, 120, 150)
keybindLabel.Font = Enum.Font.Gotham
keybindLabel.TextSize = 11
keybindLabel.LayoutOrder = 14
keybindLabel.Parent = scrollFrame

-- ─── TITLES SECTION ─────────────────────────────────────────────────────
-- Earned dex-completion titles ("Friend of Steve" etc.) with equip buttons.
-- Rebuilt from GetPlayerStats each time the panel opens.
createSectionHeader("🏅 TITLES", 20)

local titlesContainer = Instance.new("Frame")
titlesContainer.Name = "TitlesContainer"
titlesContainer.Size = UDim2.new(1, 0, 0, 0)
titlesContainer.AutomaticSize = Enum.AutomaticSize.Y
titlesContainer.BackgroundTransparency = 1
titlesContainer.LayoutOrder = 21
titlesContainer.Parent = scrollFrame

local titlesLayout = Instance.new("UIListLayout")
titlesLayout.Padding = UDim.new(0, 6)
titlesLayout.SortOrder = Enum.SortOrder.LayoutOrder
titlesLayout.Parent = titlesContainer

local rebuildTitles -- defined below; forward-declared for the equip handlers

local function makeTitleRow(text, order, isEquipped, onEquip)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.LayoutOrder = order
	row.Parent = titlesContainer

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.7, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = isEquipped and Color3.fromRGB(255, 220, 100) or Color3.fromRGB(200, 200, 220)
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 74, 0, 22)
	btn.Position = UDim2.new(1, -80, 0.5, -11)
	btn.BackgroundColor3 = isEquipped and Color3.fromRGB(160, 130, 40) or Color3.fromRGB(60, 60, 90)
	btn.Text = isEquipped and "EQUIPPED" or "EQUIP"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 10
	btn.BorderSizePixel = 0
	btn.Parent = row

	btn.MouseButton1Click:Connect(function()
		if isEquipped then return end
		onEquip()
	end)
	return row
end

function rebuildTitles()
	for _, child in titlesContainer:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	task.spawn(function()
		local ok, stats = pcall(function()
			return StudEvents.GetPlayerStats:InvokeServer()
		end)
		if not ok or not stats then return end
		local titles = stats.titles or {}

		if #titles == 0 then
			local hint = Instance.new("Frame")
			hint.Size = UDim2.new(1, 0, 0, 24)
			hint.BackgroundTransparency = 1
			hint.LayoutOrder = 1
			hint.Parent = titlesContainer
			local hintLabel = Instance.new("TextLabel")
			hintLabel.Size = UDim2.new(1, 0, 1, 0)
			hintLabel.BackgroundTransparency = 1
			hintLabel.Text = "Catch every stud of a type to earn a title!"
			hintLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
			hintLabel.Font = Enum.Font.Gotham
			hintLabel.TextSize = 11
			hintLabel.TextXAlignment = Enum.TextXAlignment.Left
			hintLabel.Parent = hint
			return
		end

		local function equip(title)
			local okEquip, result = pcall(function()
				return StudEvents.EquipTitle:InvokeServer(title)
			end)
			if okEquip and result and result.success then
				rebuildTitles()
			end
		end

		makeTitleRow("(no title)", 1, stats.equippedTitle == nil, function()
			equip(nil)
		end)
		for i, title in ipairs(titles) do
			makeTitleRow("✦ " .. title, i + 1, stats.equippedTitle == title, function()
				equip(title)
			end)
		end
	end)
end

-- Toggle visibility
local function toggleSettings()
	panel.Visible = not panel.Visible
	if panel.Visible then
		UIManager.CloseOtherPanels("Settings")
		rebuildTitles()
		-- Animate in
		panel.Position = UDim2.new(0.5, -180, 0.5, -200)
		panel.BackgroundTransparency = 0.3
		local tweenIn = TweenService:Create(panel, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Position = UDim2.new(0.5, -180, 0.5, -210),
			BackgroundTransparency = 0.05
		})
		tweenIn:Play()
	end
end

-- Exclusive-panel registration (Shop/Quests/Leaderboard close this on open)
UIManager.RegisterPanel("Settings", function()
	panel.Visible = false
end)

-- Close button handler
closeBtn.MouseButton1Click:Connect(function()
	local tweenOut = TweenService:Create(panel, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 1
	})
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		panel.Visible = false
		panel.BackgroundTransparency = 0.05
	end)
end)

-- ── SETTINGS HUD BUTTON ─────────────────────────────────────────────────
-- Gear button in the top-right rail, below the coins pill and Quest button
-- (see GameHUD/QuestUI). Same visual language: dark rounded card + stroke.
local gearBtn = Instance.new("TextButton")
gearBtn.Name = "SettingsToggle"
gearBtn.Size = UDim2.new(0, 44, 0, 44)
gearBtn.Position = UDim2.new(1, -56, 0, 112)
gearBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
gearBtn.BackgroundTransparency = 0.25
gearBtn.Text = "⚙️"
gearBtn.TextSize = 22
gearBtn.Font = Enum.Font.GothamBold
gearBtn.TextColor3 = Color3.fromRGB(200, 200, 215)
gearBtn.BorderSizePixel = 0
gearBtn.Parent = screenGui

local gearCorner = Instance.new("UICorner")
gearCorner.CornerRadius = UDim.new(0, 10)
gearCorner.Parent = gearBtn

local gearStroke = Instance.new("UIStroke")
gearStroke.Color = Color3.fromRGB(80, 80, 100)
gearStroke.Thickness = 1.5
gearStroke.Parent = gearBtn

gearBtn.MouseButton1Click:Connect(toggleSettings)
gearBtn.MouseEnter:Connect(function() gearBtn.BackgroundTransparency = 0.05 end)
gearBtn.MouseLeave:Connect(function() gearBtn.BackgroundTransparency = 0.25 end)

-- Keyboard shortcut: P to toggle settings
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.P then
		toggleSettings()
	elseif input.KeyCode == Enum.KeyCode.Escape and panel.Visible then
		panel.Visible = false
	end
end)

-- Expose toggle function for other scripts
local bindable = Instance.new("BindableEvent")
bindable.Name = "ToggleSettings"
bindable.Parent = script
bindable.Event:Connect(toggleSettings)

-- Apply initial visibility settings
task.delay(2, function()
	local hud = playerGui:FindFirstChild("GameHUD")
	if hud then
		local zoneBadge = hud:FindFirstChild("ZoneBadge", true)
		if zoneBadge then zoneBadge.Visible = settings.showZoneIndicator end
		local dayNightBadge = hud:FindFirstChild("DayNightBadge", true)
		if dayNightBadge then dayNightBadge.Visible = settings.showDayNight end
	end
end)

print("[SettingsMenu] Initialized")