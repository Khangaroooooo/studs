-- ShopSystem: Handles purchasable items from the Shop
-- Items give temporary buffs tracked via player attributes.
-- Changes:
--  * _G.ActivePlayers → ServerRegistry (no _G, no load-order fragility)
--  * Buff timers are token-based: re-buying an active buff now EXTENDS it
--    instead of the first purchase's task.delay killing it early
--  * Table-driven effects instead of an if/elseif chain

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local RateLimiter = require(ReplicatedStorage:WaitForChild("RateLimiter"))

-- Purchases are server-priced/validated already; this just drops spam.
local buyLimiter = RateLimiter.new(0.4)

-- Purchase results go over a RemoteEvent. The old pattern (set a BuyResult
-- attribute, clear it 0.1s later) silently dropped feedback when the same
-- item was bought twice in a row — same value twice = no changed signal —
-- and raced its own delayed clears on rapid purchases.
local buyResultEvent = StudEvents:FindFirstChild("BuyResult")
if not buyResultEvent then
	buyResultEvent = Instance.new("RemoteEvent")
	buyResultEvent.Name = "BuyResult"
	buyResultEvent.Parent = StudEvents
end

-- Item definitions (attr = player attribute set while the buff is active;
-- kind = "consumable" stacks into data.items instead)
local ITEMS = {
	catch_boost = { price = 50,  duration = 300, attr = "CatchBoost", result = "catch_boost" },
	lucky_charm = { price = 100, duration = 300, attr = "LuckyCharm", result = "lucky_charm" },
	heal_potion = { price = 20,  duration = 0,   result = "healed" },
	stud_lure   = { price = 75,  duration = 180, attr = "StudLure",   result = "stud_lure" },
}
-- Catch balls (consumable coin sink): definitions live in StudData so the
-- shop UI and EncounterSystem (which consumes them) share one source
for _, ball in ipairs(StudData.CatchBalls) do
	ITEMS[ball.id] = { price = ball.price, kind = "consumable", result = ball.id }
end

-- ─── DAILY FEATURED STUD ────────────────────────────────────────────────
-- One rotating species per UTC day, sold at a steep markup (the big coin
-- sink for hoarders). Deterministic pick — same stud on every server.
-- 37 is coprime with the dex size, so the rotation visits every species.
local FEATURED_PRICES = { Common = 150, Uncommon = 400, Rare = 1200, Legendary = 4000 }
local FEATURED_LEVELS = { Common = 5, Uncommon = 10, Rare = 15, Legendary = 20 }

local function getFeaturedStud()
	local day = math.floor(os.time() / 86400)
	local idx = (day * 37) % #StudData.Studs + 1
	return StudData.Studs[idx]
end

-- Client fetches shop state: featured stud of the day + owned consumables
local shopInfoFunc = StudEvents:FindFirstChild("ShopInfo")
if not shopInfoFunc then
	shopInfoFunc = Instance.new("RemoteFunction")
	shopInfoFunc.Name = "ShopInfo"
	shopInfoFunc.Parent = StudEvents
end

shopInfoFunc.OnServerInvoke = function(player)
	local activePlayersData = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayersData and activePlayersData[player.UserId]
	local data = playerInfo and playerInfo.data
	local featured = getFeaturedStud()
	local currentWorld = player:GetAttribute("CurrentWorld") or "Studville"
	return {
		featured = {
			id = featured.id,
			name = featured.name,
			studType = featured.studType,
			rarity = featured.rarity,
			description = featured.description,
			price = FEATURED_PRICES[featured.rarity] or 150,
			level = FEATURED_LEVELS[featured.rarity] or 5,
			owned = data and data.speciesCounts and data.speciesCounts[featured.id] or 0,
		},
		items = data and data.items or {},
		-- Held items on sale at THIS island (universal + local exclusives), plus
		-- what the player already has equipped, so the shop can show "equipped".
		currentWorld = currentWorld,
		currentWorldName = StudData.GetWorldDisplayName(currentWorld),
		heldItemsForSale = StudData.GetShopHeldItems(currentWorld),
		heldItemsEquipped = data and data.heldItems or {},
	}
end

-- [userId] = { [attr] = token } — a delayed clear only fires if its token
-- is still current, so overlapping purchases can't cancel each other.
local buffTokens = {}

