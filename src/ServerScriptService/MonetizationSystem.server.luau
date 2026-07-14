-- MonetizationSystem: gamepasses + developer products.
--
-- SETUP: IDs live in ReplicatedStorage/MonetizationConfig — paste real IDs
-- there. Everything is a no-op while an ID is 0, so this ships safely first.
-- Design rule: convenience & cosmetics only (see MonetizationConfig).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local Config = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))
local RateLimiter = require(ReplicatedStorage:WaitForChild("RateLimiter"))

local GAMEPASSES = Config.Gamepasses
local PRODUCTS = Config.Products

-- Drop rapid repeat prompts (Roblox also debounces its own purchase UI).
local promptLimiter = RateLimiter.new(1.0)

-- Remote so client UIs (shop, profile) can prompt purchases
local promptEvent = StudEvents:FindFirstChild("PromptPurchase")
if not promptEvent then
	promptEvent = Instance.new("RemoteEvent")
	promptEvent.Name = "PromptPurchase"
	promptEvent.Parent = StudEvents
end

promptEvent.OnServerEvent:Connect(function(player, kind, id)
	if type(id) ~= "number" or id == 0 then return end
	if not promptLimiter:allow(player) then return end
	if kind == "gamepass" then
		-- Only prompt for passes we actually sell
		for _, pass in ipairs(GAMEPASSES) do
			if pass.id == id then
				MarketplaceService:PromptGamePassPurchase(player, id)
				return
			end
		end
	elseif kind == "product" then
		if PRODUCTS[id] then
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end
end)

-- ─── GAMEPASS OWNERSHIP -> ATTRIBUTES ──────────────────────────────────

local function applyGamepasses(player)
	for _, pass in ipairs(GAMEPASSES) do
		if pass.id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				if ok and owns then
					player:SetAttribute(pass.attr, pass.value)
				end
			end)
		end
	end
end

Players.PlayerAdded:Connect(applyGamepasses)
for _, player in Players:GetPlayers() do
	applyGamepasses(player)
end

-- Apply immediately after an in-game purchase (no rejoin needed)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
	if not wasPurchased then return end
	for _, pass in ipairs(GAMEPASSES) do
		if pass.id == gamePassId then
			player:SetAttribute(pass.attr, pass.value)
		end
	end
end)

-- ─── DEVELOPER PRODUCTS (coin packs) ───────────────────────────────────
-- NOTE: ProcessReceipt is game-wide and can only be set ONCE — keep all
-- product handling in this script.

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local coins = PRODUCTS[receiptInfo.ProductId]
	if not coins then
		-- Unknown product: don't consume the receipt
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then
		-- Save not loaded yet (player on the menu) — retry later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Idempotency: Roblox re-calls ProcessReceipt until we return
	-- PurchaseGranted, and a receipt can be retried on another server/session
	-- (e.g. this server crashed after persisting the grant but before the
	-- confirmation reached Roblox). Never grant the same PurchaseId twice.
	local granted = playerInfo.data.grantedReceipts
	if granted and granted[receiptInfo.PurchaseId] then
		-- Already granted and persisted; the coins are in the loaded save.
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Apply the grant in memory and record the receipt id...
	local prevCoins = playerInfo.data.coins or 0
	playerInfo.data.coins = prevCoins + coins
	playerInfo.data.grantedReceipts = playerInfo.data.grantedReceipts or {}
	playerInfo.data.grantedReceipts[receiptInfo.PurchaseId] = true

	-- ...then PERSIST DURABLY before confirming. Real money must not live only
	-- in RAM until the next autosave (~60s): a crash or the player leaving in
	-- that window would charge the player and lose the coins. If the write
	-- fails, roll the grant back and return NotProcessedYet so Roblox retries
	-- later — we never confirm a receipt we haven't durably saved.
	local saved = ServerRegistry.Call(
		"PersistPlayer",
		player.UserId,
		playerInfo.activeSlot,
		playerInfo.data,
		player
	)
	if not saved then
		playerInfo.data.coins = prevCoins
		playerInfo.data.grantedReceipts[receiptInfo.PurchaseId] = nil
		warn("[Monetization] Durable save FAILED for " .. player.Name .. "'s purchase — deferring; Roblox will retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Durable now — safe to reflect to the client and confirm the receipt.
	StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
	ServerRegistry.Call("SyncPlayerAttributes", player, playerInfo.data)
	print("[Monetization] Granted " .. coins .. " coins to " .. player.Name)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

print("[MonetizationSystem] Initialized (configure GAMEPASSES/PRODUCTS ids to enable)")
