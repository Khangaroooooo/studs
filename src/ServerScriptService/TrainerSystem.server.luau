-- TrainerSystem: one trainer NPC per world with a fixed, themed team.
-- Beat their whole team for a purse and a one-time badge (rematches pay 25%).
--
-- This script owns the WORLD side (R6 rigs, prompts, definitions); the
-- battles themselves run in BattleSystem via the shared StartTrainerBattle
-- registry entry, reusing the whole arena battle loop and BattleUI.
--
-- Placement is derived, not authored: each trainer stands beside the first
-- encounter zone of their world (found the same way EncounterSystem finds
-- zones), raycast to the ground. Worlds without an EncounterZones folder
-- are skipped, so partially-built worlds never error.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

-- Trainer names deliberately avoid the 105 stud names — nobody should
-- wonder whether Ranger Wanda is catchable. Teams sit mid-band for their
-- world; levels come from StudData.WorldLevelBands.
local TRAINERS = {
	{
		id = "trainer_studville", world = "Studville",
		name = "Ranger Wanda", badge = "Meadow Badge", reward = 300,
		torsoColor = Color3.fromRGB(60, 140, 70),
		team = { { id = "terry", level = 8 }, { id = "gary", level = 10 } },
	},
	{
		id = "trainer_tidepool", world = "TidepoolCove",
		name = "Captain Otis", badge = "Tide Badge", reward = 600,
		torsoColor = Color3.fromRGB(45, 100, 170),
		team = { { id = "dave", level = 15 }, { id = "sandra", level = 18 }, { id = "cheryl", level = 20 } },
	},
	{
		id = "trainer_emberpeak", world = "Emberpeak",
		name = "Marshal Felix", badge = "Ember Badge", reward = 1000,
		torsoColor = Color3.fromRGB(170, 60, 40),
		team = { { id = "kevin", level = 26 }, { id = "frank", level = 28 }, { id = "bruce", level = 30 } },
	},
	{
		id = "trainer_voltwasteland", world = "VoltWasteland",
		name = "Engineer Pearl", badge = "Volt Badge", reward = 1500,
		torsoColor = Color3.fromRGB(190, 170, 40),
		team = { { id = "vince", level = 36 }, { id = "jan", level = 38 }, { id = "rick", level = 40 } },
	},
	{
		id = "trainer_canyondepths", world = "CanyonDepths",
		name = "Prospector Reggie", badge = "Canyon Badge", reward = 2200,
		torsoColor = Color3.fromRGB(140, 110, 70),
		team = { { id = "carl", level = 46 }, { id = "gladys", level = 48 }, { id = "walt", level = 50 } },
	},
	{
		id = "trainer_frostbite", world = "FrostbiteTundra",
		name = "Warden Mabel", badge = "Frost Badge", reward = 3000,
		torsoColor = Color3.fromRGB(120, 180, 210),
		team = { { id = "lance", level = 62 }, { id = "dale", level = 64 }, { id = "kirk", level = 66 } },
	},
	{
		id = "trainer_duskwood", world = "DuskwoodHollow",
		name = "Nightwatch Simon", badge = "Dusk Badge", reward = 5000,
		torsoColor = Color3.fromRGB(70, 45, 105),
		team = { { id = "cliff", level = 80 }, { id = "vicky", level = 82 }, { id = "hal", level = 85 } },
	},
}

local SKIN_COLOR = Color3.fromRGB(245, 205, 48)
local LEG_COLOR = Color3.fromRGB(50, 50, 60)