local function applyTimedBuff(player, attr, duration)
	local userTokens = buffTokens[player.UserId]
	if not userTokens then
		userTokens = {}
		buffTokens[player.UserId] = userTokens
	end
	local token = (userTokens[attr] or 0) + 1
	userTokens[attr] = token
	player:SetAttribute(attr, true)
	task.delay(duration, function()
		local t = buffTokens[player.UserId]
		if player.Parent and t and t[attr] == token then
			player:SetAttribute(attr, nil)
		end
	end)
end

StudEvents.BuyItem.OnServerEvent:Connect(function(player, itemId)
	if type(itemId) ~= "string" then return end
	if not buyLimiter:allow(player) then return end

	local activePlayersData = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayersData and activePlayersData[player.UserId]
	if not playerInfo or not playerInfo.data then return end
	local coins = playerInfo.data.coins or 0

	-- Featured stud of the day (server-priced; the client never sends a price)
	if itemId == "featured_stud" then
		local featured = getFeaturedStud()
		local price = FEATURED_PRICES[featured.rarity] or 150
		if coins < price then
			buyResultEvent:FireClient(player, "insufficient", itemId)
			return
		end
		playerInfo.data.coins = coins - price
		-- GrantCatch with purchase=true: adds to the collection (dupes still
		-- pay evo points) but skips catch rewards and quest/streak hooks
		local grant = ServerRegistry.Call("GrantCatch", player, featured.id, {
			purchase = true,
			level = FEATURED_LEVELS[featured.rarity] or 5,
		})
		if not grant then
			playerInfo.data.coins = coins -- refund on failure
		end
		StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
		player:SetAttribute("Coins", playerInfo.data.coins)
		buyResultEvent:FireClient(player, grant and "featured_stud" or "failed", itemId)
		playerInfo.data.lastSaved = os.time()
		print("[ShopSystem] Player", player.Name, "bought featured stud", featured.id, "for", price, "coins")
		return
	end

	-- Held items (permanent equips): island-gated, added to the unequipped pool
	-- (data.items). Equipping onto a species happens via SaveManager.EquipHeldItem.
	local heldDef = StudData.GetHeldItem(itemId)
	if heldDef then
		local currentWorld = player:GetAttribute("CurrentWorld") or "Studville"
		if not StudData.IsHeldItemSoldAt(itemId, currentWorld) then
			buyResultEvent:FireClient(player, "not_here", itemId)
			return
		end
		local price = heldDef.price or 0
		if coins < price then
			buyResultEvent:FireClient(player, "insufficient", itemId)
			return
		end
		playerInfo.data.coins = coins - price
		playerInfo.data.items = playerInfo.data.items or {}
		playerInfo.data.items[itemId] = (playerInfo.data.items[itemId] or 0) + 1
		StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
		player:SetAttribute("Coins", playerInfo.data.coins)
		buyResultEvent:FireClient(player, "held_item", itemId)
		playerInfo.data.lastSaved = os.time()
		print("[ShopSystem] Player", player.Name, "bought held item", itemId, "for", price, "coins")
		return
	end

	local item = ITEMS[itemId]
	if not item then return end

	if coins < item.price then
		buyResultEvent:FireClient(player, "insufficient", itemId)
		return
	end

	-- Deduct coins
	playerInfo.data.coins = coins - item.price
	StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
	player:SetAttribute("Coins", playerInfo.data.coins)

	-- Apply effect
	if item.kind == "consumable" then
		playerInfo.data.items = playerInfo.data.items or {}
		playerInfo.data.items[itemId] = (playerInfo.data.items[itemId] or 0) + 1
	elseif itemId == "heal_potion" then
		player:SetAttribute("LastHealTime", os.time())
	elseif item.attr then
		applyTimedBuff(player, item.attr, item.duration)
	end
	buyResultEvent:FireClient(player, item.result, itemId)

	playerInfo.data.lastSaved = os.time()
	print("[ShopSystem] Player", player.Name, "purchased", itemId, "for", item.price, "coins")
end)

Players.PlayerRemoving:Connect(function(player)
	buffTokens[player.UserId] = nil
end)

print("[ShopSystem] Initialized")
