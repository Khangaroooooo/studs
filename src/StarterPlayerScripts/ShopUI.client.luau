-- ShopUI: Interactive shop with Sell (duplicate studs) and Buy (items) tabs
-- Triggered by interacting with the Shop building's ProximityPrompt

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

-- Shop items available for purchase. Catch balls come from StudData (shared
-- with the server, which consumes them at CatchStart); `consumable` rows
-- show an owned count from ShopInfo.
local SHOP_ITEMS = {
	{id = "catch_boost", name = "Catch Boost", desc = "Easier catches for 5 min", price = 50, icon = "🎯"},
	{id = "lucky_charm", name = "Lucky Charm", desc = "More rare encounters for 5 min", price = 100, icon = "🍀"},
	{id = "heal_potion", name = "Heal Potion", desc = "Instantly reset encounter cooldown", price = 20, icon = "🧪"},
	{id = "stud_lure", name = "Stud Lure", desc = "Higher encounter rate for 3 min", price = 75, icon = "🧲"},
}
local BALL_ICONS = { super_ball = "🥎", mega_ball = "🌟" }
for _, ball in ipairs(StudData.CatchBalls) do
	table.insert(SHOP_ITEMS, {
		id = ball.id, name = ball.name, desc = ball.desc, price = ball.price,
		icon = BALL_ICONS[ball.id] or "⚪", consumable = true,
	})
end

-- Create the Shop ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShopUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- IMPORTANT: no IgnoreGuiInset here. The HUD rail (GameHUD coins pill,
-- Settings gear, Leaderboard) lays out in inset space; this gui ignoring
-- the ~58px topbar inset is what made the Shop toggle overlap the
-- Leaderboard button even though their Y coordinates looked staggered.
screenGui.IgnoreGuiInset = false

-- Main frame
local frame = Instance.new("Frame")
frame.Name = "ShopFrame"
frame.Size = UDim2.new(0.6, 0, 0.7, 0)
frame.Position = UDim2.new(0.2, 0, 0.15, 0)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
frame.BorderSizePixel = 0
frame.Visible = false
frame.ClipsDescendants = true
frame.Parent = screenGui



local frameStroke = Instance.new("UIStroke")
frameStroke.Color = Color3.fromRGB(255, 200, 50)
frameStroke.Thickness = 2
frameStroke.Parent = frame

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 50)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
title.BorderSizePixel = 0
title.Text = "STUD SHOP"
title.TextColor3 = Color3.fromRGB(255, 200, 50)
title.TextScaled = true
title.Font = Enum.Font.GothamBold
title.Parent = frame



local titleFix = Instance.new("Frame")
titleFix.Size = UDim2.new(1, 0, 0, 12)
titleFix.Position = UDim2.new(0, 0, 1, -12)
titleFix.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
titleFix.BorderSizePixel = 0
titleFix.Parent = title

-- Coins display
local coinsLabel = Instance.new("TextLabel")
coinsLabel.Name = "CoinsLabel"
coinsLabel.Size = UDim2.new(0.3, 0, 0, 30)
coinsLabel.Position = UDim2.new(0.7, 0, 0, 10)
coinsLabel.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
coinsLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
coinsLabel.Text = "Coins: 0"
coinsLabel.Font = Enum.Font.GothamBold
coinsLabel.TextSize = 16
coinsLabel.Parent = frame



