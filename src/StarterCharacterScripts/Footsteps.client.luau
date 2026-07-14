-- Footsteps: Plays footstep sounds while the player walks
-- Different sounds for different surfaces (grass vs cobblestone)
-- Respects sprint state for faster footstep rate

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- Footstep timing
local WALK_INTERVAL = 0.45
local SPRINT_INTERVAL = 0.3

-- Sound IDs (Roblox default footstep sounds)
local GRASS_SOUNDS = {
	"rbxassetid://9126214473",
	"rbxassetid://9126214536",
	"rbxassetid://9126214597",
}

local STONE_SOUNDS = {
	"rbxassetid://9126209418",
	"rbxassetid://9126209536",
	"rbxassetid://9126209630",
}

local function isInEncounterZone(position)
	local studville = Workspace:FindFirstChild("Studville")
	if not studville then return false end

	local encounterFolder = studville:FindFirstChild("EncounterZones")
	if not encounterFolder then return false end

	for _, zone in encounterFolder:GetChildren() do
		if zone:IsA("Model") and zone:GetAttribute("EncounterZone") then
			local grassBase = zone:FindFirstChild("GrassBase")
			if grassBase then
				local halfSize = grassBase.Size / 2
				local relPos = position - grassBase.Position
				if math.abs(relPos.X) <= halfSize.X and math.abs(relPos.Z) <= halfSize.Z then
					return true
				end
			end
		end
	end
	return false
end

local function createFootstepSound(character)
	local sound = Instance.new("Sound")
	sound.Name = "Footstep"
	sound.Volume = 0.4
	sound.PlaybackSpeed = 1
	sound.Parent = character:FindFirstChild("HumanoidRootPart") or character
	return sound
end

local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not hrp then return end

	local footstepSound = createFootstepSound(character)
	local lastStepTime = 0
	local wasMoving = false

	task.spawn(function()
		while character:IsDescendantOf(game) and player.Parent == Players do
			task.wait(0.05)

			if humanoid.Health <= 0 then continue end

			local isMoving = humanoid.MoveDirection.Magnitude > 0.1
			local walkSpeed = humanoid.WalkSpeed
			local isSprinting = walkSpeed > 20

			if isMoving then
				local interval = isSprinting and SPRINT_INTERVAL or WALK_INTERVAL
				local now = tick()

				if now - lastStepTime >= interval then
					lastStepTime = now

					-- Pick sound based on surface
					local sounds = isInEncounterZone(hrp.Position) and GRASS_SOUNDS or STONE_SOUNDS
					local soundId = sounds[math.random(#sounds)]

					footstepSound.SoundId = soundId
					footstepSound.PlaybackSpeed = isSprinting and 1.2 or 1.0
					footstepSound.Volume = isSprinting and 0.5 or 0.35
					footstepSound:Play()
				end

				wasMoving = true
			else
				wasMoving = false
			end
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

print("[Footsteps] Initialized")