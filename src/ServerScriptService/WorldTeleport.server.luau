-- WorldTeleport: server side of the Worlds menu (WorldsUI.client.luau).
-- Client fires StudEvents.TeleportToWorld with a world name; we validate it,
-- enforce a per-player cooldown, move the character to that world's spawn,
-- then fire the same event back so the client can play the arrival cutscene.
--
-- Spawn resolution order per world:
--   1. Any BasePart named "WorldSpawn" inside the world (drop one in Studio
--      to override — lands on its top surface)
--   2. Hardcoded fallback position below (measured from live geometry 2026-07-13)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

-- Rojo also declares this remote (TeleportToWorld.model.json); create it here
-- if it hasn't synced yet, same pattern as LeaderboardSystem
local teleportEvent = StudEvents:FindFirstChild("TeleportToWorld")
if not teleportEvent then
	teleportEvent = Instance.new("RemoteEvent")
	teleportEvent.Name = "TeleportToWorld"
	teleportEvent.Parent = StudEvents
end

local COOLDOWN_SECONDS = 5

-- Fallback spawn positions + the point the player should face on arrival.
-- Studville prefers the TownSpawn SpawnLocation when it exists.
local WORLDS = {
	Studville       = { pos = Vector3.new(-97, 13, 35),     face = Vector3.new(3, 13, 3) },
	TidepoolCove    = { pos = Vector3.new(-3440, -29, 193), face = Vector3.new(-3500, -29, 0) }, -- main dock
	Emberpeak       = { pos = Vector3.new(3500, 4, 0),      face = Vector3.new(3600, 4, 0) },
	VoltWasteland   = { pos = Vector3.new(0, 4, 3500),      face = Vector3.new(0, 4, 3600) },
	CanyonDepths    = { pos = Vector3.new(0, 3, -4250),     face = Vector3.new(0, 3, -4350) }, -- dry riverbed
	FrostbiteTundra = { pos = Vector3.new(3500, 4, 3500),   face = Vector3.new(3600, 4, 3500) },
	DuskwoodHollow  = { pos = Vector3.new(-3500, 4, -3500), face = Vector3.new(-3600, 4, -3500) },
}

local lastTeleport = {} -- [player] = os.clock() of last accepted teleport

local function resolveSpawn(worldName)
	local world = workspace:FindFirstChild(worldName)
	if not world then return nil end

	local override = world:FindFirstChild("WorldSpawn", true)
	if override and override:IsA("BasePart") then
		return override.Position + Vector3.new(0, override.Size.Y / 2 + 3, 0), override.Position + override.CFrame.LookVector * 50
	end

	if worldName == "Studville" then
		local townSpawn = world:FindFirstChild("TownSpawn", true)
		if townSpawn and townSpawn:IsA("BasePart") then
			return townSpawn.Position + Vector3.new(0, 3, 0), townSpawn.Position + townSpawn.CFrame.LookVector * 50
		end
	end

	local entry = WORLDS[worldName]
	return entry.pos + Vector3.new(0, 3, 0), entry.face
end

teleportEvent.OnServerEvent:Connect(function(player, worldName)
	if typeof(worldName) ~= "string" or not WORLDS[worldName] then return end

	local now = os.clock()
	local last = lastTeleport[player]
	if last and now - last < COOLDOWN_SECONDS then return end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then return end

	local spawnPos, facePos = resolveSpawn(worldName)
	if not spawnPos then return end

	lastTeleport[player] = now

	-- Face the world's point of interest unless the spawn IS that point
	local flatFace = Vector3.new(facePos.X, spawnPos.Y, facePos.Z)
	if (flatFace - spawnPos).Magnitude > 1 then
		hrp.CFrame = CFrame.lookAt(spawnPos, flatFace)
	else
		hrp.CFrame = CFrame.new(spawnPos)
	end
	hrp.AssemblyLinearVelocity = Vector3.zero

	-- Record the island the player is on so island-gated systems (the shop's
	-- exclusive held items) can check it. Unset defaults to "Studville".
	player:SetAttribute("CurrentWorld", worldName)

	teleportEvent:FireClient(player, worldName)
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

print("[WorldTeleport] Initialized")
