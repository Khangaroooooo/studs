-- EncounterSystem: Detects player movement in encounter zones and triggers wild Stud encounters
-- Modified: Now tracks encounter state (HP) and handles encounter actions (Attack, Catch, Run)
-- 10% chance per step when walking in tall grass
-- Supports healing cooldown from StudCenter/PlayerHouse

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 10)
if not StudEvents then
	warn("[EncounterSystem] Failed to find StudEvents folder!")
	return
end

local encounterStartEvent = StudEvents:WaitForChild("EncounterStart", 10)
if not encounterStartEvent then
	warn("[EncounterSystem] Failed to find EncounterStart RemoteEvent!")
	return
end

local catchAttemptEvent = StudEvents:WaitForChild("CatchAttempt", 10)
if not catchAttemptEvent then
	warn("[EncounterSystem] Failed to find CatchAttempt RemoteEvent!")
	return
end

local encounterActionFunc = StudEvents:FindFirstChild("EncounterAction")
if not encounterActionFunc then
	warn("[EncounterSystem] Failed to find EncounterAction RemoteFunction!")
	return
end

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local BattleTeam = require(ReplicatedStorage:WaitForChild("BattleTeam"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local GrowthConfig = require(ReplicatedStorage:WaitForChild("GrowthConfig"))

-- FTUE: true until the player's active save has its first catch. Drives the
-- first-catch-in-60s tuning (faster first encounter, near-guaranteed catch).
local function isPreFirstCatch(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	return playerInfo and playerInfo.data and (playerInfo.data.totalCaught or 0) == 0
end

-- ANTI-CHEAT: clients report each minigame tap through this event so the
-- server can require a plausible number of taps before granting a catch.
-- Created at runtime like the other dynamic remotes (RenameSaveSlot etc.).
local catchTapEvent = StudEvents:FindFirstChild("CatchTap")
if not catchTapEvent then
	catchTapEvent = Instance.new("RemoteEvent")
	catchTapEvent.Name = "CatchTap"
	catchTapEvent.Parent = StudEvents
end

-- Minimum taps needed to plausibly fill the catch bar, per rarity. These are
-- the mathematical floor across BOTH client minigames (circle-tap with max
-- type-advantage + CatchBoost multipliers, and the BattleUI tap-bar), so a
-- legitimate player can never trip them — but a remote-spamming exploiter
-- who skips the minigame will.
-- Floor math (circle minigame, the fastest legit path): per-tap fill =
-- barFillRate * 15 * 1.5 CatchBoost → Common 22.5, Uncommon 20.25, Rare 18,
-- Legendary 15.75 per tap, so a real catch can't finish under these counts.
local MIN_CATCH_TAPS = {
	Common = 3,
	Uncommon = 5,
	Rare = 8,
	Legendary = 11,
}

-- Track player encounter state
local playerEncounters = {}

local ENCOUNTER_RATE = 0.10
local STEP_THRESHOLD = 4
local HEAL_COOLDOWN = 30

-- Reward configuration (damage tuning lives in ReplicatedStorage/Combat)
local CONFIG = {
	WIN_COINS_MIN = 15,
	WIN_COINS_MAX = 50,
}

-- Helper: get max HP based on rarity + level
local function getMaxHP(rarity, level)
	return StudData.GetMaxHP(rarity, level or 1)
end

-- Helper: find highest-level caught entry for a species (shared with BattleSystem)
local getOwnedEntry = BattleTeam.GetOwnedEntry

-- Helper: one wild counter-attack against the player's stud (shared by the
-- Attack exchange, failed catches, and failed flees)
local function wildAttack(info)
	return Combat.CalculateDamage({
		attacker = info.wildStud,
		defender = info.playerStud,
		attackerLevel = info.wildLevel,
		defenderLevel = info.playerLevel,
		defNature = info.playerEntry and info.playerEntry.nature or nil,
		atkEffects = info.wildEffects,
		defEffects = info.playerEffects,
		attackerHpFrac = info.wildMaxHP and info.wildMaxHP > 0 and (info.wildHP / info.wildMaxHP) or nil,
	})
end

-- Helper: fainting costs coins — fewer when the wild outleveled you, more
-- when you lost to a weaker one (Combat.CalculateFaintPenalty). Returns
-- the coins actually lost.
local function applyFaintPenalty(player, info)
	local apd = ServerRegistry.Get("ActivePlayers")
	local pInfo = apd and apd[player.UserId]
	if not pInfo or not pInfo.data then return 0 end
	local loss = Combat.CalculateFaintPenalty(pInfo.data.coins, info.playerLevel, info.wildLevel)
	if loss > 0 then
		pInfo.data.coins = (pInfo.data.coins or 0) - loss
		StudEvents.UpdateCoins:FireClient(player, pInfo.data.coins)
		player:SetAttribute("Coins", pInfo.data.coins)
	end
	return loss
end

-- ─── CHAIN HUNTING ─────────────────────────────────────────────────────
-- Consecutive catches of the SAME species build a chain that multiplies
-- that species' shiny odds on future encounters. The chain only continues
-- through catches: a failed catch, a flee, a faint, or KO-ing the wild all
-- break it; catching a different species restarts it on that species.
local CHAIN_SHINY_PER_LINK = 0.4 -- +40% shiny odds per link
local CHAIN_SHINY_MAX_MULT = 6
local CHAIN_SHINY_CAP = 1 / 8 -- absolute ceiling (even with ShinyCharm)

local function bumpChain(player, info, studId)
	if info.chainSpecies == studId then
		info.chainCount = (info.chainCount or 0) + 1
	else
		info.chainSpecies = studId
		info.chainCount = 1
	end
	player:SetAttribute("ChainSpecies", studId)
	player:SetAttribute("ChainCount", info.chainCount)
	return info.chainCount
end

local function resetChain(player, info)
	if not info.chainSpecies and (info.chainCount or 0) == 0 then return end
	info.chainSpecies = nil
	info.chainCount = 0
	player:SetAttribute("ChainSpecies", nil)
	player:SetAttribute("ChainCount", 0)
end

-- Forward declaration: onPlayerFaint (below) ends the encounter on a loss,
-- but endEncounter itself is defined further down.
local endEncounter

-- ─── BATTLE TEAM ───────────────────────────────────────────────────────
-- The encounter is fought by a team of up to BattleTeam.MAX_TEAM studs
-- (data.equippedTeam, lead first). Only the active member fights; the player
-- can Switch to a reserve (costs the turn) or is forced to send one in when
-- the active faints. The team model (build/snapshot/switch/reserve) is shared
-- with BattleSystem via ReplicatedStorage/BattleTeam; only the transport here
-- (EncounterAction result tables) is encounter-specific.

-- Resolve a player faint: if a reserve is alive the battle continues with a
-- (free) forced switch; otherwise the player loses. Fills `result` and returns
-- true when the battle continues, false when it ended in a loss.
local function onPlayerFaint(player, info, result)
	BattleTeam.MarkActiveFainted(info)
	if BattleTeam.HasReserve(info) then
		info.pendingSwitch = true
		result.result = "force_switch"
		result.team = BattleTeam.Snapshot(info)
		return true
	end
	result.result = "player_fainted"
	result.coinsLost = applyFaintPenalty(player, info)
	resetChain(player, info)
	endEncounter(player)
	return false
end

-- Helper: end encounter and unfreeze player
function endEncounter(player)
	local info = playerEncounters[player.UserId]
	if info then
		info.inEncounter = false
		info.wildStud = nil
		info.wildHP = 0
		info.wildMaxHP = 0
		info.playerStud = nil
		info.playerHP = 0
		info.playerMaxHP = 0
		info.isShiny = nil
		info.wildLevel = nil
		info.playerLevel = nil
		info.playerEntry = nil
		info.catchStartedAt = nil
		info.catchTaps = nil
		info.lastTapAt = nil
		info.ballMult = nil
		info.wildStatus = nil
		info.team = nil
		info.activeIndex = nil
		info.pendingSwitch = nil

		local character = player.Character
		if character then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				-- Restore the speed captured at encounter start — a hardcoded
				-- 16 used to silently strip Sprint/buff speeds
				humanoid.WalkSpeed = info.prevWalkSpeed or 16
			end
		end
		info.prevWalkSpeed = nil
	end
end

-- Helper: determine if it's currently night
local function isNightTime()
	local clockTime = Lighting.ClockTime or 12
	return clockTime >= 18 or clockTime < 6
end

-- Rarity encounter announcement thresholds
local RARITY_ANNOUNCE = {
	Legendary = true,
	Rare = true,
}

-- PERF: the zone lookup runs every ~4 studs walked for EVERY player, so it
-- can't afford to rescan the whole workspace each time. Cache the zone base
-- parts once and refresh periodically (zones are static world geometry; the
-- refresh only exists to pick up late-loading/streamed worlds).
local zoneCache = {} -- array of { name = zoneName, part = BasePart }

local function rebuildZoneCache()
	local cache = {}
	for _, worldFolder in Workspace:GetChildren() do
		if worldFolder:IsA("Folder") or worldFolder:IsA("Model") then
			local encounterFolder = worldFolder:FindFirstChild("EncounterZones")
			if encounterFolder then
				for _, zone in encounterFolder:GetChildren() do
					if zone:IsA("Model") or zone:IsA("Folder") then
						-- Find the base part (could be named GrassBase, FireNorthBase, etc.)
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
							table.insert(cache, { name = zone.Name, part = basePart })
						end
					end
				end
			end
		end
	end
	zoneCache = cache
end

rebuildZoneCache()
task.spawn(function()
	while task.wait(30) do
		rebuildZoneCache()
	end
end)

local function getEncounterZone(position)
	for _, zone in ipairs(zoneCache) do
		local part = zone.part
		if part.Parent then
			local halfSize = part.Size / 2
			local relPos = position - part.Position
			if math.abs(relPos.X) <= halfSize.X and math.abs(relPos.Z) <= halfSize.Z then
				return zone.name
			end
		end
	end
	return nil
end

local function onPlayerAdded(player)
	playerEncounters[player.UserId] = {
		lastStepPos = nil,
		stepsInZone = 0,
		inEncounter = false,
		totalEncounters = 0,
		wildStud = nil,
		wildHP = 0,
		wildMaxHP = 0,
		playerStud = nil,
		playerHP = 0,
		playerMaxHP = 0,
		isShiny = false,
	}

	-- Fresh characters restart step tracking on the next poll tick
	player.CharacterAdded:Connect(function()
		local info = playerEncounters[player.UserId]
		if info then
			info.lastStepPos = nil
		end
	end)
end

-- One poll tick for one player: step tracking + encounter roll.
-- PERF: previously each CharacterAdded spawned its own 0.3s while-loop,
-- so N players meant N independent loops (and dead characters' loops
-- lingered until their IsDescendantOf check caught up). A single shared
-- heartbeat below calls this for everyone.
local function pollPlayer(player)
	local info = playerEncounters[player.UserId]
	if not info or info.inEncounter then
		return
	end

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if humanoid.MoveDirection.Magnitude < 0.1 then
		return
	end

	if not info.lastStepPos then
		info.lastStepPos = hrp.Position
		return
	end

	local dist = (hrp.Position - info.lastStepPos).Magnitude
	if dist < STEP_THRESHOLD then
		return
	end
	info.lastStepPos = hrp.Position
	info.stepsInZone = info.stepsInZone + 1

	local zoneName = getEncounterZone(hrp.Position)
	if zoneName then
		local lastHeal = player:GetAttribute("LastHealTime") or 0
		if os.time() - lastHeal < HEAL_COOLDOWN then
			return
		end

		local encounterRate = ENCOUNTER_RATE
		if player:GetAttribute("StudLure") then
			encounterRate = encounterRate * 2
		end

		-- FTUE: before the first catch, encounters trigger much faster so a
		-- brand-new player reaches "the fun" inside the first minute
		if isPreFirstCatch(player) then
			encounterRate = math.max(encounterRate, ENCOUNTER_RATE * GrowthConfig.FTUE.firstEncounterRateMult)
		end

		-- Roaming legendary event (EventSystem): boosted
		-- encounter rate inside the event zone
		local event = ServerRegistry.Get("ActiveLegendaryEvent")
		if event and event.zoneName == zoneName and os.time() < event.endsAt then
			encounterRate = encounterRate * 2
		else
			event = nil
		end

		if math.random() < encounterRate then
			local nightTime = isNightTime()
			local luckyCharm = player:GetAttribute("LuckyCharm") == true
			local weather = ReplicatedStorage:GetAttribute("CurrentWeather")

			local stud
			-- During a legendary event, 25% of encounters
			-- in the event zone ARE the roaming legendary
			if event and math.random() < 0.25 then
				stud = StudData.GetStudById(event.studId)
			end
			if not stud then
				stud = StudData.PickRandomStud(zoneName, nightTime, luckyCharm, weather)
			end
			if stud then
				-- Shiny Charm gamepass doubles shiny odds
				local shinyChance = StudData.SHINY_CHANCE
				if player:GetAttribute("ShinyCharm") then
					shinyChance = shinyChance * 2
				end
				-- Chain bonus: consecutive catches of THIS species
				-- multiply its shiny odds (capped)
				if info.chainSpecies == stud.id and (info.chainCount or 0) > 0 then
					shinyChance = shinyChance
						* math.min(1 + CHAIN_SHINY_PER_LINK * info.chainCount, CHAIN_SHINY_MAX_MULT)
				end
				shinyChance = math.min(shinyChance, CHAIN_SHINY_CAP)
				local isShiny = math.random() < shinyChance
				info.inEncounter = true
				info.totalEncounters = info.totalEncounters + 1
				ServerRegistry.Call("OnEncounterStarted", player) -- AnalyticsSystem funnel

				-- Build the battle team (lead first). The active member drives the
				-- wild-level scaling and all the existing single-stud fields.
				local playerStud, playerLevel = nil, 1
				local playerHeldItem = nil
				do
					local apd = ServerRegistry.Get("ActivePlayers")
					local pInfo = apd and apd[player.UserId]
					if pInfo and pInfo.data then
						info.team = BattleTeam.Build(pInfo)
						info.activeIndex = 1
						info.pendingSwitch = nil
						local active = info.team[1]
						if active then
							playerStud = active.stud
							playerLevel = active.level
							playerHeldItem = active.heldItem
							info.playerEntry = active.entry
						end
					else
						info.team = nil
						info.activeIndex = nil
					end
				end
				-- Wild level comes from the WORLD's level band
				-- (Studville 1-15 ... Duskwood 70-95) so
				-- regions have a real difficulty arc.
				-- Unbanded zones fall back to player ±2.
				local wildLevel
				local band = StudData.GetZoneLevelRange(zoneName)
				if band then
					wildLevel = math.random(band.min, band.max)
				else
					wildLevel = math.clamp(playerLevel + math.random(-2, 2), 1, StudData.MAX_LEVEL)
				end

				-- Set up encounter state with HP
				info.wildStud = stud
				info.wildLevel = wildLevel
				info.playerLevel = playerLevel
				info.wildMaxHP = getMaxHP(stud.rarity, wildLevel)
				info.wildHP = info.wildMaxHP
				info.isShiny = isShiny
				info.catchStartedAt = nil

				-- Load the lead as the active stud (HP/effects come from the
				-- prebuilt member so switches preserve damage). Passive effects
				-- were resolved per-member in BattleTeam.Build.
				if info.team and info.team[1] then
					BattleTeam.SetActive(info, 1)
				else
					info.playerStud = nil
					info.playerMaxHP = 0
					info.playerHP = 0
					info.playerEffects = nil
				end
				info.wildEffects = Combat.GatherEffects(stud, nil)

				-- SPEED: a faster wild stud gets a free opening
				-- hit (never a KO — the player's stud always
				-- hangs on at 1 HP)
				local firstStrike = nil
				if playerStud then
					local wildSpd = Combat.GetSpeed(stud, nil)
					local playerSpd = Combat.GetSpeed(playerStud, info.playerEntry and info.playerEntry.nature or nil)
					if wildSpd > playerSpd then
						local dmg, isCrit = wildAttack(info)
						dmg = math.min(dmg, math.max(0, info.playerHP - 1))
						if dmg > 0 then
							info.playerHP -= dmg
							firstStrike = { dmg = dmg, isCrit = isCrit }
						end
					end
				end

				-- Build encounter data
				local color = isShiny and StudData.GetShinyColor(StudData.GetStudColor(stud)) or StudData.GetStudColor(stud)
				local r = math.floor(color.R * 255)
				local g = math.floor(color.G * 255)
				local b = math.floor(color.B * 255)

				local encounterData = {
					id = stud.id,
					name = stud.name,
					studType = stud.studType,
					rarity = stud.rarity,
					description = stud.description,
					colorR = r,
					colorG = g,
					colorB = b,
					encounterNum = info.totalEncounters,
					isShiny = isShiny,
					wildLevel = wildLevel,
					wildMaxHP = info.wildMaxHP,
					wildHP = info.wildHP,
					-- FTUE: tells the circle minigame to use the near-guaranteed
					-- first-catch tuning (server enforces its own generous floor)
					ftueEasyCatch = (GrowthConfig.FTUE.firstCatchGenerous and isPreFirstCatch(player)) or nil,
				}

				if playerStud then
					encounterData.playerStud = {
						id = playerStud.id,
						name = playerStud.name,
						studType = playerStud.studType,
						rarity = playerStud.rarity,
						level = playerLevel,
						exp = info.playerEntry and info.playerEntry.exp or 0,
						heldItem = playerHeldItem, -- item id (nil if none) for HUD passive display
					}
					encounterData.playerMaxHP = info.playerMaxHP
					encounterData.playerHP = info.playerHP
					encounterData.firstStrike = firstStrike
					encounterData.team = BattleTeam.Snapshot(info)
				end

				encounterStartEvent:FireClient(player, encounterData)

				-- Freeze, remembering the current speed so endEncounter can
				-- restore it (Sprint/buffs survive encounters now)
				info.prevWalkSpeed = humanoid.WalkSpeed
				humanoid.WalkSpeed = 0

				if RARITY_ANNOUNCE[stud.rarity] or isShiny then
					for _, otherPlayer in Players:GetPlayers() do
						if otherPlayer ~= player then
							StudEvents.EncounterResult:FireClient(otherPlayer, {
								type = isShiny and "shinySighting" or "rareSighting",
								playerName = player.Name,
								studName = stud.name,
								rarity = stud.rarity,
							})
						end
					end
				end

				print("[EncounterSystem] Encounter #" .. info.totalEncounters .. " with", stud.name, "(" .. stud.rarity .. ") for", player.Name)
			else
				warn("[EncounterSystem] PickRandomStud returned nil for zone", zoneName)
			end
		end
	end
end

-- Shared heartbeat: one loop polls every player (see pollPlayer above)
task.spawn(function()
	while true do
		task.wait(0.3)
		for _, player in ipairs(Players:GetPlayers()) do
			pollPlayer(player)
		end
	end
end)

-- Handle encounter actions (Attack, Run, CatchStart, CatchSuccess, CatchFail)
-- Third arg is per-action payload: move index (number) for Attack, chosen
-- ball id (string, "none"/nil = no ball) for CatchStart.
encounterActionFunc.OnServerInvoke = function(player, action, arg)
	local info = playerEncounters[player.UserId]
	if not info or not info.inEncounter then
		return { success = false, reason = "no_encounter" }
	end

	if type(action) ~= "string" then
		return { success = false, reason = "invalid_action" }
	end
	local moveIndex = type(arg) == "number" and arg or nil
	local requestedBallId = type(arg) == "string" and arg or nil

	-- While a faint is pending, the only legal move is sending in a reserve
	if info.pendingSwitch and action ~= "Switch" then
		return { success = false, reason = "must_switch" }
	end

	if action == "Attack" then
		if not info.playerStud then
			return { success = false, reason = "no_stud" }
		end

		-- Move power with server-side level gating (locked moves fall back
		-- to the basic move, so exploiters can't spam the 2.0x at Lv1)
		local movePower, moveName, accuracy, move = Combat.ResolveMove(info.playerStud, moveIndex, info.playerLevel)

		local playerDmg, isCrit, eff, missed = Combat.CalculateDamage({
			attacker = info.playerStud,
			defender = info.wildStud,
			movePower = movePower,
			accuracy = accuracy,
			attackerLevel = info.playerLevel,
			defenderLevel = info.wildLevel,
			atkNature = info.playerEntry and info.playerEntry.nature or nil,
			atkEffects = info.playerEffects,
			defEffects = info.wildEffects,
			attackerHpFrac = info.playerMaxHP and info.playerMaxHP > 0 and (info.playerHP / info.playerMaxHP) or nil,
		})
		info.wildHP = math.max(0, info.wildHP - playerDmg)

		local result = {
			success = true,
			action = "Attack",
			moveName = moveName,
			playerDmg = playerDmg,
			missed = missed,
			isCrit = isCrit,
			effectiveness = eff,
			wildHP = info.wildHP,
			wildMaxHP = info.wildMaxHP,
		}

		-- Status proc on a landed hit (mid-tier Fire/Ice/Electric moves)
		if not missed and playerDmg > 0 then
			local newStatus = Combat.RollMoveStatus(move, info.wildStatus, info.playerEffects, info.wildEffects)
			if newStatus then
				info.wildStatus = newStatus
				result.statusInflicted = newStatus.kind
			end
		end

		-- Wild status tick (burn chip / freeze / paralysis). The chip can
		-- finish the wild off, so this runs before the faint check; a skip
		-- suppresses the wild's counter-attack below.
		local skipCounter = false
		if info.wildHP > 0 and info.wildStatus then
			local chip, skip, cured, kind = Combat.TickStatus(info.wildStatus, info.wildMaxHP)
			if cured then
				info.wildStatus = nil
			end
			skipCounter = skip
			if chip > 0 then
				info.wildHP = math.max(0, info.wildHP - chip)
				result.wildHP = info.wildHP
			end
			result.statusTick = { kind = kind, chip = chip, skipped = skip, cured = cured }
		end

		if info.wildHP <= 0 then
			result.result = "wild_fainted"
			resetChain(player, info) -- chains only continue through catches
			local activePlayersData = ServerRegistry.Get("ActivePlayers")
			local playerInfo = activePlayersData and activePlayersData[player.UserId]
			if playerInfo and playerInfo.data then
				local coinReward = math.random(CONFIG.WIN_COINS_MIN, CONFIG.WIN_COINS_MAX)
				if info.wildStud.rarity == "Rare" then coinReward = coinReward * 2
				elseif info.wildStud.rarity == "Legendary" then coinReward = coinReward * 3 end
				playerInfo.data.coins = (playerInfo.data.coins or 0) + coinReward
				StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
				player:SetAttribute("Coins", playerInfo.data.coins)
				result.coins = coinReward
				result.totalCoins = playerInfo.data.coins
				if info.playerEntry then
					local expGained, levelsGained, newLevel = Combat.AwardExp(info.playerEntry, info.wildLevel or 1)
					result.expGained = expGained
					result.leveledUp = levelsGained > 0
					result.newLevel = newLevel
					result.newExp = info.playerEntry.exp
				end
			end
			endEncounter(player)
			return result
		end

		-- Frozen/paralyzed wilds lose their counter-attack this exchange
		if skipCounter then
			result.playerHP = info.playerHP
			result.playerMaxHP = info.playerMaxHP
			return result
		end

		local wildDmg, wildCrit, wildEff = wildAttack(info)
		info.playerHP = math.max(0, info.playerHP - wildDmg)

		result.wildDmg = wildDmg
		result.wildCrit = wildCrit
		result.wildEffectiveness = wildEff
		result.playerHP = info.playerHP
		result.playerMaxHP = info.playerMaxHP

		if info.playerHP <= 0 then
			onPlayerFaint(player, info, result)
			return result
		end

		return result

	elseif action == "Switch" then
		-- Swap the active stud for a team reserve. A voluntary switch costs the
		-- turn (the wild gets a free hit); a forced switch after a faint is free
		-- (info.pendingSwitch).
		if not info.team or #info.team <= 1 then
			return { success = false, reason = "no_team" }
		end
		local targetIdx = moveIndex
		local target = targetIdx and info.team[targetIdx]
		if not target or targetIdx == info.activeIndex or target.fainted or target.hp <= 0 then
			return { success = false, reason = "invalid_switch" }
		end

		local forced = info.pendingSwitch
		-- Persist the outgoing stud's current HP before swapping the target in
		if not forced and info.team[info.activeIndex] then
			info.team[info.activeIndex].hp = info.playerHP
		end
		BattleTeam.SetActive(info, targetIdx)
		info.pendingSwitch = nil

		local result = {
			success = true,
			action = "Switch",
			switchedTo = BattleTeam.ActivePayload(info),
			playerHP = info.playerHP,
			playerMaxHP = info.playerMaxHP,
			team = BattleTeam.Snapshot(info),
		}

		-- Forced (post-faint) switch: free, the player acts next
		if forced then
			return result
		end

		-- Voluntary switch: the wild gets its free hit
		local wildDmg, wildCrit, wildEff = wildAttack(info)
		info.playerHP = math.max(0, info.playerHP - wildDmg)
		result.wildDmg = wildDmg
		result.wildCrit = wildCrit
		result.wildEffectiveness = wildEff
		result.playerHP = info.playerHP
		if info.playerHP <= 0 then
			onPlayerFaint(player, info, result)
		else
			result.team = BattleTeam.Snapshot(info)
		end
		return result

	elseif action == "Run" then
		-- SPEED: flee odds scale with the speed gap. No equipped stud =
		-- guaranteed escape (there's nothing to fight with). A failed flee
		-- costs a free wild hit, like a failed catch.
		if not info.playerStud then
			resetChain(player, info) -- fleeing breaks the chain
			endEncounter(player)
			return { success = true, action = "Run", result = "escaped" }
		end

		local playerSpd = Combat.GetSpeed(info.playerStud, info.playerEntry and info.playerEntry.nature or nil)
		local wildSpd = Combat.GetSpeed(info.wildStud, nil)
		local fleeChance = math.clamp(0.6 + (playerSpd - wildSpd) * 0.02, 0.3, 0.95)
		if math.random() < fleeChance then
			resetChain(player, info) -- fleeing breaks the chain
			endEncounter(player)
			return { success = true, action = "Run", result = "escaped" }
		end

		local wildDmg, wildCrit, wildEff = wildAttack(info)
		info.playerHP = math.max(0, info.playerHP - wildDmg)

		local result = {
			success = true,
			action = "Run",
			result = "flee_failed",
			wildDmg = wildDmg,
			wildCrit = wildCrit,
			wildEffectiveness = wildEff,
			playerHP = info.playerHP,
			playerMaxHP = info.playerMaxHP,
		}
		if info.playerHP <= 0 then
			onPlayerFaint(player, info, result)
		end
		return result

	elseif action == "CatchStart" then
		info.catchStartedAt = os.clock()
		info.catchTaps = 0
		info.lastTapAt = 0
		local hpRatio = info.wildHP / info.wildMaxHP
		local rarity = info.wildStud.rarity
		ServerRegistry.Call("OnCatchStarted", player) -- AnalyticsSystem funnel

		-- Consume the ball the PLAYER CHOSE in the catch picker (nil/"none" =
		-- no ball; an unowned/invalid id is treated as none, never an error).
		-- It shrinks the catch bar target for this attempt and is spent
		-- whether or not the catch lands. The CatchSuccess min-tap floor
		-- scales to match.
		info.ballMult = 1
		local ballName = nil
		if requestedBallId and requestedBallId ~= "none" then
			local ball = StudData.GetCatchBall(requestedBallId)
			local apd = ServerRegistry.Get("ActivePlayers")
			local pInfo = apd and apd[player.UserId]
			local items = pInfo and pInfo.data and pInfo.data.items
			if ball and items and (items[ball.id] or 0) > 0 then
				items[ball.id] = items[ball.id] - 1
				if items[ball.id] <= 0 then
					items[ball.id] = nil
				end
				info.ballMult = ball.targetMult
				ballName = ball.name
			end
		end

		local timerDuration = 5 + (1 - hpRatio) * 15

		-- Fallback tap-bar tuning. Must stay winnable at ~2-3 taps/sec: the old
		-- Legendary row (fill 2 / decay 8) needed 4 taps/sec just to break even,
		-- which made Legendaries uncatchable on this path.
		local catchParams = {
			Common = { barTarget = 50, fillPerTap = 8, decayRate = 2 },
			Uncommon = { barTarget = 70, fillPerTap = 7, decayRate = 2.5 },
			Rare = { barTarget = 100, fillPerTap = 6, decayRate = 3 },
			Legendary = { barTarget = 120, fillPerTap = 6, decayRate = 3.5 },
		}
		local params = catchParams[rarity] or catchParams.Common

		-- FTUE: the very first catch succeeds on near-any input (generous bar,
		-- barely any decay, long timer) — first-catch-in-60s design
		if GrowthConfig.FTUE.firstCatchGenerous and isPreFirstCatch(player) then
			params = { barTarget = 30, fillPerTap = 12, decayRate = 0.5 }
			timerDuration = 20
		end

		return {
			success = true,
			action = "CatchStart",
			hpRatio = hpRatio,
			timerDuration = timerDuration,
			barTarget = math.max(20, math.floor(params.barTarget * info.ballMult + 0.5)),
			fillPerTap = params.fillPerTap,
			decayRate = params.decayRate,
			rarity = rarity,
			-- Ball bonus for the client-side circle minigame (it computes its
			-- own bar target from StudData rarity config)
			ballMult = info.ballMult,
			ballName = ballName,
		}

	elseif action == "CatchSuccess" then
		if not info.wildStud then
			return { success = false, reason = "no_wild_stud" }
		end
		-- ANTI-CHEAT: the fill-the-bar minigame runs on the client, so require
		-- (a) CatchStart was actually invoked, (b) a minimum plausible time
		-- elapsed, and (c) the client reported a plausible number of minigame
		-- taps via the CatchTap event. Blocks the "invoke CatchStart, wait
		-- 1.5s, invoke CatchSuccess" free-Legendary exploit.
		local minTaps = MIN_CATCH_TAPS[info.wildStud.rarity] or MIN_CATCH_TAPS.Common
		-- A catch ball shrinks the bar target, so the legit-minimum tap count
		-- shrinks by the same factor
		minTaps = math.max(2, math.floor(minTaps * (info.ballMult or 1) + 0.5))
		-- FTUE: the generous first-catch bar fills in fewer taps, so the
		-- plausibility floor must shrink to match
		if GrowthConfig.FTUE.firstCatchGenerous and isPreFirstCatch(player) then
			minTaps = 2
		end
		if not info.catchStartedAt
			or (os.clock() - info.catchStartedAt) < 1.5
			or (info.catchTaps or 0) < minTaps
		then
			-- CRITICAL: must end the encounter here. Previously this early
			-- return left info.inEncounter = true forever, which (a) silently
			-- dropped the caught stud and (b) blocked ALL future encounters
			-- for that player until rejoin. That was the "stud not in
			-- inventory + can't encounter again" bug.
			endEncounter(player)
			return { success = false, reason = "catch_not_started" }
		end
		info.catchStartedAt = nil

		local studId = info.wildStud.id
		local studName = info.wildStud.name
		local isShiny = info.isShiny or false
		local wildLevel = info.wildLevel or 1

		-- All grant logic (collection insert, dupes -> evo points, coins,
		-- attributes, quest/streak/milestone hooks) lives in SaveManager's
		-- GrantCatch so the Battle Arena shares the exact same economy.
		local grant = ServerRegistry.Call("GrantCatch", player, studId, {
			isShiny = isShiny,
			level = wildLevel,
		})
		if not grant then
			endEncounter(player)
			return { success = false, reason = "no_data" }
		end

		local catchSuccessEvent = StudEvents:FindFirstChild("CatchSuccess")
		if catchSuccessEvent then
			catchSuccessEvent:FireClient(player, studId)
		end

		-- Chain hunting: consecutive catches of the same species raise its
		-- shiny odds on future encounters (different species = new chain)
		local chainCount = bumpChain(player, info, studId)

		-- Catch EXP: catching feeds the leveling loop too, so the optimal
		-- play is no longer "beat up everything, never catch". Goes to the
		-- equipped stud that did the weakening.
		local expGained, leveledUp, newLevel, newExp
		if info.playerEntry then
			expGained = StudData.GetCatchExpReward(wildLevel, info.wildStud.rarity)
			local levelsGained, lvl = Combat.GrantExp(info.playerEntry, expGained)
			leveledUp = levelsGained > 0
			newLevel = lvl
			newExp = info.playerEntry.exp
		end

		endEncounter(player)
		return {
			success = true,
			action = "CatchSuccess",
			result = "caught",
			studId = studId,
			studName = studName,
			isNew = grant.isNew,
			coins = grant.coinsAwarded, -- what the "+X coins!" log displays
			totalCoins = grant.totalCoins,
			expGained = expGained,
			leveledUp = leveledUp,
			newLevel = newLevel,
			newExp = newExp,
			chainCount = chainCount,
		}

	elseif action == "CatchFail" then
		ServerRegistry.Call("OnCatchResolved", player, false) -- streak broken
		resetChain(player, info) -- a failed catch breaks the chain too
		if not info.playerStud then
			endEncounter(player)
			return { success = true, action = "CatchFail", result = "no_stud_escaped" }
		end

		local wildDmg, wildCrit, wildEff = wildAttack(info)
		info.playerHP = math.max(0, info.playerHP - wildDmg)

		local result = {
			success = true,
			action = "CatchFail",
			wildDmg = wildDmg,
			wildCrit = wildCrit,
			wildEffectiveness = wildEff,
			playerHP = info.playerHP,
			playerMaxHP = info.playerMaxHP,
		}

		if info.playerHP <= 0 then
			onPlayerFaint(player, info, result)
			return result
		end

		return result
	end

	return { success = false, reason = "invalid_action" }
end

-- Count minigame taps for the CatchSuccess plausibility check. Rate-capped
-- so a tap-flooding exploiter gains nothing beyond a legit fast clicker.
catchTapEvent.OnServerEvent:Connect(function(player)
	local info = playerEncounters[player.UserId]
	if not info or not info.inEncounter or not info.catchStartedAt then return end
	local now = os.clock()
	if now - (info.lastTapAt or 0) < 0.04 then return end -- >25 taps/s is not human
	info.lastTapAt = now
	info.catchTaps = (info.catchTaps or 0) + 1
end)

-- SECURITY: the legacy CatchAttempt OnServerEvent handler was removed — the
-- real client never fires it (it only holds a reference), and it let any
-- exploiter end an encounter for free, skipping the CatchFail streak reset
-- and counter-attack. Escaping is only possible through the "Run" action.

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	playerEncounters[player.UserId] = nil
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[EncounterSystem] Initialized successfully")