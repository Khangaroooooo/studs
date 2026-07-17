-- StorySystem: server driver for the "Seven Ways Home" story mode.
-- All TEXT lives in ReplicatedStorage/StoryData; this script only decides
-- WHEN a beat fires and remembers that it fired (once per save slot).
--
-- Design rules (from the story docs, non-negotiable):
--   * Fully ambient — story never gates the catch loop or any system.
--   * Story/Casual is switchable mid-save (Settings). Beats that would
--     have fired while in Casual are NOT consumed; the triggers below are
--     re-checked on every catch/world-entry, so switching to Story later
--     picks the thread back up instead of leaving holes.
--   * The ending choice grants a cosmetic title only (the tentative
--     EXP/damage buff idea is deferred — PvP-fairness tension unresolved).
--
-- Beats travel over StudEvents.StoryBeat as { kind, ... } payloads; the
-- client (StoryUI) looks the text up in StoryData by id.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local StoryData = require(ReplicatedStorage:WaitForChild("StoryData"))

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

-- Rojo declares these remotes (model.json); create them here if they
-- haven't synced yet — same pattern as WorldTeleport/LeaderboardSystem
local function ensureRemote(name)
	local remote = StudEvents:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = StudEvents
	end
	return remote
end

local storyBeatEvent = ensureRemote("StoryBeat")
local setStoryModeEvent = ensureRemote("SetStoryMode")
local storyChoiceEvent = ensureRemote("StoryChoice")

local activePlayers = ServerRegistry.WaitFor("ActivePlayers", 30)
if not activePlayers then
	warn("[StorySystem] ActivePlayers never registered — story beats disabled")
	return
end

-- ─── SAVE-DATA ACCESS (nil-safe for saves older than story mode) ───────

local function getData(player)
	local info = activePlayers[player.UserId]
	return info and info.data or nil
end

local function getStory(data)
	if type(data.story) ~= "table" then
		data.story = {}
	end
	local story = data.story
	story.seen = story.seen or {}
	story.worldCatches = story.worldCatches or {}
	return story
end

local function storyOn(data)
	return data.storyMode ~= false
end

local function uniqueCount(data)
	local n = 0
	for _ in pairs(data.speciesCounts or {}) do
		n += 1
	end
	return n
end

local function registryComplete(data)
	local total = #StudData.Studs
	return total > 0 and uniqueCount(data) >= total
end

local function currentWorld(player)
	return player:GetAttribute("CurrentWorld") or "Studville"
end

-- ─── BEAT DELIVERY ─────────────────────────────────────────────────────
-- fireOnce marks the seen flag and sends the payload; callers pass the
-- seen key so chapters/legendaries/ways can key off world/species ids.

local function deliver(player, payload)
	storyBeatEvent:FireClient(player, payload)
end

local function fireOnce(player, data, seenKey, payload)
	local story = getStory(data)
	if story.seen[seenKey] then return false end
	if not storyOn(data) then return false end
	story.seen[seenKey] = true
	deliver(player, payload)
	return true
end

-- ─── OPENING (new game / first story session) ──────────────────────────
-- Merle greets you just after the starter pick, then the Studville chapter
-- card lands once you've had a minute to walk. Checked whenever the UI
-- gate opens, so old saves that switch to Story get it once too.

local function maybeOpening(player)
	if player:GetAttribute("GameStarted") ~= true then return end
	if player:GetAttribute("StarterChosen") == false then return end
	local data = getData(player)
	if not data or not storyOn(data) then return end
	local story = getStory(data)
	if story.seen["ch_Studville"] then return end

	task.delay(3, function()
		if not player.Parent then return end
		local d = getData(player)
		if d then
			fireOnce(player, d, "merle_welcome", { kind = "beat", id = "merle_welcome" })
		end
	end)
	task.delay(16, function()
		if not player.Parent then return end
		local d = getData(player)
		if d and currentWorld(player) == "Studville" then
			fireOnce(player, d, "ch_Studville", { kind = "chapter", world = "Studville" })
		end
	end)
end

-- ─── ENDING ────────────────────────────────────────────────────────────
-- Offered when the Registry is complete; re-offered on entering Duskwood
-- or rejoining until a choice is made (dismissing the panel never loses it).

local function maybeOfferEnding(player, data)
	local story = getStory(data)
	if story.ending then return end
	if not storyOn(data) then return end
	if not registryComplete(data) then return end
	deliver(player, { kind = "ending_offer" })
end

storyChoiceEvent.OnServerEvent:Connect(function(player, choice)
	if choice ~= "rest" and choice ~= "alive" then return end
	local data = getData(player)
	if not data then return end
	local story = getStory(data)
	if story.ending then return end
	if not registryComplete(data) then return end

	story.ending = choice
	local ending = StoryData.Ending.choices[choice]

	-- Cosmetic reward only: a title, same pipeline as the type-dex titles
	data.titles = data.titles or {}
	table.insert(data.titles, ending.title)
	if not data.equippedTitle then
		data.equippedTitle = ending.title
	end
	player:SetAttribute("DexTitle", data.equippedTitle)
	player:SetAttribute("StoryEnding", choice)

	deliver(player, { kind = "ending_epilogue", choice = choice })

	local milestoneEvent = StudEvents:FindFirstChild("MilestoneNotify")
	if milestoneEvent then
		milestoneEvent:FireClient(player, "story_ending_" .. choice,
			"The Last Page", "Title earned: " .. ending.title, "🖊️")
	end
	print("[StorySystem] " .. player.Name .. " chose the '" .. choice .. "' ending")
end)

