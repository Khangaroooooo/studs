--[[
	AreaNameDisplay.lua — Shows area/zone/building names when entering new areas
	Fades in a title + subtitle at the top of the screen, then fades out after 3 seconds.
	Detects: town centers, encounter zones, and buildings.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")


local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ─── SCREEN GUI ───────────────────────────────────────────────────────────
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AreaNameDisplay"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Area name label (center top)
local areaLabel = Instance.new("TextLabel")
areaLabel.Name = "AreaName"
areaLabel.Size = UDim2.new(0.5, 0, 0.08, 0)
areaLabel.Position = UDim2.new(0.25, 0, 0.12, 0)
areaLabel.BackgroundTransparency = 1
areaLabel.Text = ""
areaLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
areaLabel.Font = Enum.Font.Arcade
areaLabel.TextSize = 36
areaLabel.TextStrokeTransparency = 0.3
areaLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
areaLabel.TextTransparency = 1
areaLabel.Parent = screenGui

-- Subtitle (e.g. "Wild Grass Zone")
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "AreaSubtitle"
subtitleLabel.Size = UDim2.new(0.5, 0, 0.04, 0)
subtitleLabel.Position = UDim2.new(0.25, 0, 0.2, 0)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = ""
subtitleLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
subtitleLabel.Font = Enum.Font.Arcade
subtitleLabel.TextSize = 18
subtitleLabel.TextStrokeTransparency = 0.5
subtitleLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
subtitleLabel.TextTransparency = 1
subtitleLabel.Parent = screenGui

-- ─── STATE ──────────────────────────────────────────────────────────────
local currentArea = ""
local displayTimer = nil

-- ─── AREA DEFINITIONS ────────────────────────────────────────────────────
-- Town centers (detected by distance to center position + radius)
local townCenters = {
	{ name = "Studville", subtitle = "A cozy town for Stud Catchers", center = Vector3.new(0, 0, 0), radius = 35 },
	{ name = "Emberpeak", subtitle = "A volcanic realm of fire and fury", center = Vector3.new(3500, 0, 0), radius = 150 },
	{ name = "Tidepool Cove", subtitle = "A coastal paradise of waves and wonder", center = Vector3.new(-3500, 0, 0), radius = 150 },
	{ name = "Volt Wasteland", subtitle = "A storm-blasted land of crackling energy", center = Vector3.new(0, 0, 3500), radius = 150 },
	{ name = "Canyon Depths", subtitle = "An ancient desert of stone and sand", center = Vector3.new(0, 0, -3500), radius = 150 },
	{ name = "Frostbite Tundra", subtitle = "A frozen wasteland of ice and snow", center = Vector3.new(3500, 0, 3500), radius = 150 },
	{ name = "Duskwood Hollow", subtitle = "A dark forest of shadows and secrets", center = Vector3.new(-3500, 0, -3500), radius = 150 },
}

-- Encounter zones (detected by checking if player is inside zone's base part)
local encounterZones = {
	-- Studville
	{ name = "Northern Meadow", subtitle = "Grass & Electric Studs", zoneName = "GrassNorth" },
	{ name = "Southern Shore", subtitle = "Water & Ice Studs", zoneName = "GrassSouth" },
	{ name = "Western Ridge", subtitle = "Rock & Fire Studs", zoneName = "GrassWest" },
	{ name = "Eastern Grove", subtitle = "Grass & Water Studs", zoneName = "GrassEast" },
	-- Emberpeak
	{ name = "Fire Flats", subtitle = "Fire & Rock Studs", zoneName = "FireNorth" },
	{ name = "Ember Fields", subtitle = "Fire & Rock Studs", zoneName = "FireSouth" },
	{ name = "Magma Rift", subtitle = "Fire & Electric Studs", zoneName = "MagmaWest" },
	{ name = "Obsidian Plains", subtitle = "Rock & Fire Studs", zoneName = "MagmaEast" },
	-- Tidepool Cove
	{ name = "Northern Shore", subtitle = "Water & Ice Studs", zoneName = "ShoreNorth" },
	{ name = "Southern Shore", subtitle = "Water & Ice Studs", zoneName = "ShoreSouth" },
	{ name = "Western Reef", subtitle = "Water & Grass Studs", zoneName = "ReefWest" },
	{ name = "Eastern Reef", subtitle = "Water & Electric Studs", zoneName = "ReefEast" },
	{ name = "Northeast Reef", subtitle = "Water & Electric Studs", zoneName = "ReefNortheast" },
	{ name = "Southwest Shore", subtitle = "Water & Ice Studs", zoneName = "ShoreSouthwest" },
	{ name = "Wreck Shallows", subtitle = "Water & Rock Studs", zoneName = "ShoreWreck" },
	{ name = "Palm Lagoon", subtitle = "Water & Grass Studs", zoneName = "ReefLagoon" },
	{ name = "Ruins Shore", subtitle = "Grass & Rock Studs", zoneName = "ShoreRuins" },
	{ name = "Volcano Beach", subtitle = "Fire & Rock Studs", zoneName = "ShoreVolcano" },
	{ name = "Turtle Cove", subtitle = "Water & Grass Studs", zoneName = "ShoreTurtle" },
	-- Volt Wasteland
	{ name = "Storm Front", subtitle = "Electric & Grass Studs", zoneName = "StormNorth" },
	{ name = "Storm Back", subtitle = "Electric & Grass Studs", zoneName = "StormSouth" },
	{ name = "Static Field", subtitle = "Electric & Fire Studs", zoneName = "StaticWest" },
	{ name = "Charge Zone", subtitle = "Electric & Rock Studs", zoneName = "StaticEast" },
	-- Canyon Depths
	{ name = "Canyon North", subtitle = "Rock & Fire Studs", zoneName = "CanyonNorth" },
	{ name = "Canyon South", subtitle = "Rock & Fire Studs", zoneName = "CanyonSouth" },
	{ name = "Western Gorge", subtitle = "Rock & Electric Studs", zoneName = "GorgeWest" },
	{ name = "Eastern Gorge", subtitle = "Rock & Grass Studs", zoneName = "GorgeEast" },
	{ name = "Mesa Ridge", subtitle = "Rock & Fire Studs", zoneName = "MesaRidge" },
	{ name = "Canyon Floor", subtitle = "Rock & Ice Studs", zoneName = "CanyonFloor" },
	{ name = "Ridge Pass", subtitle = "Rock & Electric Studs", zoneName = "RidgePass" },
	-- Frostbite Tundra
	{ name = "Frost Fields", subtitle = "Ice & Water Studs", zoneName = "FrostNorth" },
	{ name = "Frost Plains", subtitle = "Ice & Water Studs", zoneName = "FrostSouth" },
	{ name = "Glacier West", subtitle = "Ice & Rock Studs", zoneName = "GlacierWest" },
	{ name = "Glacier East", subtitle = "Ice & Grass Studs", zoneName = "GlacierEast" },
	-- Duskwood Hollow
	{ name = "Shadow North", subtitle = "Shadow & Electric Studs", zoneName = "ShadowNorth" },
	{ name = "Shadow South", subtitle = "Shadow & Ice Studs", zoneName = "ShadowSouth" },
	{ name = "Dusk West", subtitle = "Shadow & Fire Studs", zoneName = "DuskWest" },
	{ name = "Dusk East", subtitle = "Shadow & Water Studs", zoneName = "DuskEast" },
}

-- Building definitions (detected by proximity to building model position)
-- Maps building model name → display name + subtitle
local buildingDefs = {
	-- Studville
	StudCenter        = { name = "Stud Center", subtitle = "Track your collection and stats" },
	StudLab           = { name = "Stud Lab", subtitle = "Research and evolve your Studs" },
	Shop              = { name = "Shop", subtitle = "Buy items and sell Studs" },
	Workshop          = { name = "Workshop", subtitle = "Craft and upgrade gear" },
	PlayerHouse       = { name = "Your House", subtitle = "Home sweet home" },
	VegetableGarden   = { name = "Vegetable Garden", subtitle = "Fresh produce from Studville" },
	-- Emberpeak
	MagmaTower        = { name = "Magma Tower", subtitle = "A spire of molten rock" },
	BlacksmithForge   = { name = "Blacksmith's Forge", subtitle = "Craft fire-forged tools" },
	MineShaft         = { name = "Mine Shaft", subtitle = "Dig for rare ores and gems" },
	ProspectorCabin   = { name = "Prospector's Cabin", subtitle = "Trade with the old miner" },
	GemCave           = { name = "Gem Cave", subtitle = "Sparkling treasures within" },
	-- Tidepool Cove
	Lighthouse        = { name = "Lighthouse", subtitle = "Guiding ships through the mist" },
	Dock              = { name = "Dock", subtitle = "Ships and Studs from the sea" },
	BattleArena       = { name = "Battle Arena", subtitle = "Challenge other Stud Catchers" },
	SeaTemple         = { name = "Sea Temple", subtitle = "Ancient waters hold secrets" },
	FishMarket        = { name = "Fish Market", subtitle = "Fresh catches and rare Studs" },
	-- Volt Wasteland
	PowerStation      = { name = "Power Station", subtitle = "Crackling with energy" },
	StormTower       = { name = "Storm Tower", subtitle = "Where lightning strikes" },
	LightningTower    = { name = "Lightning Tower", subtitle = "Charged with raw power" },
	GeneratorBunker  = { name = "Generator Bunker", subtitle = "Hidden power source" },
	-- Frostbite Tundra
	IcePalace         = { name = "Ice Palace", subtitle = "A frozen throne of crystalline beauty" },
	FrozenObservatory = { name = "Frozen Observatory", subtitle = "Gaze upon the northern lights" },
	IceFortress       = { name = "Ice Fortress", subtitle = "Bastion of the frozen north" },
	HuntersLodge      = { name = "Hunter's Lodge", subtitle = "Shelter from the storm" },
	WitchHut          = { name = "Witch's Hut", subtitle = "Brews and remedies" },
	FrozenPond        = { name = "Frozen Pond", subtitle = "Ice Studs gather here" },
	-- Duskwood Hollow
	ShadowShrine      = { name = "Shadow Shrine", subtitle = "Whispers of the dark" },
	AncientRuins      = { name = "Ancient Ruins", subtitle = "Echoes of a forgotten age" },
}

local BUILDING_RADIUS = 20 -- studs to trigger building name display

-- ─── DETECTION FUNCTIONS ─────────────────────────────────────────────────

local function getEncounterZone(position)
	for _, worldFolder in Workspace:GetChildren() do
		if worldFolder:IsA("Folder") or worldFolder:IsA("Model") then
			local encounterFolder = worldFolder:FindFirstChild("EncounterZones")
			if not encounterFolder then continue end

			for _, zone in encounterFolder:GetChildren() do
				if zone:IsA("Model") or zone:IsA("Folder") then
					local basePart = nil
					for _, child in zone:GetChildren() do
						if child:IsA("BasePart") and child.Name:find("Base") then
							basePart = child
							break
						end
					end
					if not basePart then
						basePart = zone:FindFirstChildWhichIsA("BasePart")
					end
					if basePart then
						local halfSize = basePart.Size / 2
						local relPos = position - basePart.Position
						if math.abs(relPos.X) <= halfSize.X and math.abs(relPos.Z) <= halfSize.Z then
							return zone.Name
						end
					end
				end
			end
		end
	end
	return nil
end

local function getNearbyBuilding(position)
	for _, worldFolder in Workspace:GetChildren() do
		if worldFolder:IsA("Folder") or worldFolder:IsA("Model") then
			local buildingsFolder = worldFolder:FindFirstChild("Buildings")
			if not buildingsFolder then continue end

			for _, building in buildingsFolder:GetChildren() do
				local def = buildingDefs[building.Name]
				if def then
					local pos = building:GetPivot().Position
					local dist = (position - pos).Magnitude
					if dist < BUILDING_RADIUS then
						return def.name, def.subtitle
					end
				end
			end
		end
	end
	return nil
end

-- ─── DISPLAY FUNCTION ────────────────────────────────────────────────────
local function showAreaName(name, subtitle)
	if currentArea == name then return end
	currentArea = name

	-- Cancel any existing timer
	if displayTimer then
		task.cancel(displayTimer)
		displayTimer = nil
	end

	areaLabel.Text = name
	subtitleLabel.Text = subtitle or ""

	-- Fade in
	local fadeIn = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(areaLabel, fadeIn, { TextTransparency = 0 }):Play()
	TweenService:Create(subtitleLabel, fadeIn, { TextTransparency = 0 }):Play()

	-- Fade out after 3 seconds
	displayTimer = task.delay(3, function()
		local fadeOut = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(areaLabel, fadeOut, { TextTransparency = 1 }):Play()
		TweenService:Create(subtitleLabel, fadeOut, { TextTransparency = 1 }):Play()
		task.delay(1, function()
			if currentArea == name then
				currentArea = ""
			end
		end)
	end)
end

-- ─── POSITION MONITORING ────────────────────────────────────────────────
local function monitorPosition(character)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end

	task.spawn(function()
		while character:IsDescendantOf(game) and player.Parent == Players do
			task.wait(0.5)

			local pos = hrp.Position

			-- Priority 1: Encounter zones
			local zoneName = getEncounterZone(pos)
			if zoneName then
				for _, area in encounterZones do
					if area.zoneName == zoneName then
						showAreaName(area.name, area.subtitle)
						break
					end
				end
			else
				-- Priority 2: Buildings
				local bldgName, bldgSubtitle = getNearbyBuilding(pos)
				if bldgName then
					showAreaName(bldgName, bldgSubtitle)
				else
					-- Priority 3: Town centers
					for _, area in townCenters do
						local dist = (pos - area.center).Magnitude
						if dist < area.radius then
							showAreaName(area.name, area.subtitle)
							break
						end
					end
				end
			end
		end
	end)
end

player.CharacterAdded:Connect(monitorPosition)

-- Handle character that already exists
if player.Character then
	monitorPosition(player.Character)
end

print("[AreaNameDisplay] Initialized — zones, buildings, and town centers")