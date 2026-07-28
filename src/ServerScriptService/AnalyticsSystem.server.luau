-- AnalyticsSystem: onboarding funnel + growth telemetry.
--
-- Research (Evervault studs-growth charter):
--   Q7  — instrument the FTUE as an official onboarding funnel BEFORE launch;
--         funnel events are server-only and can't be backfilled.
--   Q2  — time-to-first-catch (TTFC) is the leading FTUE metric.
--   Q23 — cheap tenure instrumentation: distinct-days-played counter.
--   Q15 — "Be Your Own Source": stamp the first session a friend was present
--         so Studs measures its own real friend-retention effect.
--
-- Funnel steps (join → first catch). Keep steps granular so a stall shows up
-- as "stuck between sighting and catch prompt", not one opaque bucket:
--   1 joined            (PlayerAdded)
--   2 data_loaded       (save slot picked; New/Load menu completed)
--   3 first_encounter   (first wild encounter triggered, pre-first-catch)
--   4 first_catch_start (catch minigame opened, pre-first-catch)
--   5 first_catch       (GrantCatch with totalCaught == 1)

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local GrowthConfig = require(ReplicatedStorage:WaitForChild("GrowthConfig"))

local FUNNEL_STEPS = {
	joined = 1,
	data_loaded = 2,
	first_encounter = 3,
	first_catch_start = 4,
	first_catch = 5,
}

-- Per-session state: [userId] = { joinedClock, loggedSteps, trackedData, coopChecked }
local sessions = {}

local function logFunnelStep(player, stepName)
	local session = sessions[player.UserId]
	local step = FUNNEL_STEPS[stepName]
	if not session or not step then return end
	if session.loggedSteps[step] then return end
	session.loggedSteps[step] = true

	task.spawn(function()
		local ok, err = pcall(function()
			AnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName)
		end)
		if not ok then
			warn("[Analytics] Funnel step '" .. stepName .. "' failed: " .. tostring(err))
		end
	end)
end

local function logCustomEvent(player, eventName, value)
	task.spawn(function()
		pcall(function()
			AnalyticsService:LogCustomEvent(player, eventName, value)
		end)
	end)
end

local function getData(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	return playerInfo and playerInfo.data or nil
end

-- ─── HOOKS FROM OTHER SYSTEMS (via ServerRegistry) ─────────────────────

-- EncounterSystem: a wild encounter started
ServerRegistry.Register("OnEncounterStarted", function(player)
	local data = getData(player)
	if data and (data.totalCaught or 0) == 0 then
		logFunnelStep(player, "first_encounter")
	end
end)

-- EncounterSystem: the catch minigame opened
ServerRegistry.Register("OnCatchStarted", function(player)
	local data = getData(player)
	if data and (data.totalCaught or 0) == 0 then
		logFunnelStep(player, "first_catch_start")
	end
end)

-- SaveManager GrantCatch: every catch (wild, battle, or purchase)
ServerRegistry.Register("OnCatchGranted", function(player, _studId, data)
	if (data.totalCaught or 0) == 1 then
		-- Keep the funnel monotone even when the first grant skipped the wild
		-- encounter path (e.g. the purchased starter): backfill 3 and 4
		logFunnelStep(player, "first_encounter")
		logFunnelStep(player, "first_catch_start")
		logFunnelStep(player, "first_catch")
		local session = sessions[player.UserId]
		if session then
			-- TTFC in seconds since join — the launch make-or-break metric
			local ttfc = math.floor(os.clock() - session.joinedClock)
			logCustomEvent(player, "TimeToFirstCatch", ttfc)
			print("[Analytics] " .. player.Name .. " first catch after " .. ttfc .. "s")
		end
	end
end)

-- ─── DAY COUNTER + CO-PLAY POLL ────────────────────────────────────────

-- Distinct-days-played: bump when this slot is played on a new UTC day
local function updateDayCounter(player, data)
	local today = os.date("!%Y-%m-%d")
	if data.lastPlayedDay ~= today then
		data.lastPlayedDay = today
		data.daysPlayed = (data.daysPlayed or 0) + 1
		logCustomEvent(player, "DistinctDayPlayed", data.daysPlayed)
	end
end

-- SaveManager: a save slot became active (New Game or Load Game).
--
-- Fired from the load itself rather than observed by the poll below. The poll
-- runs every 15s, so a player who joined and quit inside that window loaded
-- their data but never logged step 2 — and the players who quit fastest are
-- precisely the drop-off the funnel exists to measure, so the poll was biasing
-- the step it reported. The poll is kept as a backstop for slot switches.
--
-- Registered here, below updateDayCounter, because that is a `local`: a closure
-- created above its declaration would resolve the name as a (nil) global.
ServerRegistry.Register("OnDataLoaded", function(player, data)
	local session = sessions[player.UserId]
	if session then
		session.trackedData = data
	end
	logFunnelStep(player, "data_loaded")
	if data then
		updateDayCounter(player, data)
	end
end)

-- First co-op session: is any friend in this server right now?
-- IsFriendsWith can yield (web call), so this runs inside the poll's spawn.
local function checkCoplay(player, data, session)
	if data.firstCoopAt then return end
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and not session.coopChecked[other.UserId] then
			session.coopChecked[other.UserId] = true
			local ok, isFriend = pcall(function()
				return player:IsFriendsWith(other.UserId)
			end)
			if ok and isFriend then
				data.firstCoopAt = os.time()
				logCustomEvent(player, "FirstCoopSession", 1)
				ServerRegistry.Call("CheckMilestones", player)
				print("[Analytics] " .. player.Name .. " first co-op session (friend: " .. other.Name .. ")")
				return
			end
		end
	end
end

task.spawn(function()
	local sinceCoplayCheck = 0
	local POLL_INTERVAL = 15
	while true do
		task.wait(POLL_INTERVAL)
		sinceCoplayCheck += POLL_INTERVAL
		local doCoplay = GrowthConfig.Coplay.trackingEnabled
			and sinceCoplayCheck >= GrowthConfig.Coplay.checkIntervalSeconds
		if doCoplay then sinceCoplayCheck = 0 end

		for _, player in ipairs(Players:GetPlayers()) do
			local session = sessions[player.UserId]
			local data = getData(player)
			if session and data then
				if session.trackedData ~= data then
					-- First time seeing this slot's data this session (or the
					-- player switched slots): funnel step + day counter
					session.trackedData = data
					logFunnelStep(player, "data_loaded")
				end
				updateDayCounter(player, data)
				if doCoplay then
					task.spawn(checkCoplay, player, data, session)
				end
			end
		end
	end
end)

-- ─── SESSION LIFECYCLE ─────────────────────────────────────────────────

local function onPlayerAdded(player)
	sessions[player.UserId] = {
		joinedClock = os.clock(),
		loggedSteps = {},
		trackedData = nil,
		coopChecked = {},
	}
	logFunnelStep(player, "joined")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	sessions[player.UserId] = nil
end)

print("[AnalyticsSystem] Initialized (onboarding funnel + growth telemetry)")