-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 40, 0, 40)
closeBtn.Position = UDim2.new(1, -50, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 20
closeBtn.BorderSizePixel = 0
closeBtn.Parent = frame



-- Tab buttons
local tabFrame = Instance.new("Frame")
tabFrame.Size = UDim2.new(1, -20, 0, 36)
tabFrame.Position = UDim2.new(0, 10, 0, 55)
tabFrame.BackgroundTransparency = 1
tabFrame.Parent = frame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabFrame

local currentTab = "Sell"
local tabButtons = {}

for i, tabName in ipairs({"Sell", "Buy"}) do
	local btn = Instance.new("TextButton")
	btn.Name = tabName .. "Tab"
	btn.Size = UDim2.new(0.47, 0, 1, 0)
	btn.BackgroundColor3 = (tabName == "Sell") and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(50, 50, 65)
	btn.TextColor3 = (tabName == "Sell") and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(200, 200, 210)
	btn.TextSize = 14
	btn.Font = Enum.Font.GothamBold
	btn.Text = tabName
	btn.BorderSizePixel = 0
	btn.LayoutOrder = i
	btn.Parent = tabFrame



	tabButtons[tabName] = btn

	btn.MouseButton1Click:Connect(function()
		currentTab = tabName
		for name, b in pairs(tabButtons) do
			b.BackgroundColor3 = (name == tabName) and Color3.fromRGB(255, 200, 50) or Color3.fromRGB(50, 50, 65)
			b.TextColor3 = (name == tabName) and Color3.fromRGB(30, 30, 40) or Color3.fromRGB(200, 200, 210)
		end
		refreshContent()
	end)
end

-- Scroll frame for content
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "ContentScroll"
scrollFrame.Size = UDim2.new(1, -20, 1, -140)
scrollFrame.Position = UDim2.new(0, 10, 0, 95)
scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 200, 50)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = frame



local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent = scrollFrame

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop = UDim.new(0, 4)
scrollPadding.PaddingBottom = UDim.new(0, 4)
scrollPadding.Parent = scrollFrame

-- Toggle button on HUD — sits in the top-right rail below the quest,
-- settings, and leaderboard icons (60/112/164), so the shop is always one
-- tap away instead of requiring a walk to the shop building.
local toggleBtn = Instance.new("TextButton")
toggleBtn.Name = "ShopToggle"
toggleBtn.Size = UDim2.new(0, 44, 0, 44)
toggleBtn.Position = UDim2.new(1, -56, 0, 216)
toggleBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
toggleBtn.BackgroundTransparency = 0.25
toggleBtn.TextColor3 = Color3.fromRGB(255, 200, 50)
toggleBtn.TextSize = 22
toggleBtn.Text = "🛒"
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.Parent = screenGui

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = toggleBtn

local toggleStroke = Instance.new("UIStroke")
toggleStroke.Color = Color3.fromRGB(80, 80, 100)
toggleStroke.Thickness = 1.5
toggleStroke.Parent = toggleBtn

screenGui.Parent = player:WaitForChild("PlayerGui")

-- State
local isOpen = false
local playerCoins = 0

-- Sell values by rarity

-- Update coins display
local function updateCoins(coins)
	playerCoins = coins
	coinsLabel.Text = "Coins: " .. tostring(coins)
end

