-- TradeSystem: player-to-player stud trading with a two-step confirm.
--
-- Flow: request -> accept -> both sides add/remove offers -> both LOCK
-- (ready) -> both CONFIRM -> SaveManager's ExecuteTrade swaps the copies
-- atomically and persists both saves.
--
-- Anti-scam rules enforced here:
--  * any offer change clears BOTH locks and confirms
--  * confirm is only accepted while both sides are locked
--  * offers are entry snapshots validated against the live save at add time
--    AND revalidated inside ExecuteTrade at swap time (nothing moves if
--    anything changed in between)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local MAX_OFFER = 4
local INVITE_TIMEOUT = 45

local tradeAction = StudEvents:FindFirstChild("TradeAction")
if not tradeAction then
	tradeAction = Instance.new("RemoteEvent")
	tradeAction.Name = "TradeAction"
	tradeAction.Parent = StudEvents
end
local tradeState = StudEvents:FindFirstChild("TradeState")
if not tradeState then
	tradeState = Instance.new("RemoteEvent")
	tradeState.Name = "TradeState"
	tradeState.Parent = StudEvents
end

local sessions = {} -- [userId] = shared session table
local invites = {} -- [targetUserId] = { from = player, at = os.time() }

local function getData(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	return playerInfo and playerInfo.data or nil
end

local function snapshotMatchesEntry(entry, snapshot)
	return entry.id == snapshot.id
		and (entry.caughtAt or 0) == (snapshot.caughtAt or 0)
		and (entry.level or 1) == (snapshot.level or 1)
		and (entry.isShiny or false) == (snapshot.isShiny or false)
		and (entry.nature or "hardy") == (snapshot.nature or "hardy")
end

-- Cleaned copy of a client-sent snapshot (never trust extra fields)
local function sanitizeSnapshot(raw)
	if type(raw) ~= "table" or type(raw.id) ~= "string" then return nil end
	return {
		id = raw.id,
		caughtAt = tonumber(raw.caughtAt) or 0,
		level = tonumber(raw.level) or 1,
		isShiny = raw.isShiny == true,
		nature = type(raw.nature) == "string" and raw.nature or "hardy",
	}
end

-- Does the player own enough matching copies to cover this offer + one more?
local function ownsForOffer(player, offer, snapshot)
	local data = getData(player)
	if not data then return false end
	local needed = 1
	for _, offered in ipairs(offer) do
		if snapshotMatchesEntry(offered, snapshot) then
			needed += 1
		end
	end
	local owned = 0
	for _, entry in ipairs(data.caughtStuds) do
		if snapshotMatchesEntry(entry, snapshot) then
			owned += 1
			if owned >= needed then return true end
		end
	end
	return false
end

-- Display-friendly copy of an offer list
local function describeOffer(offer)
	local out = {}
	for _, snapshot in ipairs(offer) do
		local stud = StudData.GetStudById(snapshot.id)
		table.insert(out, {
			id = snapshot.id,
			name = stud and stud.name or snapshot.id,
			studType = stud and stud.studType or "?",
			rarity = stud and stud.rarity or "Common",
			level = snapshot.level,
			isShiny = snapshot.isShiny,
			nature = snapshot.nature,
		})
	end
	return out
end

local function otherPlayer(session, player)
	return session.a == player and session.b or session.a
end

local function pushState(session)
	for _, plr in ipairs({ session.a, session.b }) do
		local partner = otherPlayer(session, plr)
		tradeState:FireClient(plr, {
			action = "state",
			partnerName = partner.DisplayName,
			myOffer = describeOffer(session.offers[plr.UserId]),
			theirOffer = describeOffer(session.offers[partner.UserId]),
			myLocked = session.locked[plr.UserId] or false,
			theirLocked = session.locked[partner.UserId] or false,
			myConfirmed = session.confirmed[plr.UserId] or false,
			theirConfirmed = session.confirmed[partner.UserId] or false,
		})
	end
end

local function endSession(session, reason)
	for _, plr in ipairs({ session.a, session.b }) do
		if sessions[plr.UserId] == session then
			sessions[plr.UserId] = nil
		end
		tradeState:FireClient(plr, { action = "ended", reason = reason })
	end
end

local function resetLocks(session)
	session.locked = {}
	session.confirmed = {}
end

tradeAction.OnServerEvent:Connect(function(player, action, arg)
	if type(action) ~= "string" then return end

	-- ── Invites ──────────────────────────────────────────────────────
	if action == "request" then
		local targetUserId = tonumber(arg)
		if not targetUserId or targetUserId == player.UserId then return end
		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end
		if sessions[player.UserId] or sessions[targetUserId] then
			tradeState:FireClient(player, { action = "error", message = "That player is busy." })
			return
		end
		if not getData(player) or not getData(target) then
			tradeState:FireClient(player, { action = "error", message = "Both players need a loaded save." })
			return
		end
		local existing = invites[targetUserId]
		if existing and os.time() - existing.at < INVITE_TIMEOUT then
			tradeState:FireClient(player, { action = "error", message = "That player already has a pending invite." })
			return
		end
		invites[targetUserId] = { from = player, at = os.time() }
		tradeState:FireClient(target, {
			action = "invite",
			fromUserId = player.UserId,
			fromName = player.DisplayName,
		})
		tradeState:FireClient(player, { action = "invite_sent", toName = target.DisplayName })
		return

	elseif action == "accept" then
		local invite = invites[player.UserId]
		invites[player.UserId] = nil
		if not invite or os.time() - invite.at >= INVITE_TIMEOUT then
			tradeState:FireClient(player, { action = "error", message = "Invite expired." })
			return
		end
		local from = invite.from
		if not from.Parent or sessions[from.UserId] or sessions[player.UserId] then
			tradeState:FireClient(player, { action = "error", message = "Trade no longer available." })
			return
		end
		local session = {
			a = from,
			b = player,
			offers = { [from.UserId] = {}, [player.UserId] = {} },
			locked = {},
			confirmed = {},
			executing = false,
		}
		sessions[from.UserId] = session
		sessions[player.UserId] = session
		for _, plr in ipairs({ from, player }) do
			tradeState:FireClient(plr, {
				action = "started",
				partnerName = otherPlayer(session, plr).DisplayName,
			})
		end
		pushState(session)
		return

	elseif action == "decline" then
		local invite = invites[player.UserId]
		invites[player.UserId] = nil
		if invite and invite.from.Parent then
			tradeState:FireClient(invite.from, { action = "declined", byName = player.DisplayName })
		end
		return
	end

	-- ── In-session actions ───────────────────────────────────────────
	local session = sessions[player.UserId]
	if not session or session.executing then return end

	if action == "add" then
		local snapshot = sanitizeSnapshot(arg)
		if not snapshot then return end
		local offer = session.offers[player.UserId]
		if #offer >= MAX_OFFER then
			tradeState:FireClient(player, { action = "error", message = "Max " .. MAX_OFFER .. " studs per trade." })
			return
		end
		if not ownsForOffer(player, offer, snapshot) then
			tradeState:FireClient(player, { action = "error", message = "You don't own that stud." })
			return
		end
		table.insert(offer, snapshot)
		resetLocks(session)
		pushState(session)

	elseif action == "remove" then
		local idx = tonumber(arg)
		local offer = session.offers[player.UserId]
		if idx and offer[idx] then
			table.remove(offer, idx)
			resetLocks(session)
			pushState(session)
		end

	elseif action == "lock" then
		session.locked[player.UserId] = true
		pushState(session)

	elseif action == "unlock" then
		resetLocks(session)
		pushState(session)

	elseif action == "confirm" then
		local partner = otherPlayer(session, player)
		if not (session.locked[player.UserId] and session.locked[partner.UserId]) then
			return -- confirm only valid once both sides are locked
		end
		session.confirmed[player.UserId] = true
		pushState(session)

		if session.confirmed[partner.UserId] then
			session.executing = true
			local ok, reason = ServerRegistry.Call(
				"ExecuteTrade",
				session.a, session.b,
				session.offers[session.a.UserId],
				session.offers[session.b.UserId]
			)
			if ok then
				endSession(session, "completed")
				print("[TradeSystem] Trade completed: " .. session.a.Name .. " <-> " .. session.b.Name)
			else
				session.executing = false
				resetLocks(session)
				pushState(session)
				for _, plr in ipairs({ session.a, session.b }) do
					tradeState:FireClient(plr, {
						action = "error",
						message = "Trade failed (" .. tostring(reason) .. "). Offers reset.",
					})
				end
			end
		end

	elseif action == "cancel" then
		endSession(session, "cancelled")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	invites[player.UserId] = nil
	local session = sessions[player.UserId]
	if session then
		endSession(session, "partner_left")
	end
end)

print("[TradeSystem] Initialized")
