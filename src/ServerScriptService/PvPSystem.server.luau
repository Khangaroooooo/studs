-- PvPSystem: turn-based 1v1 duels between players, using each side's
-- equipped stud (best copy: shiny preferred, then highest level).
--
-- Flow: challenge -> accept -> alternating turns (Attack/move or Defend).
-- Faster stud (speed stat x nature) moves first. 30s per turn or the turn
-- auto-defends; MAX_TURNS ends in a draw. Winner gets a small coin purse
-- (minted, not taken from the loser).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local CONFIG = {
	WIN_COINS = 30,
	MAX_TURNS = 40,
	TURN_TIME = 30,
	CHALLENGE_TIMEOUT = 45,
}

local pvpAction = StudEvents:FindFirstChild("PvPAction")
if not pvpAction then
	pvpAction = Instance.new("RemoteEvent")
	pvpAction.Name = "PvPAction"
	pvpAction.Parent = StudEvents
end
local pvpState = StudEvents:FindFirstChild("PvPState")
if not pvpState then
	pvpState = Instance.new("RemoteEvent")
	pvpState.Name = "PvPState"
	pvpState.Parent = StudEvents
end

local duels = {} -- [userId] = shared duel table
local challenges = {} -- [targetUserId] = { from = player, at = os.time() }