-- Clear scroll content
local function clearContent()
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- Populate the SELL tab
local function populateSell()
	clearContent()

	-- Get collection from server
	local collection = StudEvents.RequestCollection:InvokeServer()

	-- Count duplicates and track the lowest-level copy per species — the
	-- server always sells that copy, so quote ITS price (incl. shiny x5)
	local studCounts = {}
	local lowestCopy = {}
	for _, caught in ipairs(collection) do
		studCounts[caught.id] = (studCounts[caught.id] or 0) + 1
		local prev = lowestCopy[caught.id]
		if not prev or (caught.level or 1) < (prev.level or 1) then
			lowestCopy[caught.id] = caught
		end
	end

	-- Create entries for owned studs
	local order = 0
	for _, stud in ipairs(StudData.Studs) do
		local count = studCounts[stud.id] or 0
		if count >= 1 then
			order += 1
			local copy = lowestCopy[stud.id]
			local sellValue = StudData.GetSellValue(stud.id, copy and copy.level or 1)
			if copy and copy.isShiny then
				sellValue = sellValue * 5
			end

			local entry = Instance.new("Frame")
			entry.Name = stud.id
			entry.Size = UDim2.new(1, 0, 0, 50)
			entry.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
			entry.LayoutOrder = order
			entry.Parent = scrollFrame



			-- Stud color indicator
			local colorBar = Instance.new("Frame")
			colorBar.Size = UDim2.new(0, 6, 1, -8)
			colorBar.Position = UDim2.new(0, 4, 0, 4)
			colorBar.BackgroundColor3 = StudData.GetStudColor(stud)
			colorBar.BorderSizePixel = 0
			colorBar.Parent = entry

			-- Stud name
			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.4, 0, 1, 0)
			nameLabel.Position = UDim2.new(0, 16, 0, 0)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = stud.name
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextSize = 14
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = entry

			-- Count label
			local countLabel = Instance.new("TextLabel")
			countLabel.Size = UDim2.new(0.15, 0, 1, 0)
			countLabel.Position = UDim2.new(0.4, 0, 0, 0)
			countLabel.BackgroundTransparency = 1
			countLabel.Text = "x" .. count
			countLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
			countLabel.TextSize = 14
			countLabel.Font = Enum.Font.Gotham
			countLabel.Parent = entry

			-- Sell button
			local sellBtn = Instance.new("TextButton")
			sellBtn.Size = UDim2.new(0.2, -10, 1, -10)
			sellBtn.Position = UDim2.new(0.8, 5, 0, 5)
			sellBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
			sellBtn.Text = "Sell +" .. sellValue
			sellBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
			sellBtn.TextSize = 12
			sellBtn.Font = Enum.Font.GothamBold
			sellBtn.BorderSizePixel = 0
			sellBtn.Parent = entry



			-- Sell handler
			sellBtn.MouseButton1Click:Connect(function()
				StudEvents.SellStud:FireServer(stud.id)
				task.delay(0.3, function()
					local stats = StudEvents.GetPlayerStats:InvokeServer()
					updateCoins(stats.coins)
					populateSell()
				end)
			end)
		end
	end

	-- If no studs owned, show a message
	if order == 0 then
		local emptyLabel = Instance.new("TextLabel")
		emptyLabel.Size = UDim2.new(1, 0, 0, 60)
		emptyLabel.BackgroundTransparency = 1
		emptyLabel.Text = "No studs to sell!\nCatch some studs first."
		emptyLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
		emptyLabel.TextSize = 14
		emptyLabel.Font = Enum.Font.Gotham
		emptyLabel.Parent = scrollFrame
	end
end

