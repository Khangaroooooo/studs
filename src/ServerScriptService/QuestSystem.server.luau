-- QuestSystem: Gives players catch quests with coin rewards
-- Quests are assigned by NPCs and tracked server-side
--
-- Quest progress (activeQuests/completedQuests/progress) is mirrored onto
-- playerInfo.data.questState, which is the same per-slot table SaveManager
-- persists — so progress survives rejoins/restarts instead of resetting.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

-- Quest definitions
local QUEST_TEMPLATES = {
	{
		id = "catch_type_fire",
		name = "Fire Finder",
		description = "Catch 2 Fire-type Studs",
		targetType = "Fire",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_type_water",
		name = "Water Collector",
		description = "Catch 2 Water-type Studs",
		targetType = "Water",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_type_grass",
		name = "Green Thumb",
		description = "Catch 2 Grass-type Studs",
		targetType = "Grass",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_type_electric",
		name = "Spark Chaser",
		description = "Catch 2 Electric-type Studs",
		targetType = "Electric",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_type_rock",
		name = "Rock Hound",
		description = "Catch 2 Rock-type Studs",
		targetType = "Rock",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_type_ice",
		name = "Ice Hunter",
		description = "Catch 2 Ice-type Studs",
		targetType = "Ice",
		targetCount = 2,
		reward = 30,
		npc = "Professor Brick",
	},
	{
		id = "catch_rare",
		name = "Rare Find",
		description = "Catch a Rare Stud",
		targetRarity = "Rare",
		targetCount = 1,
		reward = 50,
		npc = "Shopkeeper Tile",
	},
	{
		id = "catch_legendary",
		name = "Legendary Quest",
		description = "Catch a Legendary Stud",
		targetRarity = "Legendary",
		targetCount = 1,
		reward = 150,
		npc = "Professor Brick",
	},
	{
		id = "catch_total_5",
		name = "Getting Started",
		description = "Catch 5 Studs total",
		targetTotal = 5,
		reward = 25,
		npc = "Villager Cobble",
	},
	{
		id = "catch_total_10",
		name = "Dedicated Collector",
		description = "Catch 10 Studs total",
		targetTotal = 10,
		reward = 50,
		npc = "Villager Cobble",
	},
	{
		id = "catch_total_20",
		name = "Master Collector",
		description = "Catch 20 Studs total",
		targetTotal = 20,
		reward = 100,
		npc = "Villager Cobble",
	},
	{
		id = "catch_unique_6",
		name = "Type Explorer",
		description = "Catch one Stud of each type",
		targetUniqueTypes = 6,
		reward = 75,
		npc = "Professor Brick",
	},
	{
		id = "sell_stud",
		name = "First Sale",
		description = "Sell a duplicate Stud at the Shop",
		targetSell = 1,
		reward = 15,
		npc = "Shopkeeper Tile",
	},
	{
		id = "wish_well",
		name = "Make a Wish",
		description = "Make a wish at the Wishing Well",
		targetWish = 1,
		reward = 10,
		npc = "Villager Cobble",
	},
}

-- ─── DAILY QUESTS ───────────────────────────────────────────────────────
-- 3 random quests from this pool, rerolled every UTC day. Unlike the main
-- one-shot templates (which scan the collection), dailies count events
-- incrementally from the moment they're assigned, so they're always a
-- fresh task. Completing all 3 pays a bonus.
local DAILY_POOL = {
	{ kind = "catch_type", param = "Fire", target = 3, reward = 40, name = "Daily: Flame Patrol", desc = "Catch 3 Fire-type Studs today" },
	{ kind = "catch_type", param = "Water", target = 3, reward = 40, name = "Daily: Tide Watch", desc = "Catch 3 Water-type Studs today" },
	{ kind = "catch_type", param = "Grass", target = 3, reward = 40, name = "Daily: Garden Duty", desc = "Catch 3 Grass-type Studs today" },
	{ kind = "catch_type", param = "Electric", target = 3, reward = 40, name = "Daily: Storm Chaser", desc = "Catch 3 Electric-type Studs today" },
	{ kind = "catch_type", param = "Rock", target = 3, reward = 40, name = "Daily: Rock Steady", desc = "Catch 3 Rock-type Studs today" },
	{ kind = "catch_type", param = "Ice", target = 3, reward = 40, name = "Daily: Cold Snap", desc = "Catch 3 Ice-type Studs today" },
	{ kind = "catch_any", target = 5, reward = 50, name = "Daily: Field Work", desc = "Catch 5 Studs today" },
	{ kind = "catch_any", target = 8, reward = 80, name = "Daily: Marathon Hunt", desc = "Catch 8 Studs today" },
	{ kind = "catch_rarity", param = "Rare", target = 1, reward = 60, name = "Daily: Rare Sighting", desc = "Catch a Rare (or better) Stud today" },
	{ kind = "sell", target = 2, reward = 35, name = "Daily: Merchant Run", desc = "Sell 2 Studs today" },
	{ kind = "battle_win", target = 2, reward = 50, name = "Daily: Arena Regular", desc = "Win 2 battles today (arena or duel)" },
	{ kind = "wish", target = 1, reward = 25, name = "Daily: Well Wisher", desc = "Make a wish at the Wishing Well today" },
}
local DAILY_COUNT = 3
local DAILY_BONUS = 100

