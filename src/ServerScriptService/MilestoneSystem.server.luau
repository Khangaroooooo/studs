local MilestoneSystem = {}

-- Tracks player milestones and shows achievement notifications
-- Milestones: First Catch, 5/10/24 Studs, First Rare/Legendary, 100/500 coins, etc.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:FindFirstChild("StudEvents")
local StudData = require(ReplicatedStorage:FindFirstChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

-- Milestone definitions
local MILESTONES = {
	{ id = "first_catch", name = "First Catch!", desc = "Catch your first Stud", icon = "🎯" },
	{ id = "collector_5", name = "Novice Collector", desc = "Catch 5 unique Studs", icon = "📘" },
	{ id = "collector_10", name = "Avid Collector", desc = "Catch 10 unique Studs", icon = "📗" },
	{ id = "collector_18", name = "Expert Collector", desc = "Catch 18 unique Studs", icon = "🏆" },
	{ id = "collector_all", name = "Stud Master!", desc = "Catch every Stud!", icon = "👑" },
	{ id = "first_rare", name = "Rare Find!", desc = "Catch a Rare Stud", icon = "💎" },
	{ id = "first_legendary", name = "Legendary!", desc = "Catch a Legendary Stud", icon = "⭐" },
	{ id = "coins_50", name = "Pocket Change", desc = "Earn 50 coins total", icon = "🪙" },
	{ id = "coins_200", name = "Coin Collector", desc = "Earn 200 coins total", icon = "💰" },
	{ id = "coins_500", name = "Wealthy!", desc = "Earn 500 coins total", icon = "🏦" },
	{ id = "catches_10", name = "Getting Started", desc = "Catch 10 total Studs", icon = "🎣" },
	{ id = "catches_50", name = "Dedicated Hunter", desc = "Catch 50 total Studs", icon = "⚡" },
	{ id = "first_shiny", name = "Shiny Hunter", desc = "Catch a Shiny Stud", icon = "✨" },
	{ id = "first_evolution", name = "New Form!", desc = "Evolve a Stud", icon = "🧬" },
	{ id = "first_trade", name = "Introduced a Friend", desc = "Complete your first trade", icon = "🤝" },
	{ id = "first_pvp_win", name = "Duel Victor", desc = "Win a PvP duel", icon = "⚔️" },
	{ id = "first_coop", name = "Better Together", desc = "Play in a server with a friend", icon = "🏡" },
}

-- Helper functions
local function countUnique(data)
	local unique = {}
	for _, caught in ipairs(data.caughtStuds) do
		unique[caught.id] = true
	end
	local count = 0
	for _ in pairs(unique) do count += 1 end
	return count
end

local function hasRarity(data, rarity)
	for _, caught in ipairs(data.caughtStuds) do
		local stud = StudData.GetStudById(caught.id)
		if stud and stud.rarity == rarity then
			return true
		end
	end
	return false
end

local function checkMilestone(data, milestone)
	local id = milestone.id
	if id == "first_catch" then return #data.caughtStuds >= 1
	elseif id == "collector_5" then return countUnique(data) >= 5
	elseif id == "collector_10" then return countUnique(data) >= 10
	elseif id == "collector_18" then return countUnique(data) >= 18
	elseif id == "collector_all" then return countUnique(data) >= #StudData.Studs
	elseif id == "first_rare" then return hasRarity(data, "Rare")
	elseif id == "first_legendary" then return hasRarity(data, "Legendary")
	elseif id == "coins_50" then return (data.coins or 0) >= 50
	elseif id == "coins_200" then return (data.coins or 0) >= 200
	elseif id == "coins_500" then return (data.coins or 0) >= 500
	elseif id == "catches_10" then return (data.totalCaught or 0) >= 10
	elseif id == "catches_50" then return (data.totalCaught or 0) >= 50
	elseif id == "first_shiny" then return #(data.shinyStuds or {}) >= 1
	elseif id == "first_evolution" then return (data.totalEvolutions or 0) >= 1
	elseif id == "first_trade" then return (data.totalTrades or 0) >= 1
	elseif id == "first_pvp_win" then return (data.pvpWins or 0) >= 1
	elseif id == "first_coop" then return data.firstCoopAt ~= nil
	end
	return false
end

local function checkAllMilestones(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	if not activePlayers then return end

	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then return end

	local data = playerInfo.data
	-- Earned milestones live ON the save slot (data.milestones) so they
	-- persist across sessions — previously they were session-only and the
	-- whole achievement parade replayed on every join.
	if not data.milestones then
		data.milestones = {}
	end

	for _, milestone in ipairs(MILESTONES) do
		if not data.milestones[milestone.id] then
			if checkMilestone(data, milestone) then
				data.milestones[milestone.id] = true

				-- Notify client
				local milestoneEvent = StudEvents and StudEvents:FindFirstChild("MilestoneNotify")
				if milestoneEvent then
					milestoneEvent:FireClient(player, milestone.id, milestone.name, milestone.desc, milestone.icon)
				end

				-- BadgeSystem awards a platform badge if one is configured
				ServerRegistry.Call("OnMilestoneEarned", player, milestone.id)

				print("[Milestones] " .. player.Name .. " earned: " .. milestone.name)
			end
		end
	end
end

-- Create MilestoneNotify RemoteEvent if needed
if StudEvents and not StudEvents:FindFirstChild("MilestoneNotify") then
	local milestoneEvent = Instance.new("RemoteEvent")
	milestoneEvent.Name = "MilestoneNotify"
	milestoneEvent.Parent = StudEvents
end

-- Expose checkAllMilestones via the shared server registry so SaveManager,
-- EncounterSystem, and QuestSystem can call it without touching _G
ServerRegistry.Register("CheckMilestones", checkAllMilestones)

-- Periodic sweep is only a SAFETY NET — milestones are already checked
-- event-driven via ServerRegistry on every catch. 60s instead of 10s cuts
-- this O(players) sweep's cost by 6x with no player-visible difference.
task.spawn(function()
	while task.wait(60) do
		for _, player in Players:GetPlayers() do
			checkAllMilestones(player)
		end
	end
end)

print("[MilestoneSystem] Initialized with " .. #MILESTONES .. " milestones")