-- Populate the BUY tab
local function populateBuy()
	clearContent()

	-- Shop state: featured stud of the day + owned consumable counts
	local shopInfo
	pcall(function()
		shopInfo = StudEvents.ShopInfo:InvokeServer()
	end)
	local ownedItems = shopInfo and shopInfo.items or {}

	-- Featured stud of the day (rotates every UTC day — the big coin sink)
	local featured = shopInfo and shopInfo.featured
	if featured then
		local entry = Instance.new("Frame")
		entry.Name = "featured_stud"
		entry.Size = UDim2.new(1, 0, 0, 74)
		entry.BackgroundColor3 = Color3.fromRGB(55, 45, 25)
		entry.BorderSizePixel = 0
		entry.LayoutOrder = 0
		entry.Parent = scrollFrame
		local entryStroke = Instance.new("UIStroke")
		entryStroke.Color = Color3.fromRGB(255, 200, 50)
		entryStroke.Thickness = 2
		entryStroke.Parent = entry

		local tile = Instance.new("Frame")
		tile.Size = UDim2.new(0, 40, 1, -8)
		tile.Position = UDim2.new(0, 8, 0, 4)
		tile.BackgroundColor3 = StudData.GetStudColor(featured)
		tile.BorderSizePixel = 0
		tile.Parent = entry

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.5, -50, 0, 22)
		nameLabel.Position = UDim2.new(0, 52, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = "⭐ STUD OF THE DAY: " .. featured.name
		nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = entry

		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.6, -50, 0, 34)
		descLabel.Position = UDim2.new(0, 52, 0, 30)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = featured.rarity .. " " .. featured.studType .. " · Lv" .. (featured.level or 5)
			.. (featured.owned > 0 and (" · Owned x" .. featured.owned) or " · NOT IN YOUR DEX")
			.. "\nNew stud daily!"
		descLabel.TextColor3 = Color3.fromRGB(200, 190, 160)
		descLabel.TextSize = 11
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextWrapped = true
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = entry

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0.25, -10, 1, -10)
		buyBtn.Position = UDim2.new(0.75, 5, 0, 5)
		local canAfford = playerCoins >= featured.price
		buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(200, 160, 40) or Color3.fromRGB(80, 80, 90)
		buyBtn.Text = "$" .. featured.price
		buyBtn.TextColor3 = canAfford and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 130)
		buyBtn.TextSize = 13
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = entry

		buyBtn.MouseButton1Click:Connect(function()
			if playerCoins < featured.price then return end
			buyBtn.Text = "..."
			buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
			StudEvents.BuyItem:FireServer("featured_stud")
			task.delay(0.5, function()
				local stats = StudEvents.GetPlayerStats:InvokeServer()
				updateCoins(stats.coins)
				populateBuy()
			end)
		end)
	end

	for i, item in ipairs(SHOP_ITEMS) do
		local entry = Instance.new("Frame")
		entry.Name = item.id
		entry.Size = UDim2.new(1, 0, 0, 60)
		entry.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		entry.BorderSizePixel = 0
		entry.LayoutOrder = i
		entry.Parent = scrollFrame
		local entryStroke = Instance.new("UIStroke")
		entryStroke.Color = Color3.fromRGB(10, 8, 14)
		entryStroke.Thickness = 2
		entryStroke.Parent = entry



		-- Icon (retro badge tag, e.g. "[TGT]" — avoids emoji glyphs that
		-- render as blank rectangles on fonts without full emoji coverage)
		local iconLabel = Instance.new("TextLabel")
		iconLabel.Size = UDim2.new(0, 40, 1, -8)
		iconLabel.Position = UDim2.new(0, 8, 0, 4)
		iconLabel.BackgroundColor3 = Color3.fromRGB(255, 196, 40)
		iconLabel.BorderSizePixel = 0
		iconLabel.Text = item.icon
		iconLabel.TextColor3 = Color3.fromRGB(10, 8, 14)
		iconLabel.TextScaled = true
		iconLabel.Font = Enum.Font.Arcade
		iconLabel.Parent = entry
		local iconStroke = Instance.new("UIStroke")
		iconStroke.Color = Color3.fromRGB(10, 8, 14)
		iconStroke.Thickness = 2
		iconStroke.Parent = iconLabel

		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(0.4, -50, 0, 22)
		nameLabel.Position = UDim2.new(0, 52, 0, 6)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = item.name
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.TextSize = 14
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextXAlignment = Enum.TextXAlignment.Left
		nameLabel.Parent = entry

		-- Description (consumables also show how many are in the bag)
		local descText = item.desc
		if item.consumable then
			descText = descText .. "  ·  Owned: x" .. (ownedItems[item.id] or 0)
		end
		local descLabel = Instance.new("TextLabel")
		descLabel.Size = UDim2.new(0.5, -50, 0, 18)
		descLabel.Position = UDim2.new(0, 52, 0, 28)
		descLabel.BackgroundTransparency = 1
		descLabel.Text = descText
		descLabel.TextColor3 = Color3.fromRGB(160, 160, 180)
		descLabel.TextSize = 11
		descLabel.Font = Enum.Font.Gotham
		descLabel.TextXAlignment = Enum.TextXAlignment.Left
		descLabel.Parent = entry

		-- Buy button
		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(0.25, -10, 1, -10)
		buyBtn.Position = UDim2.new(0.75, 5, 0, 5)
		local canAfford = playerCoins >= item.price
		buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(60, 160, 80) or Color3.fromRGB(80, 80, 90)
		buyBtn.Text = "$" .. item.price
		buyBtn.TextColor3 = canAfford and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 130)
		buyBtn.TextSize = 13
		buyBtn.Font = Enum.Font.GothamBold
		buyBtn.BorderSizePixel = 0
		buyBtn.Parent = entry
		local buyStroke = Instance.new("UIStroke")
		buyStroke.Color = Color3.fromRGB(10, 8, 14)
		buyStroke.Thickness = 2
		buyStroke.Parent = buyBtn



		-- Buy handler
		buyBtn.MouseButton1Click:Connect(function()
			if playerCoins < item.price then return end
			buyBtn.Text = "..."
			buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)

			StudEvents.BuyItem:FireServer(item.id)

			task.delay(0.5, function()
				local stats = StudEvents.GetPlayerStats:InvokeServer()
				updateCoins(stats.coins)
				populateBuy()
			end)
		end)
	end

	-- ─── HELD ITEMS (island-gated permanent equips) ──────────────────────
	-- The server returns exactly what's on sale at THIS island (universal items
	-- + local exclusives). Equip them onto a stud from the collection screen.
	local heldForSale = shopInfo and shopInfo.heldItemsForSale or {}
	if #heldForSale > 0 then
		local header = Instance.new("TextLabel")
		header.Name = "HeldItemsHeader"
		header.Size = UDim2.new(1, 0, 0, 34)
		header.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
		header.BorderSizePixel = 0
		header.LayoutOrder = 100
		header.Text = "  🎽 HELD ITEMS · " .. (shopInfo.currentWorldName or "This Island")
		header.TextColor3 = Color3.fromRGB(210, 190, 255)
		header.TextSize = 14
		header.Font = Enum.Font.GothamBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = scrollFrame

		for hi, item in ipairs(heldForSale) do
			local ownedCount = ownedItems[item.id] or 0
			local entry = Instance.new("Frame")
			entry.Name = "held_" .. item.id
			entry.Size = UDim2.new(1, 0, 0, 72)
			entry.BackgroundColor3 = item.island and Color3.fromRGB(46, 38, 64) or Color3.fromRGB(40, 40, 55)
			entry.BorderSizePixel = 0
			entry.LayoutOrder = 100 + hi
			entry.Parent = scrollFrame
			local entryStroke = Instance.new("UIStroke")
			entryStroke.Color = item.island and Color3.fromRGB(150, 110, 220) or Color3.fromRGB(10, 8, 14)
			entryStroke.Thickness = 2
			entryStroke.Parent = entry

			local iconLabel = Instance.new("TextLabel")
			iconLabel.Size = UDim2.new(0, 40, 0, 40)
			iconLabel.Position = UDim2.new(0, 8, 0, 6)
			iconLabel.BackgroundColor3 = Color3.fromRGB(30, 26, 44)
			iconLabel.BorderSizePixel = 0
			iconLabel.Text = item.icon or "🎽"
			iconLabel.TextScaled = true
			iconLabel.Font = Enum.Font.GothamBold
			iconLabel.Parent = entry

			local nameLabel = Instance.new("TextLabel")
			nameLabel.Size = UDim2.new(0.5, -50, 0, 20)
			nameLabel.Position = UDim2.new(0, 52, 0, 6)
			nameLabel.BackgroundTransparency = 1
			nameLabel.Text = item.name .. (ownedCount > 0 and ("  · In bag x" .. ownedCount) or "")
			nameLabel.TextColor3 = Color3.new(1, 1, 1)
			nameLabel.TextSize = 14
			nameLabel.Font = Enum.Font.GothamBold
			nameLabel.TextXAlignment = Enum.TextXAlignment.Left
			nameLabel.Parent = entry

			local notes = item.description or ""
			if item.typeLock then
				notes = notes .. "  ·  " .. item.typeLock .. " studs only"
			end
			if item.island then
				notes = notes .. "\n★ Exclusive to " .. StudData.GetWorldDisplayName(item.island)
			end
			local descLabel = Instance.new("TextLabel")
			descLabel.Size = UDim2.new(0.72, -50, 0, 44)
			descLabel.Position = UDim2.new(0, 52, 0, 26)
			descLabel.BackgroundTransparency = 1
			descLabel.Text = notes
			descLabel.TextColor3 = item.island and Color3.fromRGB(205, 180, 245) or Color3.fromRGB(160, 160, 180)
			descLabel.TextSize = 11
			descLabel.Font = Enum.Font.Gotham
			descLabel.TextWrapped = true
			descLabel.TextYAlignment = Enum.TextYAlignment.Top
			descLabel.TextXAlignment = Enum.TextXAlignment.Left
			descLabel.Parent = entry

			local buyBtn = Instance.new("TextButton")
			buyBtn.Size = UDim2.new(0.25, -10, 0, 40)
			buyBtn.Position = UDim2.new(0.75, 5, 0, 16)
			local canAfford = playerCoins >= (item.price or 0)
			buyBtn.BackgroundColor3 = canAfford and Color3.fromRGB(120, 90, 200) or Color3.fromRGB(80, 80, 90)
			buyBtn.Text = "$" .. (item.price or 0)
			buyBtn.TextColor3 = canAfford and Color3.new(1, 1, 1) or Color3.fromRGB(120, 120, 130)
			buyBtn.TextSize = 13
			buyBtn.Font = Enum.Font.GothamBold
			buyBtn.BorderSizePixel = 0
			buyBtn.Parent = entry
			local buyStroke = Instance.new("UIStroke")
			buyStroke.Color = Color3.fromRGB(10, 8, 14)
			buyStroke.Thickness = 2
			buyStroke.Parent = buyBtn

			buyBtn.MouseButton1Click:Connect(function()
				if playerCoins < (item.price or 0) then return end
				buyBtn.Text = "..."
				buyBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 90)
				StudEvents.BuyItem:FireServer(item.id)
				task.delay(0.5, function()
					local stats = StudEvents.GetPlayerStats:InvokeServer()
					updateCoins(stats.coins)
					populateBuy()
				end)
			end)
		end
	end
