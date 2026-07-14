-- StatsBoardSystem: Updates the town Stats Board with player progress
-- Shows collection progress, coins, and achievements on the physical board

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 10)
if not StudEvents then return end

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local totalStuds = #StudData.Studs

local function getStatsBoard()
	local studville = Workspace:FindFirstChild("Studville")
	if not studville then return nil end
	local board = studville:FindFirstChild("StatsBoard")
	if not board then return nil end
	local boardBack = board:FindFirstChild("BoardBack")
	if not boardBack then return nil end
	local gui = boardBack:FindFirstChild("BoardGUI")
	if not gui then return nil end
	return gui:FindFirstChild("StatsContent")
end

local function updateBoard()
	local statsLabel = getStatsBoard()
	if not statsLabel then return end

	-- Aggregate stats from all players
	local totalPlayers = #Players:GetPlayers()
	local totalCaught = 0
	local totalCoins = 0
	local bestCollector = "-"
	local bestCount = 0
	local richestPlayer = "-"
	local richestCoins = 0

	for _, player in Players:GetPlayers() do
		-- Stats come from the server-set attributes (SaveManager keeps them
		-- in sync with save data); InvokeServer is a client-only API and the
		-- old pcall'd call here could never work.
		local playerCoins = player:GetAttribute("Coins") or 0
		local playerStuds = player:GetAttribute("StudCount") or 0

		totalCoins = totalCoins + playerCoins
		totalCaught = totalCaught + playerStuds

		if playerStuds > bestCount then
			bestCount = playerStuds
			bestCollector = player.Name
		end

		if playerCoins > richestCoins then
			richestCoins = playerCoins
		richestPlayer = player.Name
		end
	end

	local text = "Total Players: " .. totalPlayers .. "\n"
	text = text .. "Total Studs Caught: " .. totalCaught .. "\n"
	text = text .. "Total Coins in Town: " .. totalCoins .. "\n"
	text = text .. "\n"
	text = text .. "Best Collector: " .. bestCollector .. " (" .. bestCount .. ")\n"
	text = text .. "Richest: " .. richestPlayer .. " (" .. richestCoins .. ")\n"
	text = text .. "\n"
	text = text .. "Stud Types: " .. totalStuds .. " total\n"
	text = text .. "Types: Fire Water Grass\n"
	text = text .. "       Electric Rock Ice\n"
	text = text .. "       Shadow (Night!)"

	statsLabel.Text = text
end

-- Update player attributes when they catch studs (for board tracking)
local function onPlayerAdded(player)
	-- Initialize attributes if not set
	if not player:GetAttribute("Coins") then
		player:SetAttribute("Coins", 0)
	end
	if not player:GetAttribute("StudCount") then
		player:SetAttribute("StudCount", 0)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Update board periodically. The physical stats board iterates all players
-- each refresh, so at high player counts a 10s cadence is 3x the work of 30s
-- for a display nobody watches that closely. Join/leave still trigger
-- immediate refreshes below.
task.spawn(function()
	while task.wait(30) do
		updateBoard()
	end
end)

-- Also update when players join/leave
Players.PlayerAdded:Connect(function()
	task.delay(5, updateBoard)
end)
Players.PlayerRemoving:Connect(function()
	task.delay(2, updateBoard)
end)

print("[StatsBoardSystem] Initialized")