-- ReferralSystem: "Bring Them Home" — Roblox's official Friend Referral System
-- wired into Studs' economy.
--
-- Research (Evervault studs-growth charter, Q3):
--   - The referral system feeds the algorithm's scored "intentional co-play"
--     signal, and Roblox's own data says co-play sessions run ~1.9x longer.
--   - Policy/anti-abuse: reward on a COMPLETED MILESTONE, not a join — both
--     sides are paid only when the invitee finishes their first catch, so
--     multi-account join farming earns nothing.
--
-- Flow:
--   1. Invitee joins via a friend's invite -> GetJoinData().ReferredByPlayerId.
--   2. The inviter id is attached to the invitee's FRESH save (referredBy).
--   3. On the invitee's first catch (SaveManager fires "OnFirstCatch"), the
--      invitee is paid immediately; the inviter is paid directly if they're in
--      this server, otherwise via a DataStore mailbox claimed on next login.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents", 10)
if not StudEvents then return end

local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local GrowthConfig = require(ReplicatedStorage:WaitForChild("GrowthConfig"))

local REWARD = GrowthConfig.Referral

-- Mailbox: [inviterUserId] -> pending referral-completion count. GetDataStore
-- itself doesn't error in Studio without API access, so like SaveManager the
-- real availability check is the first read/write pcall; memoryMailbox is the
-- Studio/offline fallback.
local mailboxStore = nil
pcall(function()
	mailboxStore = DataStoreService:GetDataStore("ReferralMailbox")
end)
local memoryMailbox = {} -- [userId] = count (Studio fallback)

-- [userId] = inviter id captured from join data before the save is picked
local pendingReferrer = {}

local function notify(player, title, text)
	local announceEvent = StudEvents:FindFirstChild("GameAnnouncement")
	if announceEvent then
		announceEvent:FireClient(player, { type = "referral", title = title, text = text })
	end
end

local function grantCoins(player, data, amount)
	data.coins = (data.coins or 0) + amount
	StudEvents.UpdateCoins:FireClient(player, data.coins)
	ServerRegistry.Call("SyncPlayerAttributes", player, data)
end

-- Add one completed referral to an offline inviter's mailbox
local function enqueueInviterCredit(inviterUserId)
	local wrote = false
	if mailboxStore then
		local ok = pcall(function()
			mailboxStore:UpdateAsync(tostring(inviterUserId), function(count)
				return (count or 0) + 1
			end)
		end)
		wrote = ok
	end
	if not wrote then
		memoryMailbox[inviterUserId] = (memoryMailbox[inviterUserId] or 0) + 1
	end
end

-- Claim any mailbox credits for a player whose save data is now live
local function claimInviterCredits(player, data)
	local count = 0
	if mailboxStore then
		pcall(function()
			mailboxStore:UpdateAsync(tostring(player.UserId), function(pending)
				count = pending or 0
				return 0
			end)
		end)
	end
	count += memoryMailbox[player.UserId] or 0
	memoryMailbox[player.UserId] = nil

	if count > 0 then
		grantCoins(player, data, count * REWARD.inviterCoins)
		notify(player, "They made it home!",
			count .. (count == 1 and " friend you invited" or " friends you invited")
				.. " caught their first stud — +" .. (count * REWARD.inviterCoins) .. " coins!")
		print("[Referral] " .. player.Name .. " claimed " .. count .. " referral credit(s)")
	end
end

-- ─── FIRST-CATCH GATE (fired by SaveManager's GrantCatch) ──────────────

ServerRegistry.Register("OnFirstCatch", function(player, data)
	if not REWARD.enabled then return end
	if not data.referredBy or data.referralRewarded then return end
	data.referralRewarded = true

	-- Invitee side
	grantCoins(player, data, REWARD.inviteeCoins)
	notify(player, "Welcome home!",
		"You were invited by a friend — +" .. REWARD.inviteeCoins .. " coins!")

	-- Inviter side: pay directly if they're here with live data, else mailbox
	local inviter = Players:GetPlayerByUserId(data.referredBy)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local inviterInfo = inviter and activePlayers and activePlayers[inviter.UserId]
	if inviter and inviterInfo and inviterInfo.data then
		grantCoins(inviter, inviterInfo.data, REWARD.inviterCoins)
		notify(inviter, "They made it home!",
			player.Name .. " caught their first stud — +" .. REWARD.inviterCoins .. " coins!")
	else
		task.spawn(enqueueInviterCredit, data.referredBy)
	end

	-- The rewarded flag must survive a crash (double-pay guard), same policy
	-- as trades: persist immediately instead of waiting for autosave
	local playerInfo = activePlayers and activePlayers[player.UserId]
	if playerInfo and playerInfo.activeSlot then
		task.spawn(function()
			ServerRegistry.Call("PersistPlayer", player.UserId, playerInfo.activeSlot, data, player)
		end)
	end

	print("[Referral] Completed: " .. player.Name .. " (invited by " .. tostring(data.referredBy) .. ")")
end)

-- ─── JOIN CAPTURE + DATA-LOAD ATTACH ───────────────────────────────────

local function onPlayerAdded(player)
	local ok, joinData = pcall(function()
		return player:GetJoinData()
	end)
	local inviterId = ok and joinData and joinData.ReferredByPlayerId or nil
	if inviterId and inviterId > 0 and inviterId ~= player.UserId then
		pendingReferrer[player.UserId] = inviterId
		print("[Referral] " .. player.Name .. " joined via referral from " .. inviterId)
	end

	-- Save data only exists after the player picks New/Load on the menu
	-- (same wait pattern as DailyReward)
	task.spawn(function()
		local playerInfo
		while player.Parent do
			local activePlayers = ServerRegistry.Get("ActivePlayers")
			playerInfo = activePlayers and activePlayers[player.UserId]
			if playerInfo and playerInfo.data then break end
			task.wait(2)
		end
		if not player.Parent or not playerInfo or not playerInfo.data then return end
		local data = playerInfo.data

		-- Attach the inviter to a FRESH save only — an established save
		-- rejoining through an invite link is not a new referred player
		local inviterUserId = pendingReferrer[player.UserId]
		if inviterUserId
			and data.referredBy == nil
			and not data.referralRewarded
			and (data.totalCaught or 0) == 0
		then
			data.referredBy = inviterUserId
		end

		claimInviterCredits(player, data)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	pendingReferrer[player.UserId] = nil
end)

print("[ReferralSystem] Initialized (reward gated on invitee's first catch)")
