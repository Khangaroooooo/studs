-- EventSystem: every 25-40 minutes a Legendary stud "roams" a random
-- encounter zone for 5 minutes. While active, encounter rate in that zone
-- doubles and 25% of its encounters are the roaming legendary
-- (EncounterSystem reads ServerRegistry "ActiveLegendaryEvent").
-- Announced to everyone via the GameAnnouncement remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local announceEvent = StudEvents:FindFirstChild("GameAnnouncement")
if not announceEvent then
	announceEvent = Instance.new("RemoteEvent")
	announceEvent.Name = "GameAnnouncement"
	announceEvent.Parent = StudEvents
end

local EVENT_DURATION = 5 * 60
local EVENT_GAP_MIN = 25 * 60
local EVENT_GAP_MAX = 40 * 60

-- Friendly display names for zones (zone ids are internal)
local ZONE_DISPLAY = {
	GrassNorth = "north Studville", GrassSouth = "south Studville",
	GrassWest = "west Studville", GrassEast = "east Studville",
	FireNorth = "north Emberpeak", FireSouth = "south Emberpeak",
	MagmaWest = "the west magma fields", MagmaEast = "the east magma fields",
	ShoreNorth = "the north shore", ShoreSouth = "the south shore",
	ReefWest = "the west reef", ReefEast = "the east reef",
	StormNorth = "the north storm plains", StormSouth = "the south storm plains",
	StaticWest = "the west static fields", StaticEast = "the east static fields",
	CanyonNorth = "the north canyon", CanyonSouth = "the south canyon",
	GorgeWest = "the west gorge", GorgeEast = "the east gorge",
	MesaRidge = "Mesa Ridge", CanyonFloor = "the canyon floor", RidgePass = "Ridge Pass",
	FrostNorth = "the north tundra", FrostSouth = "the south tundra",
	GlacierWest = "the west glacier", GlacierEast = "the east glacier",
	ShadowNorth = "north Duskwood", ShadowSouth = "south Duskwood",
	DuskWest = "west Duskwood", DuskEast = "east Duskwood",
}

local function pickEvent()
	-- Pick a random zone, then a legendary whose type can appear there
	local zoneNames = {}
	for zoneName in pairs(StudData.ZoneTypes) do
		table.insert(zoneNames, zoneName)
	end
	local zoneName = zoneNames[math.random(#zoneNames)]
	local zoneTypes = StudData.ZoneTypes[zoneName]
	local chosenType = zoneTypes[math.random(#zoneTypes)]

	for _, stud in ipairs(StudData.Studs) do
		if stud.studType == chosenType and stud.rarity == "Legendary" then
			return zoneName, stud
		end
	end
	return nil, nil
end

task.spawn(function()
	while true do
		task.wait(math.random(EVENT_GAP_MIN, EVENT_GAP_MAX))

		local zoneName, stud = pickEvent()
		if zoneName and stud then
			local event = {
				zoneName = zoneName,
				studId = stud.id,
				endsAt = os.time() + EVENT_DURATION,
			}
			ServerRegistry.Register("ActiveLegendaryEvent", event)

			local zoneDisplay = ZONE_DISPLAY[zoneName] or zoneName
			announceEvent:FireAllClients({
				type = "legendaryEvent",
				title = "LEGENDARY SIGHTING!",
				text = "A wild " .. stud.name .. " is roaming " .. zoneDisplay .. " for 5 minutes!",
				studId = stud.id,
				zoneName = zoneName,
				endsAt = event.endsAt,
			})
			print("[EventSystem] Legendary event: " .. stud.name .. " in " .. zoneName)

			task.wait(EVENT_DURATION)
			ServerRegistry.Register("ActiveLegendaryEvent", nil)
			announceEvent:FireAllClients({
				type = "legendaryEventEnd",
				title = "The legendary has fled...",
				text = stud.name .. " has left " .. zoneDisplay .. ".",
			})
		end
	end
end)

print("[EventSystem] Initialized (legendary events every 25-40 min)")