-- PERF: O(1) template lookup — quest-by-id linear scans used to repeat in
-- five separate handlers
local QUEST_BY_ID = {}
for _, quest in ipairs(QUEST_TEMPLATES) do
	QUEST_BY_ID[quest.id] = quest
end

local RARITY_ORDER = { Common = 1, Uncommon = 2, Rare = 3, Legendary = 4 }

local function currentDay()
	return math.floor(os.time() / 86400)
end

-- Ensure data.dailyQuests exists and belongs to today; reroll otherwise
local function ensureDailyQuests(playerInfo)
	local data = playerInfo.data
	if not data then return nil end
	local today = currentDay()
	if data.dailyQuests and data.dailyQuests.day == today then
		return data.dailyQuests
	end

	-- Reroll: pick DAILY_COUNT distinct quests from the pool
	local indices = {}
	for i = 1, #DAILY_POOL do
		table.insert(indices, i)
	end
	local quests = {}
	for _ = 1, math.min(DAILY_COUNT, #indices) do
		local pick = table.remove(indices, math.random(#indices))
		local template = DAILY_POOL[pick]
		table.insert(quests, {
			kind = template.kind,
			param = template.param,
			target = template.target,
			reward = template.reward,
			name = template.name,
			desc = template.desc,
			progress = 0,
			done = false,
		})
	end
	data.dailyQuests = { day = today, quests = quests, bonusClaimed = false }
	return data.dailyQuests
end

-- Track player quest state (session-side mirror of playerInfo.data.questState)
local playerQuests = {} -- [userId] = { activeQuests = {}, completedQuests = {}, progress = {}, hydrated = bool }

-- Create a RemoteEvent for quest interactions
local questEvent = Instance.new("RemoteEvent")
questEvent.Name = "QuestAction"
questEvent.Parent = StudEvents

local questRequestFunc = Instance.new("RemoteFunction")
questRequestFunc.Name = "QuestRequest"
questRequestFunc.Parent = StudEvents

local function createPlayerQuestState()
	return {
		activeQuests = {},     -- list of quest ids currently active
		completedQuests = {},  -- set of quest ids already completed
		progress = {},         -- [questId] = current progress count
		hydrated = false,      -- whether we've loaded/initialized questState from save data yet
	}
end

-- ─── SAVE PERSISTENCE (questState lives inside the SaveManager-owned data table) ──

local function getPlayerInfo(userId)
	local activePlayersData = ServerRegistry.Get("ActivePlayers")
	return activePlayersData and activePlayersData[userId]
end

-- Bump matching daily quests after a validated event; pays out completions
-- and the all-done bonus
local function bumpDailyQuests(player, kind, param)
	local playerInfo = getPlayerInfo(player.UserId)
	if not playerInfo or not playerInfo.data then return end
	local daily = ensureDailyQuests(playerInfo)
	if not daily then return end

	local changed = false
	for _, quest in ipairs(daily.quests) do
		if not quest.done and quest.kind == kind then
			local matches = true
			if kind == "catch_type" then
				matches = quest.param == param
			elseif kind == "catch_rarity" then
				matches = (RARITY_ORDER[param] or 0) >= (RARITY_ORDER[quest.param] or 99)
			end
			if matches then
				quest.progress += 1
				changed = true
				if quest.progress >= quest.target then
					quest.done = true
					playerInfo.data.coins = (playerInfo.data.coins or 0) + quest.reward
					questEvent:FireClient(player, {
						action = "completed",
						questId = "daily",
						questName = quest.name,
						reward = quest.reward,
					})
				end
			end
		end
	end
	if not changed then return end

	-- All-done bonus
	if not daily.bonusClaimed then
		local allDone = true
		for _, quest in ipairs(daily.quests) do
			if not quest.done then
				allDone = false
				break
			end
		end
		if allDone then
			daily.bonusClaimed = true
			playerInfo.data.coins = (playerInfo.data.coins or 0) + DAILY_BONUS
			questEvent:FireClient(player, {
				action = "completed",
				questId = "daily_bonus",
				questName = "All Dailies Complete!",
				reward = DAILY_BONUS,
			})
		end
	end

	StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
	ServerRegistry.Call("SyncPlayerAttributes", player, playerInfo.data)
end

-- Pull questState off the persisted save (once it's loaded) or seed a fresh
-- one onto it. Safe to call repeatedly — no-ops once already hydrated, and
-- gracefully no-ops if the player hasn't picked New/Load yet (data == nil),
-- so quests still work session-only in that window and catch up once data
-- becomes available.
local function hydrateQuestState(player)
	local state = playerQuests[player.UserId]
	if not state or state.hydrated then return end

	local playerInfo = getPlayerInfo(player.UserId)
	if not playerInfo or not playerInfo.data then return end

	local saved = playerInfo.data.questState
	if saved then
		-- Drop ids that aren't real quests. Saves written before the accept
		-- handler validated its input can carry junk ids that no longer match
		-- any template; left in place they'd sit in activeQuests forever
		-- (nothing can complete them) and hold an active-quest slot.
		--
		-- Sanitize IN PLACE. state.* must stay aliased to the saved tables:
		-- checkQuestProgress writes state.progress[questId] without calling
		-- persistQuestState on the non-completing path, so it relies on those
		-- being the same tables the autosave reads. Rebinding to fresh tables
		-- here would silently stop ordinary progress from being saved.
		saved.activeQuests = saved.activeQuests or {}
		for i = #saved.activeQuests, 1, -1 do
			local questId = saved.activeQuests[i]
			if type(questId) ~= "string" or not QUEST_BY_ID[questId] then
				table.remove(saved.activeQuests, i)
			end
		end
		saved.completedQuests = saved.completedQuests or {}
		for questId in pairs(saved.completedQuests) do
			if type(questId) ~= "string" or not QUEST_BY_ID[questId] then
				saved.completedQuests[questId] = nil
			end
		end
		saved.progress = saved.progress or {}
		for questId, value in pairs(saved.progress) do
			if type(questId) ~= "string" or not QUEST_BY_ID[questId] or type(value) ~= "number" then
				saved.progress[questId] = nil
			end
		end

		state.activeQuests = saved.activeQuests
		state.completedQuests = saved.completedQuests
		state.progress = saved.progress
	else
		playerInfo.data.questState = {
			activeQuests = state.activeQuests,
			completedQuests = state.completedQuests,
			progress = state.progress,
		}
	end
	state.hydrated = true
end

-- Write the current in-memory quest state back onto playerInfo.data so the
-- next autosave / PlayerRemoving / BindToClose save captures it.
local function persistQuestState(player)
	local state = playerQuests[player.UserId]
	local playerInfo = getPlayerInfo(player.UserId)
	if not state or not playerInfo or not playerInfo.data then return end

	playerInfo.data.questState = {
		activeQuests = state.activeQuests,
		completedQuests = state.completedQuests,
		progress = state.progress,
	}
end

-- ─── QUEST LOGIC ────────────────────────────────────────────────────────

local function getAvailableQuests(userId)
	local state = playerQuests[userId]
	if not state then return {} end

	local available = {}
	for _, quest in ipairs(QUEST_TEMPLATES) do
		-- Not already completed and not already active
		if not state.completedQuests[quest.id] then
			local isActive = false
			for _, activeId in ipairs(state.activeQuests) do
				if activeId == quest.id then
					isActive = true
					break
				end
			end
			if not isActive then
				table.insert(available, quest)
			end
		end
	end
	return available
end

local function checkQuestProgress(player, questId)
	hydrateQuestState(player)

	local state = playerQuests[player.UserId]
	if not state then return end

	local quest = QUEST_BY_ID[questId]
	if not quest then return end

	-- Get player's caught studs from SaveManager
	local playerInfo = getPlayerInfo(player.UserId)
	if not playerInfo or not playerInfo.data then return end

	-- PERF: count via the SaveManager-maintained species-count cache
	-- ([studId] = copies owned) — O(unique species) instead of O(collection).
	-- Falls back to a one-off scan for saves that predate the cache.
	local speciesCounts = playerInfo.data.speciesCounts
	if not speciesCounts then
		speciesCounts = {}
		for _, caught in ipairs(playerInfo.data.caughtStuds or {}) do
			speciesCounts[caught.id] = (speciesCounts[caught.id] or 0) + 1
		end
		playerInfo.data.speciesCounts = speciesCounts
	end
	local progress = 0

	if quest.targetType then
		-- Count studs of specific type
		for studId, count in pairs(speciesCounts) do
			local studInfo = StudData.GetStudById(studId)
			if studInfo and studInfo.studType == quest.targetType then
				progress = progress + count
			end
		end
	elseif quest.targetRarity then
		-- Count studs of specific rarity
		for studId, count in pairs(speciesCounts) do
			local studInfo = StudData.GetStudById(studId)
			if studInfo and studInfo.rarity == quest.targetRarity then
				progress = progress + count
			end
		end
	elseif quest.targetTotal then
		progress = #(playerInfo.data.caughtStuds or {})
	elseif quest.targetUniqueTypes then
		local types = {}
		for studId in pairs(speciesCounts) do
			local studInfo = StudData.GetStudById(studId)
			if studInfo then
				types[studInfo.studType] = true
			end
		end
		local count = 0
		for _ in pairs(types) do count = count + 1 end
		progress = count
	elseif quest.targetSell then
		progress = state.progress[questId] or 0
	elseif quest.targetWish then
		progress = state.progress[questId] or 0
	end

	state.progress[questId] = progress

	-- Check if quest is complete
	local target = quest.targetCount or quest.targetTotal or quest.targetUniqueTypes or quest.targetSell or quest.targetWish or 1
	if progress >= target then
		-- Complete the quest!
		for i, activeId in ipairs(state.activeQuests) do
			if activeId == questId then
				table.remove(state.activeQuests, i)
				break
			end
		end
		state.completedQuests[questId] = true

		-- Award coins
		if playerInfo.data then
			playerInfo.data.coins = (playerInfo.data.coins or 0) + quest.reward
			StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
		end

		persistQuestState(player)

		-- Notify client
		questEvent:FireClient(player, {
			action = "completed",
			questId = questId,
			questName = quest.name,
			reward = quest.reward,
		})

		-- Check milestones
		task.defer(function()
			ServerRegistry.Call("CheckMilestones", player)
		end)

		print("[QuestSystem] Player", player.Name, "completed quest:", quest.name)
	else
		persistQuestState(player)

		-- Update progress on client
		questEvent:FireClient(player, {
			action = "progress",
			questId = questId,
			progress = progress,
			target = target,
		})
	end
end

-- Accept a quest
questEvent.OnServerEvent:Connect(function(player, data)
	if type(data) ~= "table" then return end

	hydrateQuestState(player)

	if data.action == "accept" then
		local questId = data.questId
		-- Must be a REAL quest id, not merely truthy. An unvalidated id reaches
		-- state.progress[questId] below, which is persisted into the save: a
		-- table or number key there makes the DataStore write throw (non-string
		-- / mixed keys don't serialize), so every later autosave for that player
		-- fails and their whole save — not just quests — stops persisting. It
		-- also permanently consumes one of the 3 active-quest slots, because a
		-- junk id can never complete and there is no abandon path.
		if type(questId) ~= "string" or not QUEST_BY_ID[questId] then return end

		local state = playerQuests[player.UserId]
		if not state then return end

		-- Max 3 active quests at a time
		if #state.activeQuests >= 3 then
			questEvent:FireClient(player, {
				action = "error",
				message = "You can only have 3 active quests!",
			})
			return
		end

		-- Check not already active or completed
		if state.completedQuests[questId] then return end
		for _, activeId in ipairs(state.activeQuests) do
			if activeId == questId then return end
		end

		table.insert(state.activeQuests, questId)
		state.progress[questId] = 0
		persistQuestState(player)

		questEvent:FireClient(player, {
			action = "accepted",
			questId = questId,
		})

		-- Immediately check progress
		checkQuestProgress(player, questId)

	elseif data.action == "check" then
		-- Manually check all active quests
		local state = playerQuests[player.UserId]
		if state then
			for _, questId in ipairs(state.activeQuests) do
				checkQuestProgress(player, questId)
			end
		end
	end
end)

-- Client requests quest data
questRequestFunc.OnServerInvoke = function(player)
	hydrateQuestState(player)

	local state = playerQuests[player.UserId]
	if not state then
		return { active = {}, available = {}, completed = {}, progress = {} }
	end

	local active = {}
	for _, questId in ipairs(state.activeQuests) do
		local q = QUEST_BY_ID[questId]
		if q then
			table.insert(active, {
				id = q.id,
				name = q.name,
				description = q.description,
				reward = q.reward,
				npc = q.npc,
				progress = state.progress[q.id] or 0,
				target = q.targetCount or q.targetTotal or q.targetUniqueTypes or q.targetSell or q.targetWish or 1,
			})
		end
	end

	local available = getAvailableQuests(player.UserId)
	local availList = {}
	for _, q in ipairs(available) do
		table.insert(availList, {
			id = q.id,
			name = q.name,
			description = q.description,
			reward = q.reward,
			npc = q.npc,
		})
	end

	-- Send display names too — the client used to render raw quest ids
	-- ("catch_type_fire") in the Completed tab
	local completed = {}
	for questId, _ in pairs(state.completedQuests) do
		local q = QUEST_BY_ID[questId]
		table.insert(completed, { id = questId, name = q and q.name or questId })
	end

	-- Daily quests (rerolled per UTC day; nil until a save is loaded)
	local daily = nil
	local playerInfo = getPlayerInfo(player.UserId)
	if playerInfo and playerInfo.data then
		local dailyState = ensureDailyQuests(playerInfo)
		if dailyState then
			local quests = {}
			for _, quest in ipairs(dailyState.quests) do
				table.insert(quests, {
					name = quest.name,
					desc = quest.desc,
					reward = quest.reward,
					progress = quest.progress,
					target = quest.target,
					done = quest.done,
				})
			end
			daily = {
				quests = quests,
				bonus = DAILY_BONUS,
				bonusClaimed = dailyState.bonusClaimed,
				resetsIn = (currentDay() + 1) * 86400 - os.time(),
			}
		end
	end

	return {
		active = active,
		available = availList,
		completed = completed,
		progress = state.progress,
		daily = daily,
	}
end

-- Hook into catch events via the shared server registry
-- (CatchSuccess is a server->client RemoteEvent, so OnServerEvent never fires)
ServerRegistry.Register("OnStudCaught", function(player, studId)
	-- Daily quest progress (incremental, validated server-side)
	local studInfo = StudData.GetStudById(studId)
	if studInfo then
		bumpDailyQuests(player, "catch_type", studInfo.studType)
		bumpDailyQuests(player, "catch_any")
		bumpDailyQuests(player, "catch_rarity", studInfo.rarity)
	end

	-- OnStudCaught fires synchronously from GrantCatch AFTER the collection
	-- insert, so the data is already current — the old 0.5s deferred re-scan
	-- was dead weight (and a race window).
	hydrateQuestState(player)
	local state = playerQuests[player.UserId]
	if state then
		for _, questId in ipairs(state.activeQuests) do
			checkQuestProgress(player, questId)
		end
	end
end)

-- Battle wins: BattleSystem (arena) and PvPSystem (duel faint-wins only)
-- both call this after a validated win
ServerRegistry.Register("OnBattleWon", function(player)
	bumpDailyQuests(player, "battle_win")
end)

-- Hook into sell events — via ServerRegistry so progress only counts sales
-- SaveManager has actually validated (previously the raw remote could be
-- spammed with fake studIds to farm sell-quest progress).
ServerRegistry.Register("OnStudSold", function(player, studId)
	bumpDailyQuests(player, "sell")
	hydrateQuestState(player)
	local state = playerQuests[player.UserId]
	if state then
		for _, questId in ipairs(state.activeQuests) do
			local quest = QUEST_BY_ID[questId]
			if quest and quest.targetSell then
				state.progress[questId] = (state.progress[questId] or 0) + 1
				checkQuestProgress(player, questId)
			end
		end
	end
end)

-- Hook into wishing well
local function onWishMade(player)
	bumpDailyQuests(player, "wish")
	hydrateQuestState(player)
	local state = playerQuests[player.UserId]
	if state then
		for _, questId in ipairs(state.activeQuests) do
			local quest = QUEST_BY_ID[questId]
			if quest and quest.targetWish then
				state.progress[questId] = (state.progress[questId] or 0) + 1
				checkQuestProgress(player, questId)
			end
		end
	end
end

-- Listen for wish results
Players.PlayerAdded:Connect(function(player)
	playerQuests[player.UserId] = createPlayerQuestState()

	-- Hook into wish attribute changes
	player:GetAttributeChangedSignal("WishResult"):Connect(function()
		local result = player:GetAttribute("WishResult")
		if result and result ~= "none" then
			onWishMade(player)
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	-- Final best-effort sync in case anything changed since the last persist
	-- call above (harmless if it races with SaveManager's own save, since
	-- persistQuestState only touches the in-memory table, not the DataStore).
	persistQuestState(player)
	playerQuests[player.UserId] = nil
end)

-- Handle players already in game
for _, player in Players:GetPlayers() do
	playerQuests[player.UserId] = createPlayerQuestState()
end

print("[QuestSystem] Initialized with " .. #QUEST_TEMPLATES .. " quests (progress now persists across sessions)")
