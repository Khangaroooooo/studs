-- MobileControls: on-screen buttons for touch devices. The game is
-- keyboard-driven (E inventory, Shift sprint, Q quests) — without these,
-- phone/tablet players can't open the inventory or sprint at all.
-- Only shown when the device has touch and no keyboard.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

if not UserInputService.TouchEnabled or UserInputService.KeyboardEnabled then
	return
end

local playerGui = player:WaitForChild("PlayerGui")

local NORMAL_SPEED = 16
local SPRINT_SPEED = 24

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MobileControls"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local function makeButton(text, position)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 52, 0, 52)
	btn.Position = position
	btn.AnchorPoint = Vector2.new(0, 1)
	btn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
	btn.BackgroundTransparency = 0.25
	btn.TextColor3 = Color3.fromRGB(255, 200, 50)
	btn.TextSize = 24
	btn.Text = text
	btn.Font = Enum.Font.GothamBold
	btn.BorderSizePixel = 0
	btn.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = btn

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 80, 100)
	stroke.Thickness = 1.5
	stroke.Parent = btn

	return btn
end

-- Bottom-left cluster (Roblox's jump button owns the bottom-right)
local inventoryBtn = makeButton("🎒", UDim2.new(0, 12, 1, -80))
local sprintBtn = makeButton("🏃", UDim2.new(0, 12, 1, -140))

-- ── Inventory ──────────────────────────────────────────────────────────
inventoryBtn.MouseButton1Click:Connect(function()
	if not player:GetAttribute("GameStarted") then return end
	if UIManager.GetLockCount() == 0 then
		UIManager.Call("OpenInventory")
	else
		UIManager.Call("CloseInventory")
	end
end)

-- ── Sprint toggle ──────────────────────────────────────────────────────
-- Mirrors Sprint.client.luau's freeze rules: never touch WalkSpeed while
-- the server has frozen us (WalkSpeed == 0 during encounters).
local sprinting = false

local function applySprint()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if humanoid.WalkSpeed == 0 then return end -- frozen by encounter
	humanoid.WalkSpeed = sprinting and SPRINT_SPEED or NORMAL_SPEED
end

local function setSprintVisual()
	sprintBtn.BackgroundColor3 = sprinting and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(20, 20, 35)
	sprintBtn.TextColor3 = sprinting and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(255, 200, 50)
end

sprintBtn.MouseButton1Click:Connect(function()
	sprinting = not sprinting
	setSprintVisual()
	applySprint()
end)

-- Re-apply sprint speed when the server unfreezes us after an encounter
local function monitorHumanoid(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed == NORMAL_SPEED and sprinting then
			humanoid.WalkSpeed = SPRINT_SPEED
		end
	end)
end

player.CharacterAdded:Connect(function(character)
	sprinting = false
	setSprintVisual()
	task.spawn(monitorHumanoid, character)
end)
if player.Character then
	task.spawn(monitorHumanoid, player.Character)
end

print("[MobileControls] Initialized (touch device detected)")
