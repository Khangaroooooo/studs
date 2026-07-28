-- Sprint: Hold LeftShift to sprint, no stamina bar
-- Works with R6 characters, respects encounter freeze

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local NORMAL_SPEED = 16
local SPRINT_SPEED = 24

local isFrozen = false -- set by encounter system

local function getHumanoid()
	local character = player.Character
	if character then
		return character:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

local function setSprinting(sprinting)
	if isFrozen then return end
	local humanoid = getHumanoid()
	if not humanoid then return end

	humanoid.WalkSpeed = sprinting and SPRINT_SPEED or NORMAL_SPEED
end

-- Track encounter state by monitoring WalkSpeed changes from server
-- When the server sets WalkSpeed to 0 (encounter freeze), we know we're frozen
-- When it sets back to 16, we know the encounter ended
-- Event-driven freeze detection: instead of polling WalkSpeed 10x/sec forever,
-- listen to GetPropertyChangedSignal("WalkSpeed"). Fires only when the server
-- (or this script) actually changes it — zero idle cost, and reacts instantly
-- instead of up to 100ms late.
local function monitorWalkSpeed(humanoid)
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if humanoid.WalkSpeed == 0 then
			isFrozen = true
		elseif isFrozen and humanoid.WalkSpeed > 0 then
			isFrozen = false
			-- Restore correct speed based on shift key state
			setSprinting(UserInputService:IsKeyDown(Enum.KeyCode.LeftShift))
		end
	end)
end

-- Input handling
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		setSprinting(false)
	end
end)

-- When character spawns, reset state and disable climbing to prevent wall floating
player.CharacterAdded:Connect(function(character)
	isFrozen = false

	-- Disable Climbing state to prevent floating when jumping into walls,
	-- and attach the event-driven WalkSpeed monitor to this humanoid.
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 5)
		if humanoid then
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
			monitorWalkSpeed(humanoid)
		end
	end)
end)

-- Attach to the current character if it already exists
do
	local humanoid = getHumanoid()
	if humanoid then monitorWalkSpeed(humanoid) end
end

print("[Sprint] Initialized - hold Shift to sprint")