-- First encounter zone of a world (alphabetical for determinism) that has a
-- usable base part — same discovery rules as EncounterSystem's zone cache.
-- Tries every zone in order: some (e.g. CanyonDepths' CanyonFloor) have no
-- BasePart children and used to leave their trainer unspawned.
local function findAnchorPart(worldFolder)
	local encounterFolder = worldFolder:FindFirstChild("EncounterZones")
	if not encounterFolder then return nil end

	local zones = {}
	for _, zone in encounterFolder:GetChildren() do
		if zone:IsA("Model") or zone:IsA("Folder") then
			table.insert(zones, zone)
		end
	end
	table.sort(zones, function(a, b) return a.Name < b.Name end)

	for _, zone in ipairs(zones) do
		for _, child in zone:GetChildren() do
			if child:IsA("BasePart") and child.Name:find("Base") then
				return child
			end
		end
		local anyPart = zone:FindFirstChildWhichIsA("BasePart")
		if anyPart then
			return anyPart
		end
	end
	return nil
end

local function buildTrainerRig(def, rootCFrame, parent)
	local model = Instance.new("Model")
	model.Name = def.name

	local function mkPart(name, size, color, offset)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = name == "Torso"
		part.CFrame = rootCFrame * offset
		part.Parent = model
		return part
	end

	local hrp = mkPart("HumanoidRootPart", Vector3.new(2, 2, 1), def.torsoColor, CFrame.new())
	hrp.Transparency = 1
	hrp.CanCollide = false

	local torso = mkPart("Torso", Vector3.new(2, 2, 1), def.torsoColor, CFrame.new())
	mkPart("Left Arm", Vector3.new(1, 2, 1), SKIN_COLOR, CFrame.new(-1.5, 0, 0))
	mkPart("Right Arm", Vector3.new(1, 2, 1), SKIN_COLOR, CFrame.new(1.5, 0, 0))
	mkPart("Left Leg", Vector3.new(1, 2, 1), LEG_COLOR, CFrame.new(-0.5, -2, 0))
	mkPart("Right Leg", Vector3.new(1, 2, 1), LEG_COLOR, CFrame.new(0.5, -2, 0))

	local head = mkPart("Head", Vector3.new(2, 1, 1), SKIN_COLOR, CFrame.new(0, 1.5, 0))
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.DisplayName = def.name
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	-- Big beacon billboard so trainers are spottable from across the zone
	-- (they stand at zone edges, which are easy to walk past otherwise)
	local beacon = Instance.new("BillboardGui")
	beacon.Name = "TrainerBeacon"
	beacon.Size = UDim2.new(0, 220, 0, 44)
	beacon.StudsOffset = Vector3.new(0, 3.2, 0)
	beacon.AlwaysOnTop = true
	beacon.MaxDistance = 250
	beacon.Parent = head

	local beaconTitle = Instance.new("TextLabel")
	beaconTitle.Size = UDim2.new(1, 0, 0.5, 0)
	beaconTitle.BackgroundTransparency = 1
	beaconTitle.Text = "⚔️ TRAINER"
	beaconTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
	beaconTitle.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	beaconTitle.TextStrokeTransparency = 0.2
	beaconTitle.Font = Enum.Font.Arcade
	beaconTitle.TextScaled = true
	beaconTitle.Parent = beacon

	local beaconName = Instance.new("TextLabel")
	beaconName.Size = UDim2.new(1, 0, 0.5, 0)
	beaconName.Position = UDim2.new(0, 0, 0.5, 0)
	beaconName.BackgroundTransparency = 1
	beaconName.Text = def.name .. " · " .. def.badge
	beaconName.TextColor3 = Color3.new(1, 1, 1)
	beaconName.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	beaconName.TextStrokeTransparency = 0.2
	beaconName.Font = Enum.Font.Arcade
	beaconName.TextScaled = true
	beaconName.Parent = beacon

	model.PrimaryPart = hrp

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Battle"
	prompt.ObjectText = def.name
	prompt.HoldDuration = 0.5 -- deliberate hold; no accidental gauntlets
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	prompt.Triggered:Connect(function(player)
		ServerRegistry.Call("StartTrainerBattle", player, def)
	end)

	model.Parent = parent
	return model
end

local trainersFolder = Workspace:FindFirstChild("Trainers")
if not trainersFolder then
	trainersFolder = Instance.new("Folder")
	trainersFolder.Name = "Trainers"
	trainersFolder.Parent = Workspace
end

local spawned = 0
for _, def in ipairs(TRAINERS) do
	if not trainersFolder:FindFirstChild(def.name) then
		local worldFolder = Workspace:FindFirstChild(def.world)
		local anchor = worldFolder and findAnchorPart(worldFolder)
		if anchor then
			-- Stand beside the zone edge, raycast to the ground, face the zone
			local edgePos = anchor.Position + Vector3.new(anchor.Size.X / 2 + 5, 10, 0)
			local rayParams = RaycastParams.new()
			rayParams.FilterType = Enum.RaycastFilterType.Exclude
			rayParams.FilterDescendantsInstances = { trainersFolder }
			local ray = Workspace:Raycast(edgePos, Vector3.new(0, -60, 0), rayParams)
			local groundY = ray and ray.Position.Y or (anchor.Position.Y + anchor.Size.Y / 2)

			local rootPos = Vector3.new(edgePos.X, groundY + 3, edgePos.Z)
			local lookAt = Vector3.new(anchor.Position.X, rootPos.Y, anchor.Position.Z)
			buildTrainerRig(def, CFrame.lookAt(rootPos, lookAt), trainersFolder)
			spawned += 1
		else
			warn("[TrainerSystem] No encounter zone anchor for world '" .. def.world .. "'; " .. def.name .. " not spawned")
		end
	end
end

print("[TrainerSystem] Spawned " .. spawned .. "/" .. #TRAINERS .. " trainers")
