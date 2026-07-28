-- SaveManager: Handles player data persistence with DataStoreService
-- Supports multiple save slots per player (up to MAX_SLOTS)
-- Slot metadata stored under player_<userId>_slots
-- Slot data stored under player_<userId>_slot_<n>
-- Session lock stored under player_<userId>_session (dupe-on-rejoin defense)

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local BattleTeam = require(ReplicatedStorage:WaitForChild("BattleTeam"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

-- NOTE: CatchSuccess is NOT created here anymore — it now ships as a synced
-- static RemoteEvent (StudEvents/CatchSuccess.model.json). Creating a second
-- one at runtime left two same-named siblings under StudEvents, so
-- `StudEvents.CatchSuccess` / `FindFirstChild("CatchSuccess")` calls in
-- EncounterSystem and various client scripts could resolve to either copy
-- depending on script load order — breaking catch-result delivery
-- intermittently. Removed the duplicate creation; the static instance is
-- used directly everywhere.

-- Rename save slot event
local renameSaveSlotEvent = Instance.new("RemoteEvent")
renameSaveSlotEvent.Name = "RenameSaveSlot"
renameSaveSlotEvent.Parent = StudEvents

-- Stud nickname remote (InventoryUI rename button)
local renameStudFunc = Instance.new("RemoteFunction")
renameStudFunc.Name = "RenameStud"
renameStudFunc.Parent = StudEvents

-- Starter selection (brand-new saves): server offers, client picks one of
-- StudData.Starters via StarterChoiceUI
local offerStarterEvent = Instance.new("RemoteEvent")
offerStarterEvent.Name = "OfferStarter"
offerStarterEvent.Parent = StudEvents

local chooseStarterFunc = Instance.new("RemoteFunction")
chooseStarterFunc.Name = "ChooseStarter"
chooseStarterFunc.Parent = StudEvents

-- Equip/unequip an earned dex-completion title (SettingsMenu title picker)
local equipTitleFunc = Instance.new("RemoteFunction")
equipTitleFunc.Name = "EquipTitle"
equipTitleFunc.Parent = StudEvents

-- Tutorial completion event (client fires when the intro tutorial is done)
local tutorialCompleteEvent = Instance.new("RemoteEvent")
tutorialCompleteEvent.Name = "TutorialComplete"
tutorialCompleteEvent.Parent = StudEvents

-- Try to get the DataStore (may fail in Studio without API access).
-- IMPORTANT: GetDataStore() itself does NOT error in Studio when API access
-- is disabled — only the first real request does. So we probe with an actual
-- GetAsync; otherwise dataStoreAvailable is wrongly true, every write silently
-- fails after retries, the memory fallback never engages, and saves never
-- appear in the Load menu.
local dataStore
local dataStoreAvailable = false
local success, err = pcall(function()
	dataStore = DataStoreService:GetDataStore("StudGamePlayerData_v1")
	dataStore:GetAsync("__availability_probe__")
end)
dataStoreAvailable = success
if not success then
	warn("DataStore not available (likely Studio mode). Using in-memory storage.")
	warn("Saves will NOT survive between play sessions until Studio API access is enabled: Game Settings > Security > 'Enable Studio Access to API Services'.")
end
-- Let clients know whether saves actually persist (SaveLoadUI shows a notice)
ReplicatedStorage:SetAttribute("SavesPersist", dataStoreAvailable)

-- In-memory fallback for Studio testing
local memoryStore = {}
local memorySlotLists = {}

local MAX_SLOTS = 10

-- ─── RETRY-SAFE DATASTORE ACCESS ────────────────────────────────────────
-- Wraps GetAsync/SetAsync with retries + backoff so a single transient
-- DataStore hiccup doesn't silently drop a read or a write. Returns
-- (success, data) for reads and (success) for writes.

local RETRY_ATTEMPTS = 3
local RETRY_BACKOFF = 1 -- seconds, multiplied by attempt number

local function robustGetAsync(key)
	if not dataStoreAvailable then return false, nil end
	local lastErr
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, result = pcall(function()
			return dataStore:GetAsync(key)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < RETRY_ATTEMPTS then
			task.wait(RETRY_BACKOFF * attempt)
		end
	end
	warn("[SaveManager] GetAsync failed after " .. RETRY_ATTEMPTS .. " attempts for key '" .. key .. "': " .. tostring(lastErr))
	return false, nil
end

local function robustSetAsync(key, value)
	if not dataStoreAvailable then return false end
	local lastErr
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, err = pcall(function()
			dataStore:SetAsync(key, value)
		end)
		if ok then
			return true
		end
		lastErr = err
		if attempt < RETRY_ATTEMPTS then
			task.wait(RETRY_BACKOFF * attempt)
		end
	end
	warn("[SaveManager] SetAsync failed after " .. RETRY_ATTEMPTS .. " attempts for key '" .. key .. "': " .. tostring(lastErr))
	return false
end

-- SetAsync(key, nil) is rejected by DataStoreService, so deletions need
-- RemoveAsync — passing nil through robustSetAsync silently failed forever,
-- which meant "deleted" slots and migrated legacy keys never actually left
-- the DataStore.
-- UpdateAsync wrapper: transform(currentValue) -> newValue (or nil to abort).
-- Used for all slot-data writes and the session lock — unlike SetAsync it
-- serializes concurrent writers, which is the foundation the session lock
-- (below) needs to be race-free.
local function robustUpdateAsync(key, transform)
	if not dataStoreAvailable then return false, nil end
	local lastErr
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, result = pcall(function()
			return dataStore:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		if attempt < RETRY_ATTEMPTS then
			task.wait(RETRY_BACKOFF * attempt)
		end
	end
	warn("[SaveManager] UpdateAsync failed after " .. RETRY_ATTEMPTS .. " attempts for key '" .. key .. "': " .. tostring(lastErr))
	return false, nil
end

local function robustRemoveAsync(key)
	if not dataStoreAvailable then return false end
	local lastErr
	for attempt = 1, RETRY_ATTEMPTS do
		local ok, err = pcall(function()
			dataStore:RemoveAsync(key)
		end)
		if ok then
			return true
		end
		lastErr = err
		if attempt < RETRY_ATTEMPTS then
			task.wait(RETRY_BACKOFF * attempt)
		end
	end
	warn("[SaveManager] RemoveAsync failed after " .. RETRY_ATTEMPTS .. " attempts for key '" .. key .. "': " .. tostring(lastErr))
	return false
end

-- ─── DATA ACCESS FUNCTIONS ──────────────────────────────────────────────

local function getSlotList(userId)
	-- MEMORY-FIRST: this server is authoritative for its own players, so once
	-- a slot list is in memory (from join-time load or any save), we serve it
	-- from there. This guarantees the Load menu always reflects every save
	-- made this session — regardless of DataStore health, throttling, or
	-- stale reads — and eliminates a GetAsync per menu-open/save, which is
	-- what keeps DataStore usage flat as player counts grow.
	if memorySlotLists[userId] then
		return memorySlotLists[userId]
	end
	if dataStoreAvailable then
		local ok, data = robustGetAsync("player_" .. userId .. "_slots")
		if ok and data then
			memorySlotLists[userId] = data
			return data
		end
	end
	return nil
end

local function setSlotList(userId, slotList)
	memorySlotLists[userId] = slotList -- always cache in memory first
	if dataStoreAvailable then
		return robustSetAsync("player_" .. userId .. "_slots", slotList)
	end
	return true
end

local function getSlotData(userId, slotId)
	-- Memory-first for the same reasons as getSlotList above
	local cached = memoryStore[userId .. "_slot_" .. slotId]
	if cached then return cached end
	if dataStoreAvailable then
		local ok, data = robustGetAsync("player_" .. userId .. "_slot_" .. slotId)
		if ok and data then
			memoryStore[userId .. "_slot_" .. slotId] = data
			return data
		end
	end
	return nil
end

local function setSlotData(userId, slotId, data)
	memoryStore[userId .. "_slot_" .. slotId] = data -- always cache in memory first
	if dataStoreAvailable then
		local ok = robustUpdateAsync("player_" .. userId .. "_slot_" .. slotId, function()
			return data
		end)
		return ok
	end
	return true
end

-- ─── SESSION LOCKING ───────────────────────────────────────────────────
-- With trading live, the classic dupe exploit is: trade a stud away, then
-- rejoin on ANOTHER server that still has (or loads) your pre-trade data
-- and autosaves it back. The lock makes one server at a time the writer for
-- a player: it's claimed (via UpdateAsync, so claims can't race) when a
-- slot is loaded/created, refreshed by the autosave loop, and released on
-- leave/shutdown. A crashed server's lock simply expires after the TTL.

local SESSION_LOCK_TTL = 180 -- seconds; autosave refreshes every 60s
local sessionLocks = {} -- [userId] = true while THIS server holds the lock

local function sessionLockKey(userId)
	return "player_" .. userId .. "_session"
end

local function claimSessionLock(userId)
	if not dataStoreAvailable then return true end -- Studio memory mode
	if sessionLocks[userId] then return true end
	local ok, result = robustUpdateAsync(sessionLockKey(userId), function(current)
		if current and current.jobId ~= game.JobId and os.time() < (current.expiresAt or 0) then
			return nil -- live lock held by another server: abort, don't claim
		end
		return { jobId = game.JobId, expiresAt = os.time() + SESSION_LOCK_TTL }
	end)
	if ok and result and result.jobId == game.JobId then
		sessionLocks[userId] = true
		return true
	end
	return false
end

local function refreshSessionLock(userId)
	if not dataStoreAvailable or not sessionLocks[userId] then return end
	robustUpdateAsync(sessionLockKey(userId), function(current)
		if current and current.jobId ~= game.JobId and os.time() < (current.expiresAt or 0) then
			return nil -- lost the lock somehow; don't steal it back mid-flight
		end
		return { jobId = game.JobId, expiresAt = os.time() + SESSION_LOCK_TTL }
	end)
end

local function releaseSessionLock(userId)
	if not dataStoreAvailable or not sessionLocks[userId] then return end
	sessionLocks[userId] = nil
	robustUpdateAsync(sessionLockKey(userId), function(current)
		if current and current.jobId == game.JobId then
			return { jobId = current.jobId, expiresAt = 0 } -- expired = released
		end
		return nil -- someone else's lock: leave it alone
	end)
end

-- ─── MIGRATION ─────────────────────────────────────────────────────────
-- Migrates old single-save data (player_<userId>) to slot 1 format

local function migrateOldSave(userId)
	local existingSlotList = getSlotList(userId)
	if existingSlotList and existingSlotList.slots and #existingSlotList.slots > 0 then
		return false -- already on new format
	end

	local oldData
	if dataStoreAvailable then
		local ok, data = robustGetAsync("player_" .. userId)
		if ok and data then oldData = data end
	else
		oldData = memoryStore[userId]
	end

	if not oldData then return false end

	-- Migrate to slot 1
	local studCount = oldData.caughtStuds and #oldData.caughtStuds or 0
	local slotList = {
		slots = {
			{
				slotId = 1,
				created = oldData.created or os.time(),
				lastSaved = oldData.lastSaved or os.time(),
				studCount = studCount,
			},
		},
	}
	setSlotList(userId, slotList)
	setSlotData(userId, 1, oldData)

	-- Clean up old key
	if dataStoreAvailable then
		robustRemoveAsync("player_" .. userId)
	else
		memoryStore[userId] = nil
	end

	print("[SaveManager] Migrated old save for user " .. userId .. " to slot 1")
	return true
end

-- ─── SAVE DATA CREATION ────────────────────────────────────────────────

local function createNewSaveData()
	return {
		tutorialSeen = false,
		caughtStuds = {},
		speciesCounts = {},
		items = {}, -- consumables + unequipped held items: [itemId] = count
		heldItems = {}, -- equipped held items: [speciesId] = itemId (one slot/species)
		totalCaught = 0,
		coins = 0,
		playTime = 0,
		created = os.time(),
		lastSaved = os.time(),
		evoPoints = {},
		equippedStudId = nil,
		equippedTeam = {}, -- ordered battle team (≤ MAX_TEAM); [1] is the lead
		lastDailyReward = 0,
		dailyStreak = 0,
		shinyStuds = {},
		grantedReceipts = {}, -- [PurchaseId] = true; dev-product receipts already granted (ProcessReceipt idempotency)
		lastPosition = nil,
		storyMode = true, -- Story vs Casual; picked on New Game, switchable in Settings
		story = { seen = {}, worldCatches = {}, ending = nil }, -- StorySystem's namespace (beats fired, per-world catch counts, ending choice)
		-- Growth/retention state (AnalyticsSystem, ReferralSystem, MilestoneSystem)
		daysPlayed = 0, -- distinct UTC days this slot was played
		lastPlayedDay = nil, -- "YYYY-MM-DD" of the most recent counted day
		firstCoopAt = nil, -- os.time() of first session with a friend in the server
		referredBy = nil, -- inviter UserId (official Friend Referral System join data)
		referralRewarded = false, -- both-sides referral reward already granted
		totalEvolutions = 0,
		totalTrades = 0,
		pvpWins = 0,
	}
end

-- ─── POSITION CAPTURE / RESTORE ───────────────────────────────────────

local function capturePlayerPosition(player)
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	return {
		x = hrp.Position.X,
		y = hrp.Position.Y,
		z = hrp.Position.Z,
	}
end

local function restorePlayerPosition(player, posData)
	if not posData then return end
	local function doTeleport()
		local character = player.Character
		if not character then return false end
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if not hrp then return false end
		hrp.CFrame = CFrame.new(posData.x, posData.y, posData.z)
		return true
	end
	if not doTeleport() then
		local conn
		conn = player.CharacterAdded:Connect(function()
			task.wait(0.5)
			doTeleport()
			conn:Disconnect()
		end)
	end
end

-- ─── ACTIVE PLAYER TRACKING ────────────────────────────────────────────

local activePlayers = {}
local catchStreaks = {}
ServerRegistry.Register("ActivePlayers", activePlayers)

-- ─── SPECIES COUNT CACHE ──────────────────────────────────────────────
-- PERF: data.speciesCounts ([studId] = copies owned) is maintained at every
-- collection mutation (catch/sell/evolve/trade) and rebuilt on load. It
-- replaces the full caughtStuds scans that used to run on EVERY catch
-- (unique counting, dupe checks, ownership checks) — those were O(collection)
-- and caughtStuds grows without bound. Iterating this map is O(unique
-- species) ≤ dex size instead. QuestSystem reads it for progress counting.

local function rebuildSpeciesCounts(data)
	local counts = {}
	for _, caught in ipairs(data.caughtStuds or {}) do
		counts[caught.id] = (counts[caught.id] or 0) + 1
	end
	data.speciesCounts = counts
	return counts
end

local function getSpeciesCounts(data)
	return data.speciesCounts or rebuildSpeciesCounts(data)
end

local function bumpSpeciesCount(data, studId, delta)
	local counts = getSpeciesCounts(data)
	local n = (counts[studId] or 0) + delta
	counts[studId] = n > 0 and n or nil
end

-- ─── EQUIPPED TEAM ─────────────────────────────────────────────────────
-- Players field a battle team of up to MAX_TEAM species. equippedTeam is the
-- ordered roster; equippedStudId always mirrors the lead (team[1]) so every
-- system that predates teams (companion, PvP, profile, encounter fallback)
-- keeps working off a single "representative" stud with no changes.
local MAX_TEAM = BattleTeam.MAX_TEAM -- one cap shared with both battle drivers + UIs

-- Keep equippedTeam self-consistent after any collection/equip mutation:
-- drop unowned species and duplicates, cap at MAX_TEAM, and re-point
-- equippedStudId at the lead. Also migrates legacy saves that only stored
-- equippedStudId (seeds the team from it on first touch).
local function normalizeTeam(data)
	local counts = getSpeciesCounts(data)
	local team = data.equippedTeam
	if type(team) ~= "table" then
		team = {}
		if data.equippedStudId then team[1] = data.equippedStudId end
	end
	local seen, cleaned = {}, {}
	for _, id in ipairs(team) do
		if type(id) == "string" and not seen[id] and (counts[id] or 0) >= 1 then
			seen[id] = true
			cleaned[#cleaned + 1] = id
			if #cleaned >= MAX_TEAM then break end
		end
	end
	data.equippedTeam = cleaned
	data.equippedStudId = cleaned[1]
	return cleaned
end

-- Push the stat attributes every other system reads (HUD, leaderboards,
-- StatsBoard) so they always mirror the authoritative save data. The
-- leaderboard's TotalCaught/UniqueCount columns were permanently zero before
-- because nothing ever set those attributes.
local function syncPlayerAttributes(player, data)
	local uniqueCount = 0
	for _ in pairs(getSpeciesCounts(data)) do
		uniqueCount += 1
	end
	player:SetAttribute("Coins", data.coins or 0)
	player:SetAttribute("StudCount", data.caughtStuds and #data.caughtStuds or 0)
	player:SetAttribute("TotalCaught", data.totalCaught or 0)
	player:SetAttribute("UniqueCount", uniqueCount)
	player:SetAttribute("EquippedStud", data.equippedStudId)
end
ServerRegistry.Register("SyncPlayerAttributes", syncPlayerAttributes)

-- ─── SHARED SAVE HELPER ────────────────────────────────────────────────
-- Single source of truth for "write this slot's data + update its slot-list
-- metadata". Used by PlayerRemoving, manual SaveData, autosave, and
-- BindToClose so all four paths get the same retry-safe behavior instead
-- of four copies that can drift out of sync.
-- Returns true if both writes succeeded.

local function persistPlayerSlot(userId, slotId, data, player)
	if not slotId or not data then return false end

	-- No session lock = another server may be authoritative for this player;
	-- writing would risk resurrecting traded-away studs. Keep the in-memory
	-- copy fresh so play continues, but skip the DataStore write.
	if dataStoreAvailable and not sessionLocks[userId] then
		memoryStore[userId .. "_slot_" .. slotId] = data
		warn("[SaveManager] Skipping DataStore write for user " .. userId .. " — session lock not held")
		return false
	end

	data.lastSaved = os.time()
	if player then
		local pos = capturePlayerPosition(player)
		if pos then
			data.lastPosition = pos
		end
	end

	local dataOk = setSlotData(userId, slotId, data)

	local slotListOk = true
	local slotList = getSlotList(userId)
	if slotList and slotList.slots then
		for _, slot in ipairs(slotList.slots) do
			if slot.slotId == slotId then
				slot.lastSaved = data.lastSaved
				slot.studCount = data.caughtStuds and #data.caughtStuds or 0
				break
			end
		end
		slotListOk = setSlotList(userId, slotList)
	end

	if not dataOk then
		warn("[SaveManager] Slot data write FAILED for user " .. userId .. " slot " .. tostring(slotId) .. " — progress may not have been saved!")
	end

	return dataOk and slotListOk
end

-- Exposed so callers that MUST NOT lose a change to a pre-autosave crash can
-- force a durable write on demand — same reason ExecuteTrade persists inline.
-- The prime case is real-money purchases (MonetizationSystem.ProcessReceipt),
-- which need the grant on disk before the receipt is confirmed. Returns true
-- only if the DataStore write succeeded (false if the session lock isn't held).
ServerRegistry.Register("PersistPlayer", persistPlayerSlot)

-- ─── PLAYER ADDED / REMOVING ───────────────────────────────────────────

local function onPlayerAdded(player)
	migrateOldSave(player.UserId)

	-- Don't load data yet — wait for client to choose New or Load
	activePlayers[player.UserId] = {
		data = nil,
		activeSlot = nil,
	}

	-- Handle House Rest bonus
	player:GetAttributeChangedSignal("HouseRestBonus"):Connect(function()
		if player:GetAttribute("HouseRestBonus") then
			local playerInfo = activePlayers[player.UserId]
			if playerInfo and playerInfo.data then
				playerInfo.data.coins = (playerInfo.data.coins or 0) + 5
				StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
				player:SetAttribute("Coins", playerInfo.data.coins)
			end
		end
	end)

	-- Handle Wishing Well results
	player:GetAttributeChangedSignal("WishResult"):Connect(function()
		local result = player:GetAttribute("WishResult")
		if result then
			local playerInfo = activePlayers[player.UserId]
			if playerInfo and playerInfo.data then
				local coinAmount = 0
				if result == "jackpot" then
					coinAmount = 100
				elseif result == "lucky" then
					coinAmount = 50
				elseif result == "nice" then
					coinAmount = 25
				elseif result == "small" then
					coinAmount = 10
				end

				if coinAmount > 0 then
					playerInfo.data.coins = (playerInfo.data.coins or 0) + coinAmount
					StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
					player:SetAttribute("Coins", playerInfo.data.coins)
					task.defer(function()
						ServerRegistry.Call("CheckMilestones", player)
					end)
				end
			end
		end
	end)
end

local function onPlayerRemoving(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data and playerInfo.activeSlot then
		persistPlayerSlot(player.UserId, playerInfo.activeSlot, playerInfo.data, player)
	end
	-- Final save first, THEN release the lock so another server can load
	releaseSessionLock(player.UserId)
	activePlayers[player.UserId] = nil
	catchStreaks[player.UserId] = nil

	-- Evict this player's memory-first cache. Without this, if they play on
	-- another server and later rejoin THIS server, the stale cached copy wins
	-- over the fresher DataStore data and the autosave rolls their progress
	-- back. (In Studio/no-DataStore mode the memory tables ARE the store, so
	-- they must be kept.)
	if dataStoreAvailable then
		memorySlotLists[player.UserId] = nil
		local prefix = player.UserId .. "_"
		for key in pairs(memoryStore) do
			if key:sub(1, #prefix) == prefix then
				memoryStore[key] = nil
			end
		end
	end
end

-- ─── SLOT MANAGEMENT EVENTS ────────────────────────────────────────────

-- Client requests the list of save slots
StudEvents.RequestSaveSlots.OnServerInvoke = function(player)
	migrateOldSave(player.UserId)
	local slotList = getSlotList(player.UserId)
	if slotList and slotList.slots then
		return slotList.slots
	end
	return {}
end

-- Persist whatever slot is currently being played before switching to a
-- different one (New Game / Load Game from the menu). Without this, anything
-- since the last autosave on the old slot was silently discarded.
local function persistActiveSlotBeforeSwitch(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data and playerInfo.activeSlot then
		persistPlayerSlot(player.UserId, playerInfo.activeSlot, playerInfo.data, player)
	end
end

-- New Game: auto-assign the next available slot. mode is "story" (default)
-- or "casual" — the menu's Story/Casual pick after pressing New Game.
StudEvents.NewGame.OnServerEvent:Connect(function(player, mode)
	if not claimSessionLock(player.UserId) then
		player:Kick("Your save data is still active on another server. Please rejoin in a couple of minutes.")
		return
	end

	persistActiveSlotBeforeSwitch(player)

	local slotList = getSlotList(player.UserId) or { slots = {} }

	-- MonetizationSystem sets ExtraSaveSlots for gamepass owners
	local maxSlots = MAX_SLOTS + (player:GetAttribute("ExtraSaveSlots") or 0)
	if #slotList.slots >= maxSlots then
		warn("[SaveManager] Max slots reached for player " .. player.Name)
		return
	end

	-- Find next available slot ID
	local nextSlotId = 1
	local usedIds = {}
	for _, slot in ipairs(slotList.slots) do
		usedIds[slot.slotId] = true
	end
	while usedIds[nextSlotId] do
		nextSlotId = nextSlotId + 1
	end

	local newData = createNewSaveData()
	newData.storyMode = mode ~= "casual"

	table.insert(slotList.slots, {
		slotId = nextSlotId,
		created = os.time(),
		lastSaved = os.time(),
		studCount = 0,
	})

	setSlotList(player.UserId, slotList)
	setSlotData(player.UserId, nextSlotId, newData)

	activePlayers[player.UserId] = {
		data = newData,
		activeSlot = nextSlotId,
	}
	syncPlayerAttributes(player, newData)
	ServerRegistry.Call("OnDataLoaded", player, newData) -- AnalyticsSystem funnel

	-- Gate the tutorial: only fires for brand-new games, never on the menu
	player:SetAttribute("TutorialSeen", false)
	-- StarterChosen=false holds back the tutorial and the rest of the HUD
	-- (see UIGate) so the starter pick is the ONLY thing on screen first
	player:SetAttribute("StarterChosen", false)
	player:SetAttribute("StoryMode", newData.storyMode)
	player:SetAttribute("GameStarted", true)

	-- Brand-new save: offer the starter pick (Gary/Susan/Terry)
	offerStarterEvent:FireClient(player)

	print("[SaveManager] Created new save slot " .. nextSlotId .. " for " .. player.Name)
end)

-- Load Game: client passes the slotId to load
StudEvents.LoadGame.OnServerEvent:Connect(function(player, slotId)
	if type(slotId) ~= "number" then return end

	if not claimSessionLock(player.UserId) then
		player:Kick("Your save data is still active on another server. Please rejoin in a couple of minutes.")
		return
	end

	persistActiveSlotBeforeSwitch(player)

	local data = getSlotData(player.UserId, slotId)
	if data then
		activePlayers[player.UserId] = {
			data = data,
			activeSlot = slotId,
		}
		-- Force-rebuild the species-count cache on load so a stale persisted
		-- copy can never drift from the actual collection
		rebuildSpeciesCounts(data)
		-- Migrate/repair the equipped team (seeds from a legacy equippedStudId,
		-- drops anything no longer owned) before attributes are synced
		normalizeTeam(data)
		syncPlayerAttributes(player, data)
		ServerRegistry.Call("OnDataLoaded", player, data) -- AnalyticsSystem funnel
		restorePlayerPosition(player, data.lastPosition)
		-- Loaded games never re-show the tutorial (old saves without the
		-- field belong to existing players, so nil counts as "seen").
		player:SetAttribute("TutorialSeen", data.tutorialSeen ~= false)
		-- A save that never picked a starter (e.g. left mid-choice) gets
		-- re-offered — but only while the collection is still empty
		local needsStarter = not data.starterChosen and #(data.caughtStuds or {}) == 0
		player:SetAttribute("StarterChosen", not needsStarter)
		-- Saves from before story mode existed default to Story (nil ~= false)
		player:SetAttribute("StoryMode", data.storyMode ~= false)
		player:SetAttribute("GameStarted", true)
		player:SetAttribute("DexTitle", data.equippedTitle)
		if needsStarter then
			offerStarterEvent:FireClient(player)
		end
		print("[SaveManager] Loaded save slot " .. slotId .. " for " .. player.Name)
	else
		warn("[SaveManager] Failed to load save slot " .. slotId .. " for " .. player.Name)
	end
end)

-- Delete save slot
StudEvents.DeleteSaveSlot.OnServerEvent:Connect(function(player, slotId)
	if type(slotId) ~= "number" then return end

	local slotList = getSlotList(player.UserId)
	if not slotList or not slotList.slots then return end

	for i, slot in ipairs(slotList.slots) do
		if slot.slotId == slotId then
			table.remove(slotList.slots, i)
			break
		end
	end
	setSlotList(player.UserId, slotList)

	-- Delete slot data (from both the memory cache and the DataStore)
	memoryStore[player.UserId .. "_slot_" .. slotId] = nil
	if dataStoreAvailable then
		robustRemoveAsync("player_" .. player.UserId .. "_slot_" .. slotId)
	end

	-- If this was the active slot, clear it
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.activeSlot == slotId then
		playerInfo.data = nil
		playerInfo.activeSlot = nil
	end

	print("[SaveManager] Deleted save slot " .. slotId .. " for " .. player.Name)
end)

-- Rename save slot
StudEvents.RenameSaveSlot.OnServerEvent:Connect(function(player, slotId, newName)
	if type(slotId) ~= "number" then return end
	-- Sanitize: only strings, hard length cap (protects the DataStore blob)
	if newName ~= nil then
		if type(newName) ~= "string" then return end
		newName = newName:sub(1, 30)
	end

	local slotList = getSlotList(player.UserId)
	if not slotList or not slotList.slots then return end

	for _, slot in ipairs(slotList.slots) do
		if slot.slotId == slotId then
			if newName and #newName > 0 then
				slot.name = newName
			else
				slot.name = nil
			end
			break
		end
	end
	setSlotList(player.UserId, slotList)

	print("[SaveManager] Renamed save slot " .. slotId .. " for " .. player.Name .. " to " .. (newName or "(cleared)"))
end)

-- Backward-compatible RequestDataLoad (returns most recent save info)
StudEvents.RequestDataLoad.OnServerInvoke = function(player)
	migrateOldSave(player.UserId)
	local slotList = getSlotList(player.UserId)
	local hasSave = slotList and slotList.slots and #slotList.slots > 0
	local saveData = nil
	if hasSave then
		-- Most recently SAVED slot, not most recently created
		local mostRecent = slotList.slots[1]
		for _, slot in ipairs(slotList.slots) do
			if (slot.lastSaved or 0) > (mostRecent.lastSaved or 0) then
				mostRecent = slot
			end
		end
		saveData = getSlotData(player.UserId, mostRecent.slotId)
	end
	return {
		hasSave = hasSave,
		saveData = saveData,
	}
end

-- Tutorial completed: persist so it never replays for this save
tutorialCompleteEvent.OnServerEvent:Connect(function(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data then
		playerInfo.data.tutorialSeen = true
	end
	player:SetAttribute("TutorialSeen", true)
end)

-- Manual save trigger from client (rate-limited: spam = DataStore throttling)
local lastManualSave = {}
StudEvents.SaveData.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if lastManualSave[player.UserId] and now - lastManualSave[player.UserId] < 10 then
		return
	end
	lastManualSave[player.UserId] = now
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data and playerInfo.activeSlot then
		persistPlayerSlot(player.UserId, playerInfo.activeSlot, playerInfo.data, player)
	end
end)

-- ─── DEX MILESTONE CHECKING ────────────────────────────────────────────

local function checkDexMilestones(player)
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then return end

	local uniqueCount = 0
	for _ in pairs(getSpeciesCounts(playerInfo.data)) do
		uniqueCount = uniqueCount + 1
	end

	local totalStuds = #StudData.Studs
	if totalStuds == 0 then return end
	local percent = math.floor((uniqueCount / totalStuds) * 100 + 0.5)

	local milestones = { 25, 50, 75, 100 }
	-- Persisted on the save slot so milestone popups don't replay every session
	local lastMilestone = playerInfo.data.lastDexMilestone or 0
	for _, threshold in ipairs(milestones) do
		if percent >= threshold and lastMilestone < threshold then
			playerInfo.data.lastDexMilestone = threshold
			player:SetAttribute("LastDexMilestone", threshold)
			player:SetAttribute("DexMilestone", threshold)
			break
		end
	end

	-- Per-type dex completion: own every species of a type at once → a
	-- one-time coin reward + a title ("Friend of Steve" etc.). The first
	-- earned title auto-equips (shown over the character's head).
	local data = playerInfo.data
	data.typeDexRewards = data.typeDexRewards or {}
	local ownedPerType = {}
	for studId in pairs(getSpeciesCounts(data)) do
		local stud = StudData.GetStudById(studId)
		if stud then
			ownedPerType[stud.studType] = (ownedPerType[stud.studType] or 0) + 1
		end
	end
	for typeName in pairs(StudData.Types) do
		local total = #StudData.GetStudsByType(typeName)
		if total > 0
			and not data.typeDexRewards[typeName]
			and (ownedPerType[typeName] or 0) >= total
		then
			data.typeDexRewards[typeName] = true
			local title = StudData.TypeDexTitles[typeName] or (typeName .. " Master")
			data.titles = data.titles or {}
			table.insert(data.titles, title)
			if not data.equippedTitle then
				data.equippedTitle = title
			end
			player:SetAttribute("DexTitle", data.equippedTitle)

			data.coins = (data.coins or 0) + StudData.TYPE_DEX_REWARD
			StudEvents.UpdateCoins:FireClient(player, data.coins)
			player:SetAttribute("Coins", data.coins)

			local milestoneEvent = StudEvents:FindFirstChild("MilestoneNotify")
			if milestoneEvent then
				milestoneEvent:FireClient(player, "typedex_" .. typeName,
					typeName .. " Dex Complete!",
					"+" .. StudData.TYPE_DEX_REWARD .. " coins · Title: " .. title, "📖")
			end
			print("[SaveManager] " .. player.Name .. " completed the " .. typeName .. " dex → " .. title)
		end
	end
end

-- ─── CATCH HANDLING ───────────────────────────────────────────────────

-- SECURITY FIX: the old handler trusted studId/wasCaught/isShiny straight from
-- the client, letting exploiters grant themselves any stud (incl. shiny
-- Legendaries) plus coins. Catches are now granted ONLY by the server-
-- authoritative EncounterAction "CatchSuccess" path in EncounterSystem.
-- This remote stays as a stub so old clients don't error.
StudEvents.CatchComplete.OnServerInvoke = function(player, _studId, wasCaught)
	if not wasCaught then
		catchStreaks[player.UserId] = 0
		player:SetAttribute("CatchStreak", 0)
	end
	return { success = false, reason = "deprecated" }
end

-- Single server-authoritative path for adding a caught stud to a player's
-- save. Both the wild-encounter minigame (EncounterSystem) and the Battle
-- Arena (BattleSystem) route through this, so the dupe/coin/evo-point
-- economy and the quest/streak/milestone hooks can't drift between the two.
-- Policy: every catch adds a copy to the collection (duplicates are what the
-- Sell flow and sell quests are built on); duplicates pay half coins and +1
-- evo point of the stud's type.
ServerRegistry.Register("GrantCatch", function(player, studId, opts)
	opts = opts or {}
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then return nil end
	local studInfo = StudData.GetStudById(studId)
	if not studInfo then return nil end
	local data = playerInfo.data

	local alreadyCaught = (getSpeciesCounts(data)[studId] or 0) > 0

	local newEntry = {
		id = studId,
		caughtAt = os.time(),
		isShiny = opts.isShiny or false,
		level = opts.level or 1,
		exp = 0,
		nature = opts.nature or StudData.RollNature(),
	}
	table.insert(data.caughtStuds, newEntry)
	bumpSpeciesCount(data, studId, 1)
	data.totalCaught = (data.totalCaught or 0) + 1

	if opts.isShiny then
		data.shinyStuds = data.shinyStuds or {}
		table.insert(data.shinyStuds, studId)
	end

	-- opts.purchase: stud was BOUGHT (shop featured stud), not caught in the
	-- wild — no catch coin reward, and quest/streak hooks don't fire (buying
	-- your way through "catch 3 Fire studs" would gut the quests)
	local reward = 0
	if not opts.purchase then
		local coinRewards = { Common = 10, Uncommon = 25, Rare = 50, Legendary = 100 }
		reward = coinRewards[studInfo.rarity] or 10
		if alreadyCaught then
			reward = math.floor(reward * 0.5)
		end
		data.coins = (data.coins or 0) + reward
	end
	if alreadyCaught then
		data.evoPoints = data.evoPoints or {}
		data.evoPoints[studInfo.studType] = (data.evoPoints[studInfo.studType] or 0) + 1
	end
	data.lastSaved = os.time()

	StudEvents.UpdateCoins:FireClient(player, data.coins)
	syncPlayerAttributes(player, data)

	if not opts.purchase then
		ServerRegistry.Call("OnStudCaught", player, studId)
		ServerRegistry.Call("OnCatchResolved", player, true)
	end
	-- Story beats fire on EVERY grant (purchases included — the starter is
	-- the "first neighbor you remember"); StorySystem no-ops in Casual mode
	ServerRegistry.Call("OnStoryCatch", player, studId, not alreadyCaught, opts.purchase == true)
	task.defer(function()
		ServerRegistry.Call("CheckMilestones", player)
		checkDexMilestones(player)
	end)

	-- Growth hooks: AnalyticsSystem (funnel/TTFC) sees every catch;
	-- ReferralSystem's both-sides reward is gated on the FIRST catch
	-- specifically (anti-abuse: a join alone pays nothing)
	ServerRegistry.Call("OnCatchGranted", player, studId, data)
	if (data.totalCaught or 0) == 1 then
		ServerRegistry.Call("OnFirstCatch", player, data)
	end

	return {
		isNew = not alreadyCaught,
		coinsAwarded = reward,
		totalCoins = data.coins,
		nature = newEntry.nature,
	}
end)

-- ─── TRADING PRIMITIVE ────────────────────────────────────────────────
-- Atomically move specific stud copies between two online players' saves.
-- offersA/offersB are arrays of entry SNAPSHOTS ({id, caughtAt, level,
-- isShiny, nature}); each snapshot must still match a real entry at execute
-- time or the whole trade fails with nothing moved. Owned by SaveManager so
-- TradeSystem never touches save tables directly.
local function entryMatches(entry, snapshot)
	return entry.id == snapshot.id
		and (entry.caughtAt or 0) == (snapshot.caughtAt or 0)
		and (entry.level or 1) == (snapshot.level or 1)
		and (entry.isShiny or false) == (snapshot.isShiny or false)
		and (entry.nature or "hardy") == (snapshot.nature or "hardy")
end

-- First entry matching the snapshot that isn't already claimed by this trade
local function findUntakenEntryIndex(caughtStuds, snapshot, taken)
	for i, entry in ipairs(caughtStuds) do
		if not taken[i] and entryMatches(entry, snapshot) then
			return i
		end
	end
	return nil
end

ServerRegistry.Register("ExecuteTrade", function(playerA, playerB, offersA, offersB)
	local infoA = activePlayers[playerA.UserId]
	local infoB = activePlayers[playerB.UserId]
	if not infoA or not infoA.data or not infoB or not infoB.data then
		return false, "no_data"
	end

	-- Resolve every snapshot to a concrete index BEFORE mutating anything
	local indicesA, indicesB = {}, {}
	local takenA, takenB = {}, {}
	for _, snapshot in ipairs(offersA) do
		local idx = findUntakenEntryIndex(infoA.data.caughtStuds, snapshot, takenA)
		if not idx then return false, "offer_changed" end
		takenA[idx] = true
		table.insert(indicesA, idx)
	end
	for _, snapshot in ipairs(offersB) do
		local idx = findUntakenEntryIndex(infoB.data.caughtStuds, snapshot, takenB)
		if not idx then return false, "offer_changed" end
		takenB[idx] = true
		table.insert(indicesB, idx)
	end

	-- Remove (highest index first so earlier indices stay valid)
	local movedFromA, movedFromB = {}, {}
	table.sort(indicesA, function(x, y) return x > y end)
	table.sort(indicesB, function(x, y) return x > y end)
	for _, idx in ipairs(indicesA) do
		table.insert(movedFromA, table.remove(infoA.data.caughtStuds, idx))
	end
	for _, idx in ipairs(indicesB) do
		table.insert(movedFromB, table.remove(infoB.data.caughtStuds, idx))
	end

	-- Swap ownership
	for _, entry in ipairs(movedFromA) do
		entry.tradedAt = os.time()
		table.insert(infoB.data.caughtStuds, entry)
	end
	for _, entry in ipairs(movedFromB) do
		entry.tradedAt = os.time()
		table.insert(infoA.data.caughtStuds, entry)
	end

	-- Rebuild both species-count caches (bulk swap: a rebuild is simpler and
	-- safer than paired bumps), then clear equips that no longer resolve
	for _, pair in ipairs({ { playerA, infoA }, { playerB, infoB } }) do
		local plr, inf = pair[1], pair[2]
		local counts = rebuildSpeciesCounts(inf.data)
		-- Drop any traded-away species from the team and re-point the lead
		normalizeTeam(inf.data)
		-- Held items belong to the owner (keyed by species, not traded with the
		-- creature); trading away a species' last copy frees its item to the pool.
		if inf.data.heldItems then
			for speciesId, itemId in pairs(inf.data.heldItems) do
				if (counts[speciesId] or 0) < 1 then
					inf.data.items = inf.data.items or {}
					inf.data.items[itemId] = (inf.data.items[itemId] or 0) + 1
					inf.data.heldItems[speciesId] = nil
				end
			end
		end
		syncPlayerAttributes(plr, inf.data)
	end

	infoA.data.totalTrades = (infoA.data.totalTrades or 0) + 1
	infoB.data.totalTrades = (infoB.data.totalTrades or 0) + 1

	-- Persist both sides immediately — a trade is exactly the kind of change
	-- that must not be lost to a crash before the next autosave
	persistPlayerSlot(playerA.UserId, infoA.activeSlot, infoA.data, playerA)
	persistPlayerSlot(playerB.UserId, infoB.activeSlot, infoB.data, playerB)

	task.defer(function()
		ServerRegistry.Call("CheckMilestones", playerA)
		ServerRegistry.Call("CheckMilestones", playerB)
		checkDexMilestones(playerA)
		checkDexMilestones(playerB)
	end)

	return true
end)

-- Streak logic, driven only by the server (EncounterSystem calls this)
ServerRegistry.Register("OnCatchResolved", function(player, caught)
	if not caught then
		catchStreaks[player.UserId] = 0
		player:SetAttribute("CatchStreak", 0)
		return
	end
	local streak = (catchStreaks[player.UserId] or 0) + 1
	catchStreaks[player.UserId] = streak
	player:SetAttribute("CatchStreak", streak)

	if streak % 5 == 0 then
		local playerInfo = activePlayers[player.UserId]
		if playerInfo and playerInfo.data then
			playerInfo.data.coins = (playerInfo.data.coins or 0) + streak * 2
			StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
			player:SetAttribute("Coins", playerInfo.data.coins)
		end
	end

	task.defer(function()
		checkDexMilestones(player)
	end)
end)

-- ─── COLLECTION & STATS ───────────────────────────────────────────────

StudEvents.RequestCollection.OnServerInvoke = function(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data then
		-- 3rd return: equipped held items per species ([speciesId] = itemId);
		-- 4th: the unequipped item pool ([itemId] = count) so the collection UI
		-- can populate the held-item picker without a second round-trip.
		return playerInfo.data.caughtStuds,
			playerInfo.data.equippedStudId,
			playerInfo.data.heldItems or {},
			playerInfo.data.items or {},
			playerInfo.data.equippedTeam or {}
	end
	return {}, nil, {}, {}, {}
end

StudEvents.GetPlayerStats.OnServerInvoke = function(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data then
		local data = playerInfo.data
		local uniqueCount = 0
		for _ in pairs(getSpeciesCounts(data)) do
			uniqueCount = uniqueCount + 1
		end
		return {
			coins = data.coins or 0,
			totalCaught = data.totalCaught or 0,
			uniqueCount = uniqueCount,
			totalCount = #data.caughtStuds,
			maxStuds = #StudData.Studs,
			shinyCount = data.shinyStuds and #data.shinyStuds or 0,
			evoPoints = data.evoPoints or {},
			titles = data.titles or {},
			equippedTitle = data.equippedTitle,
		}
	end
	return { coins = 0, totalCaught = 0, uniqueCount = 0, totalCount = 0, maxStuds = #StudData.Studs, shinyCount = 0, evoPoints = {}, titles = {} }
end

-- ─── EQUIP / SELL / EVOLVE ─────────────────────────────────────────────

StudEvents.EquipStud.OnServerInvoke = function(player, studId)
	if type(studId) ~= "string" then return { success = false, reason = "invalid" } end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end

	if (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1 then
		return { success = false, reason = "not_owned" }
	end

	-- "Equip" now means "make this the team lead": ensure the species is on the
	-- team and move it to the front. If the team is already full and this stud
	-- isn't on it, the current lead is bumped to make room.
	local data = playerInfo.data
	normalizeTeam(data)
	local team = data.equippedTeam
	for i = #team, 1, -1 do
		if team[i] == studId then table.remove(team, i) end
	end
	table.insert(team, 1, studId)
	if #team > MAX_TEAM then table.remove(team, 2) end
	normalizeTeam(data)

	player:SetAttribute("EquippedStud", data.equippedStudId)
	setSlotData(player.UserId, playerInfo.activeSlot, data)
	return { success = true, studId = studId, team = data.equippedTeam }
end

-- Add or remove a species from the battle team (≤ MAX_TEAM). Toggling the
-- current lead off promotes the next member; the InventoryUI drives this.
StudEvents.ToggleTeamMember.OnServerInvoke = function(player, studId)
	if type(studId) ~= "string" then return { success = false, reason = "invalid" } end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end
	local data = playerInfo.data
	if (getSpeciesCounts(data)[studId] or 0) < 1 then
		return { success = false, reason = "not_owned" }
	end

	normalizeTeam(data)
	local team = data.equippedTeam
	local idx = table.find(team, studId)
	if idx then
		table.remove(team, idx)
	else
		if #team >= MAX_TEAM then
			return { success = false, reason = "team_full", team = team, lead = data.equippedStudId }
		end
		table.insert(team, studId)
	end
	normalizeTeam(data)

	player:SetAttribute("EquippedStud", data.equippedStudId)
	setSlotData(player.UserId, playerInfo.activeSlot, data)
	return { success = true, team = data.equippedTeam, lead = data.equippedStudId }
end

-- Equip / swap / unequip a held item on a species' one slot. itemId nil or ""
-- unequips. Enforces species ownership, item ownership (from the unequipped
-- pool data.items), and the item's typeLock. Returns the updated heldItems +
-- items maps so the client can refresh without a re-fetch.
StudEvents.EquipHeldItem.OnServerInvoke = function(player, studId, itemId)
	if type(studId) ~= "string" then return { success = false, reason = "invalid" } end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end
	local data = playerInfo.data
	data.heldItems = data.heldItems or {}
	data.items = data.items or {}

	if (getSpeciesCounts(data)[studId] or 0) < 1 then
		return { success = false, reason = "not_owned" }
	end
	local stud = StudData.GetStudById(studId)
	if not stud then return { success = false, reason = "invalid_stud" } end

	local current = data.heldItems[studId]

	-- Unequip: return the current item to the pool
	if itemId == nil or itemId == "" then
		if current then
			data.items[current] = (data.items[current] or 0) + 1
			data.heldItems[studId] = nil
		end
		setSlotData(player.UserId, playerInfo.activeSlot, data)
		return { success = true, studId = studId, heldItem = nil, heldItems = data.heldItems, items = data.items }
	end

	if type(itemId) ~= "string" or not StudData.GetHeldItem(itemId) then
		return { success = false, reason = "unknown_item" }
	end
	if not StudData.CanEquipHeldItem(itemId, stud.studType) then
		return { success = false, reason = "type_locked" }
	end
	if current == itemId then
		return { success = true, studId = studId, heldItem = itemId, heldItems = data.heldItems, items = data.items }
	end
	if (data.items[itemId] or 0) < 1 then
		return { success = false, reason = "not_owned_item" }
	end

	-- Swap: current item back to the pool, consume the new one
	if current then
		data.items[current] = (data.items[current] or 0) + 1
	end
	data.items[itemId] = data.items[itemId] - 1
	if data.items[itemId] <= 0 then data.items[itemId] = nil end
	data.heldItems[studId] = itemId

	setSlotData(player.UserId, playerInfo.activeSlot, data)
	return { success = true, studId = studId, heldItem = itemId, heldItems = data.heldItems, items = data.items }
end

StudEvents.SellStud.OnServerEvent:Connect(function(player, studId)
	if type(studId) ~= "string" then return end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then return end

	-- Sell the LOWEST-level duplicate so the player's trained copy survives
	local sellIdx, lowestLevel = nil, math.huge
	for i, caught in ipairs(playerInfo.data.caughtStuds) do
		if caught.id == studId then
			local lvl = caught.level or 1
			if lvl < lowestLevel then
				lowestLevel = lvl
				sellIdx = i
			end
		end
	end
	if not sellIdx then return end

	local soldEntry = playerInfo.data.caughtStuds[sellIdx]
	-- Level-scaled sell value (single source of truth in StudData)
	local sellValue = StudData.GetSellValue(studId, soldEntry.level or 1)
	if soldEntry.isShiny then
		sellValue = sellValue * 5
	end

	table.remove(playerInfo.data.caughtStuds, sellIdx)
	bumpSpeciesCount(playerInfo.data, studId, -1)
	playerInfo.data.coins = (playerInfo.data.coins or 0) + sellValue

	-- Selling the last copy frees its held item back to the unequipped pool so
	-- a permanent equip is never silently lost with the species.
	if (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1 then
		local held = playerInfo.data.heldItems and playerInfo.data.heldItems[studId]
		if held then
			playerInfo.data.items = playerInfo.data.items or {}
			playerInfo.data.items[held] = (playerInfo.data.items[held] or 0) + 1
			playerInfo.data.heldItems[studId] = nil
		end
	end

	-- Drop the species from the team if that was its last copy (normalizeTeam
	-- also re-points the lead); the attribute is refreshed by syncPlayerAttributes.
	normalizeTeam(playerInfo.data)

	setSlotData(player.UserId, playerInfo.activeSlot, playerInfo.data)
	StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
	syncPlayerAttributes(player, playerInfo.data)

	-- Quest progress fires only after a validated, completed sale
	ServerRegistry.Call("OnStudSold", player, studId)
end)

StudEvents.EvolveStud.OnServerInvoke = function(player, studId, targetId)
	if type(studId) ~= "string" then return { success = false, reason = "invalid" } end
	if targetId ~= nil and type(targetId) ~= "string" then targetId = nil end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end

	local stud = StudData.GetStudById(studId)
	if not stud then
		return { success = false, reason = "invalid_stud" }
	end

	if (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1 then
		return { success = false, reason = "not_owned" }
	end

	-- targetId lets the client pick a branch from StudData.EvolutionPaths;
	-- GetEvolution validates it server-side (invalid branch -> nil)
	local evolution = StudData.GetEvolution(studId, targetId)
	if not evolution then
		return { success = false, reason = targetId and "invalid_branch" or "max_evolved" }
	end

	local cost = StudData.GetEvolutionCost(studId)
	if not cost then
		return { success = false, reason = "no_cost" }
	end

	if not playerInfo.data.evoPoints then
		playerInfo.data.evoPoints = {}
	end
	local currentPoints = playerInfo.data.evoPoints[stud.studType] or 0
	if currentPoints < cost then
		return { success = false, reason = "insufficient_points", current = currentPoints, cost = cost }
	end

	-- Evolve the HIGHEST-level copy and carry its level/exp into the new form
	local evoIdx, bestLevel = nil, -1
	for i, caught in ipairs(playerInfo.data.caughtStuds) do
		if caught.id == studId then
			local lvl = caught.level or 1
			if lvl > bestLevel then
				bestLevel = lvl
				evoIdx = i
			end
		end
	end
	local oldEntry = table.remove(playerInfo.data.caughtStuds, evoIdx)
	bumpSpeciesCount(playerInfo.data, studId, -1)

	table.insert(playerInfo.data.caughtStuds, {
		id = evolution.id,
		caughtAt = os.time(),
		isShiny = oldEntry.isShiny or false,
		evolved = true,
		level = oldEntry.level or 1,
		exp = oldEntry.exp or 0,
	})
	bumpSpeciesCount(playerInfo.data, evolution.id, 1)

	-- If the evolved copy was the last of its species, carry any team slot(s)
	-- over to the new form in place (otherwise normalizeTeam would just drop the
	-- now-unowned species and shrink the team)
	if (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1 then
		local team = playerInfo.data.equippedTeam
		if type(team) == "table" then
			for i, id in ipairs(team) do
				if id == studId then team[i] = evolution.id end
			end
		end
	end
	normalizeTeam(playerInfo.data)

	-- Carry the held item onto the evolved form when the old species is gone.
	-- If the evolution's type breaks the item's typeLock, free it to the pool
	-- instead of silently losing it or leaving an illegal equip.
	if playerInfo.data.heldItems
		and playerInfo.data.heldItems[studId]
		and (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1
	then
		local held = playerInfo.data.heldItems[studId]
		playerInfo.data.heldItems[studId] = nil
		if StudData.CanEquipHeldItem(held, evolution.studType) then
			playerInfo.data.heldItems[evolution.id] = held
		else
			playerInfo.data.items = playerInfo.data.items or {}
			playerInfo.data.items[held] = (playerInfo.data.items[held] or 0) + 1
		end
	end

	playerInfo.data.evoPoints[stud.studType] = currentPoints - cost
	playerInfo.data.totalEvolutions = (playerInfo.data.totalEvolutions or 0) + 1
	playerInfo.data.lastSaved = os.time()
	setSlotData(player.UserId, playerInfo.activeSlot, playerInfo.data)
	syncPlayerAttributes(player, playerInfo.data)

	task.defer(function()
		ServerRegistry.Call("CheckMilestones", player)
		checkDexMilestones(player)
	end)

	return {
		success = true,
		oldStud = studId,
		newStud = evolution.id,
		newName = evolution.name,
		newRarity = evolution.rarity,
		remainingPoints = playerInfo.data.evoPoints[stud.studType],
	}
end

-- ─── STARTER CHOICE ────────────────────────────────────────────────────
-- One-time pick on a brand-new save. Validated hard: only while the
-- collection is empty and only ids from StudData.Starters, so it can never
-- become a free-stud faucet.

chooseStarterFunc.OnServerInvoke = function(player, starterId)
	if type(starterId) ~= "string" then return { success = false, reason = "invalid" } end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end
	local data = playerInfo.data
	if data.starterChosen or #(data.caughtStuds or {}) > 0 then
		return { success = false, reason = "already_started" }
	end

	local valid = false
	for _, id in ipairs(StudData.Starters) do
		if id == starterId then
			valid = true
			break
		end
	end
	if not valid then
		return { success = false, reason = "invalid_starter" }
	end

	data.starterChosen = true
	-- purchase=true: the freebie pays no catch coins and doesn't tick
	-- quest/streak hooks. Lv5 so the first trips into tall grass are fair.
	local grant = ServerRegistry.Call("GrantCatch", player, starterId, { purchase = true, level = 5 })
	if not grant then
		data.starterChosen = nil
		return { success = false, reason = "grant_failed" }
	end
	data.equippedTeam = { starterId }
	normalizeTeam(data)
	player:SetAttribute("EquippedStud", data.equippedStudId)
	-- Unlocks the tutorial + HUD (UIGate) now that the pick is done
	player:SetAttribute("StarterChosen", true)
	syncPlayerAttributes(player, data)

	local stud = StudData.GetStudById(starterId)
	print("[SaveManager] " .. player.Name .. " chose starter: " .. (stud and stud.name or starterId))
	return { success = true, studId = starterId, name = stud and stud.name or starterId }
end

-- ─── TITLE EQUIP ───────────────────────────────────────────────────────
-- Equip an earned title (nil/"" clears it). Only titles actually in
-- data.titles are accepted, so this can't display arbitrary strings.
equipTitleFunc.OnServerInvoke = function(player, title)
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end
	local data = playerInfo.data

	if title == nil or title == "" then
		data.equippedTitle = nil
		player:SetAttribute("DexTitle", nil)
		return { success = true, equipped = nil }
	end

	if type(title) ~= "string" then
		return { success = false, reason = "invalid" }
	end
	local owned = false
	for _, earned in ipairs(data.titles or {}) do
		if earned == title then
			owned = true
			break
		end
	end
	if not owned then
		return { success = false, reason = "not_earned" }
	end

	data.equippedTitle = title
	player:SetAttribute("DexTitle", title)
	return { success = true, equipped = title }
end

-- ─── NICKNAMES ─────────────────────────────────────────────────────────
-- Rename the player's BEST copy of a species (highest level — the same
-- "trained copy" convention battles and evolution use). Nicknames pass
-- through Roblox text filtering since they can surface to other players
-- (trades). Empty/whitespace input clears the nickname.

local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")

local NICKNAME_MAX_LENGTH = 20

renameStudFunc.OnServerInvoke = function(player, studId, nickname)
	if type(studId) ~= "string" then return { success = false, reason = "invalid" } end
	local playerInfo = activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		return { success = false, reason = "no_data" }
	end
	if (getSpeciesCounts(playerInfo.data)[studId] or 0) < 1 then
		return { success = false, reason = "not_owned" }
	end

	local best = nil
	for _, caught in ipairs(playerInfo.data.caughtStuds) do
		if caught.id == studId and (not best or (caught.level or 1) > (best.level or 1)) then
			best = caught
		end
	end
	if not best then
		return { success = false, reason = "not_owned" }
	end

	if nickname ~= nil and type(nickname) ~= "string" then
		return { success = false, reason = "invalid" }
	end
	nickname = nickname and nickname:gsub("^%s+", ""):gsub("%s+$", ""):sub(1, NICKNAME_MAX_LENGTH) or ""

	if #nickname == 0 then
		best.nickname = nil
		return { success = true, nickname = nil, caughtAt = best.caughtAt }
	end

	local filtered
	local ok = pcall(function()
		local result = TextService:FilterStringAsync(nickname, player.UserId)
		filtered = result:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or not filtered then
		if RunService:IsStudio() then
			filtered = nickname -- text filtering is unavailable offline in Studio
		else
			return { success = false, reason = "filter_failed" }
		end
	end

	best.nickname = filtered
	return { success = true, nickname = filtered, caughtAt = best.caughtAt }
end

-- ─── HEALING ───────────────────────────────────────────────────────────
-- SECURITY: there is deliberately NO OnServerEvent handler for HealPlayer.
-- Healing (LastHealTime) is granted only by server-side ProximityPrompts in
-- BuildingInteractions and by the heal_potion purchase in ShopSystem. The
-- old handler here let any client fire HealPlayer to reset the cooldown at
-- will; the real client only ever LISTENS to this event (StudCenterUI/
-- SoundEffects), so removing it breaks nothing legitimate.

-- ─── EVO POINTS REQUEST ───────────────────────────────────────────────

StudEvents.RequestEvoPoints.OnServerInvoke = function(player)
	local playerInfo = activePlayers[player.UserId]
	if playerInfo and playerInfo.data then
		return playerInfo.data.evoPoints or {}
	end
	return {}
end

-- ─── CONNECTIONS ───────────────────────────────────────────────────────

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

-- Auto-save every 60 seconds, STAGGERED: saving all players back-to-back
-- creates a DataStore request burst that queues/throttles as servers fill up.
-- Spacing saves ~1s apart keeps the request rate smooth at any player count
-- (well within the 60 + 10/player-per-minute write budget: 2 writes/player/min).
task.spawn(function()
	while task.wait(60) do
		for userId, playerInfo in pairs(activePlayers) do
			if playerInfo.data and playerInfo.activeSlot then
				refreshSessionLock(userId) -- keep the lock alive while playing
				local player = Players:GetPlayerByUserId(userId)
				if persistPlayerSlot(userId, playerInfo.activeSlot, playerInfo.data, player) then
					print("[SaveManager] Autosaved slot " .. playerInfo.activeSlot .. " for user " .. userId)
				end
				task.wait(1)
			end
		end
	end
end)

-- ─── SHUTDOWN SAFETY NET ───────────────────────────────────────────────
-- Roblox gives a live server a short window (up to ~30s) to finish work in
-- BindToClose before it's torn down — for deploys, crashes, or the last
-- player leaving. Without this, any progress since the last autosave/
-- PlayerRemoving tick for a player still connected at shutdown is lost.
-- We save every active player in parallel and wait for them all (or a
-- safety timeout) before letting the callback return.

game:BindToClose(function()
	if not dataStoreAvailable then return end

	local pending = 0
	local done = 0

	for userId, playerInfo in pairs(activePlayers) do
		if playerInfo.data and playerInfo.activeSlot then
			pending += 1
			local player = Players:GetPlayerByUserId(userId)
			task.spawn(function()
				local ok = persistPlayerSlot(userId, playerInfo.activeSlot, playerInfo.data, player)
				if not ok then
					warn("[SaveManager] BindToClose save FAILED for user " .. userId)
				end
				releaseSessionLock(userId) -- save first, then free for other servers
				done += 1
			end)
		end
	end

	if pending == 0 then return end

	print("[SaveManager] BindToClose: saving " .. pending .. " active player(s) before shutdown...")
	local waited = 0
	while done < pending and waited < 25 do
		task.wait(0.25)
		waited += 0.25
	end
	print("[SaveManager] BindToClose: saved " .. done .. "/" .. pending .. " player(s), shutting down.")
end)

print("[SaveManager] Initialized with multi-slot support (max " .. MAX_SLOTS .. " slots)")