-- ─── WORLD ENTRY (chapter intros) ──────────────────────────────────────

local function onWorldEnter(player, world)
	local data = getData(player)
	if not data then return end
	if not StoryData.Chapters[world] then return end

	-- Small delay so the note lands after WorldsUI's arrival cutscene
	task.delay(2.5, function()
		if not player.Parent then return end
		local d = getData(player)
		if not d then return end
		fireOnce(player, d, "ch_" .. world, { kind = "chapter", world = world })
		if world == "DuskwoodHollow" then
			maybeOfferEnding(player, d)
		end
	end)
end

-- ─── CATCHES (the main trigger — every rung re-checked, catch-up safe) ──

local function countWaysCaught(data)
	local counts = data.speciesCounts or {}
	local n = 0
	for _, way in ipairs(StoryData.BryanWays) do
		if (counts[way.studId] or 0) > 0 then
			n += 1
		end
	end
	return n
end

ServerRegistry.Register("OnStoryCatch", function(player, studId, isNew, wasPurchase)
	local data = getData(player)
	if not data then return end
	local story = getStory(data)

	-- Per-world catch counter (drives the deep notes). The starter purchase
	-- counts — it's the first neighbor you remember.
	local world = currentWorld(player)
	story.worldCatches[world] = (story.worldCatches[world] or 0) + 1

	if not storyOn(data) then return end -- counters advance in Casual; notes don't fire

	-- First wild catch of the save (the starter doesn't spend this beat)
	if not wasPurchase then
		fireOnce(player, data, "first_catch", { kind = "beat", id = "first_catch" })
	end

	-- Unique-dex twist rungs (fire late if the threshold passed in Casual)
	local unique = uniqueCount(data)
	for _, note in ipairs(StoryData.UniqueNotes) do
		if unique >= note.count then
			fireOnce(player, data, note.beatId, { kind = "beat", id = note.beatId })
		end
	end

	-- Per-world deep notes
	for _, note in ipairs(StoryData.WorldNotes) do
		if (story.worldCatches[note.world] or 0) >= note.count then
			fireOnce(player, data, note.beatId, { kind = "beat", id = note.beatId })
		end
	end

	-- Legendary re-meets: the region's most-remembered neighbors
	if StoryData.LegendaryIds[studId] and StoryData.DexAsides[studId] then
		fireOnce(player, data, "legend_" .. studId, { kind = "legend", studId = studId })
	end

	-- Bryan's Seven Ways: sweep ownership so ways obtained while in Casual
	-- (or via evolution, which skips GrantCatch) still get their beat
	local counts = data.speciesCounts or {}
	local waysCaught = countWaysCaught(data)
	for index, way in ipairs(StoryData.BryanWays) do
		if (counts[way.studId] or 0) > 0 then
			fireOnce(player, data, "way_" .. way.studId,
				{ kind = "way", index = index, caught = waysCaught })
		end
	end
	if waysCaught >= #StoryData.BryanWays then
		fireOnce(player, data, "ways_complete", { kind = "beat", id = "ways_complete" })
	end

	-- Registry complete → the Last Page
	maybeOfferEnding(player, data)
end)

-- ─── STORY/CASUAL TOGGLE (mid-save, Settings) ──────────────────────────

setStoryModeEvent.OnServerEvent:Connect(function(player, enabled)
	if type(enabled) ~= "boolean" then return end
	local data = getData(player)
	if not data then return end
	data.storyMode = enabled
	player:SetAttribute("StoryMode", enabled)
	if enabled then
		-- Re-open the thread where it left off
		maybeOpening(player)
		maybeOfferEnding(player, data)
	end
end)

-- ─── PLAYER WIRING ─────────────────────────────────────────────────────

local function watchPlayer(player)
	player:GetAttributeChangedSignal("CurrentWorld"):Connect(function()
		local world = player:GetAttribute("CurrentWorld")
		if world then
			onWorldEnter(player, world)
		end
	end)
	-- Fires on new game (starter picked) and on load (attributes set) alike
	player:GetAttributeChangedSignal("StarterChosen"):Connect(function()
		maybeOpening(player)
	end)
	player:GetAttributeChangedSignal("GameStarted"):Connect(function()
		maybeOpening(player)
		-- Rejoining with a complete Registry and no choice made → re-offer
		task.delay(8, function()
			if not player.Parent then return end
			local data = getData(player) -- re-fetch: slot may have switched
			if data then
				maybeOfferEnding(player, data)
			end
		end)
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	watchPlayer(player)
end

print("[StorySystem] Seven Ways Home initialized")