local function getData(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	return playerInfo and playerInfo.data or nil
end

-- Equipped species' best copy (shiny preferred, then level)
local function getBattleEntry(player)
	local data = getData(player)
	if not data or not data.equippedStudId then return nil, nil end
	local stud = StudData.GetStudById(data.equippedStudId)
	if not stud then return nil, nil end
	local best = nil
	for _, entry in ipairs(data.caughtStuds) do
		if entry.id == data.equippedStudId then
			if not best
				or (entry.isShiny and not best.isShiny)
				or (entry.isShiny == best.isShiny and (entry.level or 1) > (best.level or 1))
			then
				best = entry
			end
		end
	end
	local heldItem = data.heldItems and data.heldItems[data.equippedStudId] or nil
	return stud, best, heldItem
end

local function otherId(duel, userId)
	return duel.ids[1] == userId and duel.ids[2] or duel.ids[1]
end

local function sideInfo(duel, userId)
	local stud = duel.studs[userId]
	local entry = duel.entries[userId]
	return {
		userId = userId,
		playerName = duel.names[userId],
		id = stud.id,
		name = stud.name,
		studType = stud.studType,
		rarity = stud.rarity,
		level = duel.levels[userId],
		isShiny = entry.isShiny or false,
		nature = entry.nature,
		hp = duel.hp[userId],
		maxHP = duel.maxHP[userId],
	}
end

local function pushState(duel, extra)
	for _, userId in ipairs(duel.ids) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local payload = {
				action = extra and extra.action or "state",
				me = sideInfo(duel, userId),
				them = sideInfo(duel, otherId(duel, userId)),
				myTurn = duel.turnUserId == userId,
				turnCount = duel.turnCount,
				turnTime = CONFIG.TURN_TIME,
				log = extra and extra.log or nil,
				result = extra and extra.results and extra.results[userId] or nil,
			}
			pvpState:FireClient(player, payload)
		end
	end
end

local function endDuel(duel, winnerUserId, reason)
	if duel.over then return end
	duel.over = true
	duel.turnToken = (duel.turnToken or 0) + 1 -- invalidate pending timeout

	local results = {}
	for _, userId in ipairs(duel.ids) do
		duels[userId] = nil
		if not winnerUserId then
			results[userId] = "draw"
		else
			results[userId] = userId == winnerUserId and "win" or "lose"
		end
	end

	-- Winner's purse (minted; losing costs nothing)
	local endLog = { reason }
	if winnerUserId then
		local winner = Players:GetPlayerByUserId(winnerUserId)
		local data = winner and getData(winner)
		if winner and data then
			data.coins = (data.coins or 0) + CONFIG.WIN_COINS
			StudEvents.UpdateCoins:FireClient(winner, data.coins)
			ServerRegistry.Call("SyncPlayerAttributes", winner, data)
		end

		-- EXP for the winning stud, relative to the loser's level — but ONLY
		-- when the loser's stud actually fainted. Forfeits and disconnects
		-- pay no EXP, otherwise two friends could trade instant forfeits to
		-- farm levels. duel.entries holds live references into caughtStuds,
		-- so the level-up persists through the normal save path.
		local loserId = otherId(duel, winnerUserId)
		local loserFainted = (duel.hp[loserId] or 0) <= 0
		local entry = duel.entries[winnerUserId]
		if entry and loserFainted then
			local expGained, levelsGained, newLevel = Combat.AwardExp(entry, duel.levels[loserId])
			table.insert(endLog, duel.studs[winnerUserId].name .. " gained " .. expGained .. " EXP!")
			if levelsGained > 0 then
				table.insert(endLog, duel.studs[winnerUserId].name .. " grew to Lv" .. newLevel .. "!")
			end
		end

		-- Daily-quest hook: only fully-fought wins count
		local winnerPlayer = Players:GetPlayerByUserId(winnerUserId)
		if loserFainted and winnerPlayer then
			ServerRegistry.Call("OnBattleWon", winnerPlayer)
		end

		-- Faint penalty: a fainted loser drops coins — fewer when the
		-- winner's stud outleveled theirs, more when they lost to a weaker
		-- one. Forfeits/disconnects cost nothing (the winner gets no EXP for
		-- those either, so there's nothing to farm).
		if loserFainted then
			local loser = Players:GetPlayerByUserId(loserId)
			local loserData = loser and getData(loser)
			if loser and loserData then
				local loss = Combat.CalculateFaintPenalty(loserData.coins, duel.levels[loserId], duel.levels[winnerUserId])
				if loss > 0 then
					loserData.coins = (loserData.coins or 0) - loss
					StudEvents.UpdateCoins:FireClient(loser, loserData.coins)
					ServerRegistry.Call("SyncPlayerAttributes", loser, loserData)
					table.insert(endLog, duel.names[loserId] .. " dropped " .. loss .. " coins!")
				end
			end
		end
	end

	pushState(duel, {
		action = "ended",
		log = endLog,
		results = results,
	})
end

-- Turn timeout: auto-defend and pass the turn
local function armTurnTimer(duel)
	duel.turnToken = (duel.turnToken or 0) + 1
	local token = duel.turnToken
	task.delay(CONFIG.TURN_TIME, function()
		if duel.over or duel.turnToken ~= token then return end
		local userId = duel.turnUserId
		duel.defending[userId] = true
		duel.turnUserId = otherId(duel, userId)
		duel.turnCount += 1
		pushState(duel, { log = { duel.names[userId] .. " hesitated and braced!" } })
		armTurnTimer(duel)
	end)
end

local function startDuel(playerA, playerB)
	local studA, entryA, heldA = getBattleEntry(playerA)
	local studB, entryB, heldB = getBattleEntry(playerB)
	if not studA or not entryA then
		pvpState:FireClient(playerA, { action = "error", message = "You need an equipped stud to duel." })
		pvpState:FireClient(playerB, { action = "error", message = playerA.DisplayName .. " has no equipped stud." })
		return
	end
	if not studB or not entryB then
		pvpState:FireClient(playerB, { action = "error", message = "You need an equipped stud to duel." })
		pvpState:FireClient(playerA, { action = "error", message = playerB.DisplayName .. " has no equipped stud." })
		return
	end

	local idA, idB = playerA.UserId, playerB.UserId
	local duel = {
		ids = { idA, idB },
		names = { [idA] = playerA.DisplayName, [idB] = playerB.DisplayName },
		studs = { [idA] = studA, [idB] = studB },
		entries = { [idA] = entryA, [idB] = entryB },
		-- Passive effects (ability + held item) per side, resolved once.
		effects = { [idA] = Combat.GatherEffects(studA, heldA), [idB] = Combat.GatherEffects(studB, heldB) },
		levels = { [idA] = entryA.level or 1, [idB] = entryB.level or 1 },
		hp = {},
		maxHP = {},
		defending = {},
		status = {}, -- [userId] = { kind, turnsLeft } (burn/freeze/paralyze)
		turnCount = 1,
		over = false,
	}
	duel.maxHP[idA] = StudData.GetMaxHP(studA.rarity, duel.levels[idA])
	duel.maxHP[idB] = StudData.GetMaxHP(studB.rarity, duel.levels[idB])
	duel.hp[idA] = duel.maxHP[idA]
	duel.hp[idB] = duel.maxHP[idB]

	-- Faster stud goes first (speed stat x nature speed; coin flip on tie)
	local speedA = Combat.GetSpeed(studA, entryA.nature)
	local speedB = Combat.GetSpeed(studB, entryB.nature)
	if speedA > speedB then
		duel.turnUserId = idA
	elseif speedB > speedA then
		duel.turnUserId = idB
	else
		duel.turnUserId = math.random() < 0.5 and idA or idB
	end

	duels[idA] = duel
	duels[idB] = duel
	pushState(duel, { action = "started", log = { "Duel started! " .. duel.names[duel.turnUserId] .. " moves first." } })
	armTurnTimer(duel)
end

pvpAction.OnServerEvent:Connect(function(player, action, arg, arg2)
	if type(action) ~= "string" then return end

	if action == "challenge" then
		local targetUserId = tonumber(arg)
		if not targetUserId or targetUserId == player.UserId then return end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end
		if duels[player.UserId] or duels[targetUserId] then
			pvpState:FireClient(player, { action = "error", message = "That player is busy." })
			return
		end
		local existing = challenges[targetUserId]
		if existing and os.time() - existing.at < CONFIG.CHALLENGE_TIMEOUT then
			pvpState:FireClient(player, { action = "error", message = "That player already has a pending challenge." })
			return
		end
		challenges[targetUserId] = { from = player, at = os.time() }
		pvpState:FireClient(target, {
			action = "challenge",
			fromUserId = player.UserId,
			fromName = player.DisplayName,
		})
		pvpState:FireClient(player, { action = "challenge_sent", toName = target.DisplayName })
		return

	elseif action == "accept" then
		local challenge = challenges[player.UserId]
		challenges[player.UserId] = nil
		if not challenge or os.time() - challenge.at >= CONFIG.CHALLENGE_TIMEOUT then
			pvpState:FireClient(player, { action = "error", message = "Challenge expired." })
			return
		end
		local from = challenge.from
		if not from.Parent or duels[from.UserId] or duels[player.UserId] then
			pvpState:FireClient(player, { action = "error", message = "Duel no longer available." })
			return
		end
		startDuel(from, player)
		return

	elseif action == "decline" then
		local challenge = challenges[player.UserId]
		challenges[player.UserId] = nil
		if challenge and challenge.from.Parent then
			pvpState:FireClient(challenge.from, { action = "declined", byName = player.DisplayName })
		end
		return
	end

	-- ── In-duel actions ──────────────────────────────────────────────
	local duel = duels[player.UserId]
	if not duel or duel.over then return end
	local userId = player.UserId

	if action == "forfeit" then
		endDuel(duel, otherId(duel, userId), duel.names[userId] .. " forfeited!")
		return
	end

	if action ~= "move" or duel.turnUserId ~= userId then return end
	local moveType = arg
	local moveIndex = tonumber(arg2)
	local enemyId = otherId(duel, userId)
	local log = {}

	-- Status tick on the acting side (burn chip / freeze / paralysis).
	-- Burn can faint you on your own turn; a skip consumes the whole turn.
	local myStatus = duel.status[userId]
	if myStatus then
		local chip, skip, cured, kind = Combat.TickStatus(myStatus, duel.maxHP[userId])
		if cured then
			duel.status[userId] = nil
		end
		if chip > 0 then
			duel.hp[userId] = math.max(0, duel.hp[userId] - chip)
			table.insert(log, duel.studs[userId].name .. " is hurt by its burn! -" .. chip .. " HP")
		end
		if duel.hp[userId] <= 0 then
			endDuel(duel, enemyId, duel.studs[userId].name .. " fainted! " .. duel.names[enemyId] .. " wins!")
			return
		end
		if skip then
			table.insert(log, duel.studs[userId].name .. " " .. (Combat.STATUS_SKIP_TEXT[kind] or "can't move!"))
			duel.defending[userId] = false
			duel.turnCount += 1
			if duel.turnCount > CONFIG.MAX_TURNS then
				endDuel(duel, nil, "The duel ended in a draw!")
				return
			end
			duel.turnUserId = enemyId
			pushState(duel, { log = log })
			armTurnTimer(duel)
			return
		end
	end

	if moveType == "Defend" then
		duel.defending[userId] = true
		table.insert(log, duel.names[userId] .. "'s " .. duel.studs[userId].name .. " braces itself!")
	elseif moveType == "Attack" then
		duel.defending[userId] = false
		-- Level-gated move resolution (locked/invalid -> basic move)
		local movePower, moveName, accuracy, move = Combat.ResolveMove(duel.studs[userId], moveIndex, duel.levels[userId])
		local dmg, isCrit, eff, missed = Combat.CalculateDamage({
			attacker = duel.studs[userId],
			defender = duel.studs[enemyId],
			movePower = movePower,
			accuracy = accuracy,
			attackerLevel = duel.levels[userId],
			defenderLevel = duel.levels[enemyId],
			atkNature = duel.entries[userId].nature,
			defNature = duel.entries[enemyId].nature,
			isDefending = duel.defending[enemyId],
			atkEffects = duel.effects[userId],
			defEffects = duel.effects[enemyId],
			attackerHpFrac = duel.maxHP[userId] and duel.maxHP[userId] > 0
				and (duel.hp[userId] / duel.maxHP[userId]) or nil,
		})
		duel.hp[enemyId] = math.max(0, duel.hp[enemyId] - dmg)
		if missed then
			table.insert(log, duel.studs[userId].name .. " used " .. moveName .. "... it missed!")
		else
			local effText = ""
			if eff > 1.1 then effText = " Super effective!"
			elseif eff < 0.9 then effText = " Not very effective..."
			end
			table.insert(log, duel.studs[userId].name .. " used " .. moveName .. "! -" .. dmg .. " HP" .. effText .. (isCrit and " Critical!" or ""))
			-- Status proc on a landed hit (mid-tier Fire/Ice/Electric moves)
			local newStatus = Combat.RollMoveStatus(move, duel.status[enemyId], duel.effects[userId], duel.effects[enemyId])
			if newStatus then
				duel.status[enemyId] = newStatus
				table.insert(log, duel.studs[enemyId].name .. " " .. Combat.STATUS_INFLICT_TEXT[newStatus.kind])
			end
		end
	else
		return
	end

	-- Defend only shields until your next turn starts
	duel.defending[enemyId] = duel.defending[enemyId] or false

	if duel.hp[enemyId] <= 0 then
		endDuel(duel, userId, duel.studs[enemyId].name .. " fainted! " .. duel.names[userId] .. " wins!")
		return
	end

	duel.turnCount += 1
	if duel.turnCount > CONFIG.MAX_TURNS then
		endDuel(duel, nil, "The duel ended in a draw!")
		return
	end

	duel.turnUserId = enemyId
	pushState(duel, { log = log })
	armTurnTimer(duel)
end)

Players.PlayerRemoving:Connect(function(player)
	challenges[player.UserId] = nil
	local duel = duels[player.UserId]
	if duel and not duel.over then
		endDuel(duel, otherId(duel, player.UserId), player.DisplayName .. " left the game!")
	end
end)

print("[PvPSystem] Initialized")
