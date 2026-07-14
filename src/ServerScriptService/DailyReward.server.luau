-- DailyReward: Gives players bonus coins for logging in each day
-- Streak system: consecutive days give bigger rewards
-- Day 1: 50 coins, Day 2: 75, Day 3: 100, Day 4: 150, Day 5+: 200

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 10)
if not StudEvents then return end

local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local DAILY_REWARDS = {50, 75, 100, 150, 200}
local MAX_STREAK = #DAILY_REWARDS

local function onPlayerAdded(player)
	task.spawn(function()
		-- Save data only exists AFTER the player picks New/Load on the menu,
		-- so wait for it instead of checking once at +3s (which always found
		-- nil and meant the daily reward never actually fired for anyone).
		local playerInfo
		while player.Parent do
			local activePlayers = ServerRegistry.Get("ActivePlayers")
			playerInfo = activePlayers and activePlayers[player.UserId]
			if playerInfo and playerInfo.data then break end
			task.wait(2)
		end
		if not player.Parent or not playerInfo or not playerInfo.data then return end

		local data = playerInfo.data
		local lastDaily = data.lastDailyReward or 0
		local dailyStreak = data.dailyStreak or 0
		local now = os.time()

		-- Check if enough time has passed (20 hours minimum)
		local COOLDOWN = 20 * 3600 -- 20 hours

		if now - lastDaily >= COOLDOWN then
			-- Calculate streak
			local timeSinceLast = now - lastDaily
			if lastDaily == 0 or timeSinceLast > 48 * 3600 then
				-- New streak or streak broken (more than 48h)
				dailyStreak = 1
			else
				-- Continue streak
				dailyStreak = math.min(dailyStreak + 1, MAX_STREAK)
			end

			local rewardAmount = DAILY_REWARDS[dailyStreak] or DAILY_REWARDS[MAX_STREAK]

			-- Persist to save data
			data.lastDailyReward = now
			data.dailyStreak = dailyStreak

			-- Also set attributes for client-side UI reads
			player:SetAttribute("LastDailyReward", now)
			player:SetAttribute("DailyStreak", dailyStreak)

			-- Award coins via SaveManager
			data.coins = (data.coins or 0) + rewardAmount
			StudEvents.UpdateCoins:FireClient(player, data.coins)
			player:SetAttribute("Coins", data.coins)

			-- Notify client of daily reward
			local rewardEvent = StudEvents:FindFirstChild("EncounterResult")
			if rewardEvent then
				rewardEvent:FireClient(player, {
					type = "dailyReward",
					coins = rewardAmount,
					streak = dailyStreak,
				})
			end

			print("[DailyReward] Awarded", rewardAmount, "coins to", player.Name, "(streak:", dailyStreak, ")")
		else
			-- Sync attributes from persisted data so client can read streak info
			player:SetAttribute("LastDailyReward", lastDaily)
			player:SetAttribute("DailyStreak", dailyStreak)
			local remaining = COOLDOWN - (now - lastDaily)
			print("[DailyReward]", player.Name, "already claimed. Next in", math.floor(remaining / 3600), "h", math.floor((remaining % 3600) / 60), "m")
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[DailyReward] Initialized successfully")