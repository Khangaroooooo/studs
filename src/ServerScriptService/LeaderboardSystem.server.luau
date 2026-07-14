-- LeaderboardSystem: Tracks and broadcasts top player rankings
-- Categories: Most Catches, Richest (Coins), Best Dex Completion
-- Updates every 30 seconds.
-- GLOBAL boards: OrderedDataStores persist every player's best TotalCaught /
-- UniqueCount / ShinyCount across all servers; top 10 fetched periodically.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local StudEvents = ReplicatedStorage:FindFirstChild("StudEvents")
if not StudEvents then
	warn("[LeaderboardSystem] StudEvents folder not found!")
	return
end

-- Create or get the LeaderboardUpdate RemoteEvent
local leaderboardEvent = StudEvents:FindFirstChild("LeaderboardUpdate")
if not leaderboardEvent then
	leaderboardEvent = Instance.new("RemoteEvent")
	leaderboardEvent.Name = "LeaderboardUpdate"
	leaderboardEvent.Parent = StudEvents
end

-- Create or get the RequestLeaderboard RemoteFunction
local requestLeaderboard = StudEvents:FindFirstChild("RequestLeaderboard")
if not requestLeaderboard then
	requestLeaderboard = Instance.new("RemoteFunction")
	requestLeaderboard.Name = "RequestLeaderboard"
	requestLeaderboard.Parent = StudEvents
end

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local totalSpecies = StudData.GetTotalSpecies()

-- Cache player stats for leaderboard calculations
local playerStatsCache = {} -- [userId] = { name, totalCaught, coins, uniqueCount }

-- Build leaderboard data from all online players
local function buildLeaderboard()
	local catchBoard = {}
	local coinsBoard = {}
	local dexBoard = {}

	for _, player in Players:GetPlayers() do
		local stats = playerStatsCache[player.UserId]
		if stats then
			table.insert(catchBoard, {
				name = stats.name,
				value = stats.totalCaught or 0,
			})
			table.insert(coinsBoard, {
				name = stats.name,
				value = stats.coins or 0,
			})
			table.insert(dexBoard, {
				name = stats.name,
				value = stats.uniqueCount or 0,
				maxValue = totalSpecies,
			})
		end
	end

	-- Sort each board descending
	table.sort(catchBoard, function(a, b) return a.value > b.value end)
	table.sort(coinsBoard, function(a, b) return a.value > b.value end)
	table.sort(dexBoard, function(a, b) return a.value > b.value end)

	-- Trim to top 10
	local function trim(board, max)
		local result = {}
		for i = 1, math.min(#board, max) do
			table.insert(result, board[i])
		end
		return result
	end

	return {
		catches = trim(catchBoard, 10),
		coins = trim(coinsBoard, 10),
		dex = trim(dexBoard, 10),
	}
end

-- Update stats cache from player attributes
local function refreshPlayerStats(player)
	local totalCaught = player:GetAttribute("TotalCaught") or 0
	local coins = player:GetAttribute("Coins") or 0
	local uniqueCount = player:GetAttribute("UniqueCount") or 0

	playerStatsCache[player.UserId] = {
		name = player.Name,
		totalCaught = totalCaught,
		coins = coins,
		uniqueCount = uniqueCount,
	}
end

-- Listen for stat attribute changes to keep cache fresh
local function onPlayerAdded(player)
	refreshPlayerStats(player)

	-- Watch for attribute changes
	for _, attr in ipairs({"TotalCaught", "Coins", "UniqueCount"}) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			refreshPlayerStats(player)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	playerStatsCache[player.UserId] = nil
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- ─── GLOBAL (CROSS-SERVER) LEADERBOARDS ────────────────────────────────

local GLOBAL_BOARDS = {
	{ key = "catches", store = "GlobalLB_TotalCaught_v1", attr = "TotalCaught" },
	{ key = "dex", store = "GlobalLB_UniqueCount_v1", attr = "UniqueCount" },
	{ key = "shinies", store = "GlobalLB_ShinyCount_v1", attr = "ShinyCount" },
}

local orderedStores = {}
local globalAvailable = false
do
	local ok = pcall(function()
		for _, board in ipairs(GLOBAL_BOARDS) do
			orderedStores[board.key] = DataStoreService:GetOrderedDataStore(board.store)
		end
		-- Probe: OrderedDataStore also only fails on first real request
		orderedStores.catches:GetSortedAsync(false, 1)
	end)
	globalAvailable = ok
	if not ok then
		warn("[LeaderboardSystem] OrderedDataStores unavailable (Studio?) — global boards disabled")
	end
end

local globalTops = { catches = {}, dex = {}, shinies = {} }
local nameCache = {} -- [userId] = username

local function resolveName(userId)
	if nameCache[userId] then return nameCache[userId] end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.Name
		return online.Name
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = ok and name or "???"
	return nameCache[userId]
end

-- ShinyCount isn't a synced attribute; read it straight from save data
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local function getShinyCount(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	if playerInfo and playerInfo.data and playerInfo.data.shinyStuds then
		return #playerInfo.data.shinyStuds
	end
	return 0
end

local function pushGlobalScores(player)
	if not globalAvailable then return end
	for _, board in ipairs(GLOBAL_BOARDS) do
		local value
		if board.key == "shinies" then
			value = getShinyCount(player)
		else
			value = player:GetAttribute(board.attr) or 0
		end
		if value > 0 then
			pcall(function()
				-- Keep the best score ever (multi-slot players shouldn't
				-- lose rank for playing a fresh slot)
				orderedStores[board.key]:UpdateAsync(tostring(player.UserId), function(old)
					if old and old >= value then return old end
					return value
				end)
			end)
		end
	end
end

local function fetchGlobalTops()
	if not globalAvailable then return end
	for _, board in ipairs(GLOBAL_BOARDS) do
		pcall(function()
			local pages = orderedStores[board.key]:GetSortedAsync(false, 10)
			local top = {}
			for _, item in ipairs(pages:GetCurrentPage()) do
				table.insert(top, {
					name = resolveName(tonumber(item.key)),
					value = item.value,
				})
			end
			globalTops[board.key] = top
		end)
	end
end

-- Push + fetch loop (staggered; OrderedDataStore budgets are modest)
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in Players:GetPlayers() do
			pushGlobalScores(player)
			task.wait(1)
		end
		fetchGlobalTops()
	end
end)

Players.PlayerRemoving:Connect(pushGlobalScores)

-- Initial fetch shortly after startup
task.delay(5, fetchGlobalTops)

-- ─── BROADCAST ─────────────────────────────────────────────────────────

local function buildPayload()
	local data = buildLeaderboard()
	data.global = globalTops
	return data
end

-- Broadcast leaderboard updates every 30 seconds
task.spawn(function()
	while task.wait(30) do
		leaderboardEvent:FireAllClients(buildPayload())
	end
end)

-- Handle on-demand requests
requestLeaderboard.OnServerInvoke = function(player)
	refreshPlayerStats(player)
	return buildPayload()
end

print("[LeaderboardSystem] Initialized")