end

-- Refresh content based on current tab
function refreshContent()
	if currentTab == "Sell" then
		populateSell()
	elseif currentTab == "Buy" then
		populateBuy()
	end
end

-- Toggle shop visibility
local function openShop()
	if isOpen then return end
	UIManager.CloseOtherPanels("Shop")
	isOpen = true
	frame.Visible = true

	-- Get current stats
	local stats = StudEvents.GetPlayerStats:InvokeServer()
	updateCoins(stats.coins)
	refreshContent()

	-- Animate in
	frame.Position = UDim2.new(0.2, 0, 1, 0)
	local tween = TweenService:Create(frame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.2, 0, 0.15, 0)
	})
	tween:Play()
end

local function closeShop()
	if not isOpen then return end
	isOpen = false

	local tween = TweenService:Create(frame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Position = UDim2.new(0.2, 0, 1, 0)
	})
	tween:Play()
	tween.Completed:Connect(function()
		frame.Visible = false
	end)
end

-- Close button
closeBtn.MouseButton1Click:Connect(closeShop)

-- Exclusive-panel registration (Quests/Settings/Leaderboard close the shop
-- when they open, and openShop closes them)
UIManager.RegisterPanel("Shop", closeShop)

-- HUD icon toggles the shop from anywhere
toggleBtn.MouseButton1Click:Connect(function()
	if isOpen then
		closeShop()
	else
		openShop()
	end
end)

-- Listen for shop open trigger from server
player:GetAttributeChangedSignal("OpenShop"):Connect(function()
	if player:GetAttribute("OpenShop") == true then
		openShop()
	end
end)

-- Listen for coin updates from server
StudEvents.UpdateCoins.OnClientEvent:Connect(function(coins)
	updateCoins(coins)
end)

-- Listen for purchase results (RemoteEvent — reliable even when the same
-- item is bought twice in a row, unlike the old attribute flash, which
-- fired no changed signal on a repeated value)
StudEvents:WaitForChild("BuyResult").OnClientEvent:Connect(function(result, _itemId)
	if not result then return end
	-- Result feedback is currently handled by the coin update + item state;
	-- hook future purchase toasts/sounds here.
end)

-- Close on ESC
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and isOpen then
		closeShop()
	end
end)

print("[ShopUI] Initialized")