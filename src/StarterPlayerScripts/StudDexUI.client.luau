-- StudDexUI: Enhanced collection viewer with type filters and detail view
-- Press 'C' to toggle
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local StoryData = require(ReplicatedStorage:WaitForChild("StoryData"))
local playerGui = player:WaitForChild("PlayerGui")
-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StudDexUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui
-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0.75, 0, 0.85, 0)
mainFrame.Position = UDim2.new(0.125, 0, 0.075, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0.07, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0.6, 0, 1, 0)
titleLabel.Position = UDim2.new(0.02, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "StudDex"
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.Font = Enum.Font.Arcade
titleLabel.TextSize = 26
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar
-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0.08, 0, 0.7, 0)
closeBtn.Position = UDim2.new(0.9, 0, 0.15, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.Arcade
closeBtn.TextSize = 20
closeBtn.Parent = titleBar

-- Stats bar with progress
local statsBar = Instance.new("Frame")
statsBar.Name = "StatsBar"
statsBar.Size = UDim2.new(1, -20, 0.05, 0)
statsBar.Position = UDim2.new(0, 10, 0.08, 0)
statsBar.BackgroundColor3 = Color3.fromRGB(35, 35, 55)
statsBar.BorderSizePixel = 0
statsBar.Parent = mainFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(0.5, 0, 1, 0)
statsLabel.Position = UDim2.new(0.02, 0, 0, 0)
statsLabel.BackgroundTransparency = 1
statsLabel.Text = "Caught: 0 / 24"
statsLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statsLabel.Font = Enum.Font.Arcade
statsLabel.TextSize = 16
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.Parent = statsBar
-- Progress bar
local progressBg = Instance.new("Frame")
progressBg.Name = "ProgressBg"
progressBg.Size = UDim2.new(0.4, 0, 0.5, 0)
progressBg.Position = UDim2.new(0.55, 0, 0.25, 0)
progressBg.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
progressBg.BorderSizePixel = 0
progressBg.Parent = statsBar

local progressFill = Instance.new("Frame")
progressFill.Name = "ProgressFill"
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
progressFill.BorderSizePixel = 0
progressFill.Parent = progressBg

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, 0, 1, 0)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "0%"
progressLabel.TextColor3 = Color3.new(1, 1, 1)
progressLabel.Font = Enum.Font.Arcade
progressLabel.TextSize = 12
progressLabel.ZIndex = 2
progressLabel.Parent = progressBg
-- Type filter tabs
local filterBar = Instance.new("Frame")
filterBar.Name = "FilterBar"
filterBar.Size = UDim2.new(1, -20, 0.045, 0)
filterBar.Position = UDim2.new(0, 10, 0.14, 0)
filterBar.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
filterBar.BorderSizePixel = 0
filterBar.Parent = mainFrame

local filterLayout = Instance.new("UIListLayout")
filterLayout.FillDirection = Enum.FillDirection.Horizontal
filterLayout.SortOrder = Enum.SortOrder.LayoutOrder
filterLayout.Padding = UDim.new(0, 4)
filterLayout.Parent = filterBar
local filterPadding = Instance.new("UIPadding")
filterPadding.PaddingLeft = UDim.new(0, 4)
filterPadding.PaddingTop = UDim.new(0, 3)
filterPadding.Parent = filterBar
-- Forward declaration: the filter buttons below capture this as an upvalue.
-- (The old code called `refreshCollection`, a local declared AFTER the
-- buttons — so the closures saw a nil global and filter clicks errored.)
local renderCollection

-- Shadow was missing from this list even though Shadow studs exist —
-- they were undiscoverable in the dex filter
local typeFilters = {"All", "Fire", "Water", "Grass", "Electric", "Rock", "Ice", "Shadow"}
local typeColors = {
	All = Color3.fromRGB(180, 180, 180),
	Fire = Color3.fromRGB(230, 60, 40),
	Water = Color3.fromRGB(40, 120, 230),
	Grass = Color3.fromRGB(40, 180, 60),
	Electric = Color3.fromRGB(240, 210, 30),
	Rock = Color3.fromRGB(160, 140, 100),
	Ice = Color3.fromRGB(140, 210, 240),
	Shadow = Color3.fromRGB(80, 50, 120),
}
local activeFilter = "All"
local filterButtons = {}
for i, filterName in ipairs(typeFilters) do
	local btn = Instance.new("TextButton")
	btn.Name = filterName .. "Filter"
	btn.Size = UDim2.new(0, 52, 0, 24)
	btn.BackgroundColor3 = typeColors[filterName]
	btn.BackgroundTransparency = (filterName == "All") and 0 or 0.5
	btn.Text = filterName
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Arcade
	btn.TextSize = 12
	btn.BorderSizePixel = 0
	btn.LayoutOrder = i
	btn.Parent = filterBar

	filterButtons[filterName] = btn
	btn.MouseButton1Click:Connect(function()
		activeFilter = filterName
		for name, b in pairs(filterButtons) do
			b.BackgroundTransparency = (name == filterName) and 0 or 0.5
		end
		renderCollection()
	end)
end

-- Second filter row: rarity tabs + caught-only toggle + name search.
-- At 105 species the flat grid needs these to stay navigable.
local rarityBar = Instance.new("Frame")
rarityBar.Name = "RarityBar"
rarityBar.Size = UDim2.new(1, -20, 0.045, 0)
rarityBar.Position = UDim2.new(0, 10, 0.19, 0)
rarityBar.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
rarityBar.BorderSizePixel = 0
rarityBar.Parent = mainFrame

local rarityLayout = Instance.new("UIListLayout")
rarityLayout.FillDirection = Enum.FillDirection.Horizontal
rarityLayout.SortOrder = Enum.SortOrder.LayoutOrder
rarityLayout.Padding = UDim.new(0, 4)
rarityLayout.Parent = rarityBar
local rarityPadding = Instance.new("UIPadding")
rarityPadding.PaddingLeft = UDim.new(0, 4)
rarityPadding.PaddingTop = UDim.new(0, 3)
rarityPadding.Parent = rarityBar

local rarityFilters = {"All", "Common", "Uncommon", "Rare", "Legendary"}
local activeRarity = "All"
local caughtOnly = false
local searchQuery = ""
local rarityButtons = {}

for i, rarityName in ipairs(rarityFilters) do
	local btn = Instance.new("TextButton")
	btn.Name = rarityName .. "Rarity"
	btn.Size = UDim2.new(0, 74, 0, 24)
	btn.BackgroundColor3 = rarityName == "All" and Color3.fromRGB(180, 180, 180)
		or (StudData.Rarity[rarityName] and StudData.Rarity[rarityName].color)
		or Color3.fromRGB(180, 180, 180)
	btn.BackgroundTransparency = (rarityName == "All") and 0 or 0.5
	btn.Text = rarityName
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.Arcade
	btn.TextSize = 11
	btn.BorderSizePixel = 0
	btn.LayoutOrder = i
	btn.Parent = rarityBar

	rarityButtons[rarityName] = btn
	btn.MouseButton1Click:Connect(function()
		activeRarity = rarityName
		for name, b in pairs(rarityButtons) do
			b.BackgroundTransparency = (name == rarityName) and 0 or 0.5
		end
		renderCollection()
	end)
end

local caughtToggle = Instance.new("TextButton")
caughtToggle.Name = "CaughtToggle"
caughtToggle.Size = UDim2.new(0, 90, 0, 24)
caughtToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
caughtToggle.Text = "Caught only"
caughtToggle.TextColor3 = Color3.fromRGB(200, 200, 210)
caughtToggle.Font = Enum.Font.Arcade
caughtToggle.TextSize = 11
caughtToggle.BorderSizePixel = 0
caughtToggle.LayoutOrder = 10
caughtToggle.Parent = rarityBar
caughtToggle.MouseButton1Click:Connect(function()
	caughtOnly = not caughtOnly
	caughtToggle.BackgroundColor3 = caughtOnly and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(60, 60, 75)
	caughtToggle.TextColor3 = caughtOnly and Color3.fromRGB(20, 20, 30) or Color3.fromRGB(200, 200, 210)
	renderCollection()
end)

local searchBox = Instance.new("TextBox")
searchBox.Name = "DexSearch"
searchBox.Size = UDim2.new(0, 150, 0, 24)
searchBox.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
searchBox.PlaceholderText = "🔎 Search name..."
searchBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 135)
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.TextColor3 = Color3.new(1, 1, 1)
searchBox.Font = Enum.Font.Arcade
searchBox.TextSize = 12
searchBox.BorderSizePixel = 0
searchBox.LayoutOrder = 11
searchBox.Parent = rarityBar
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	searchQuery = string.lower(searchBox.Text)
	renderCollection()
end)

-- Scroll frame for Stud entries
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "StudList"
scrollFrame.Size = UDim2.new(0.55, -10, 0.73, 0)
scrollFrame.Position = UDim2.new(0, 10, 0.24, 0)
scrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 6
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 120)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 90, 0, 110)
gridLayout.CellPadding = UDim2.new(0, 8, 0, 8)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = scrollFrame
-- Detail panel (right side)
local detailPanel = Instance.new("Frame")
detailPanel.Name = "DetailPanel"
detailPanel.Size = UDim2.new(0.42, -10, 0.73, 0)
detailPanel.Position = UDim2.new(0.56, 0, 0.24, 0)
detailPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 48)
detailPanel.BorderSizePixel = 0
detailPanel.Visible = false
detailPanel.Parent = mainFrame

-- Detail: Stud tile visual
local detailTile = Instance.new("Frame")
detailTile.Name = "DetailTile"
detailTile.Size = UDim2.new(0, 80, 0, 80)
detailTile.Position = UDim2.new(0.5, -40, 0.05, 0)
detailTile.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
detailTile.BorderSizePixel = 0
detailTile.Parent = detailPanel

-- Detail: Name
local detailName = Instance.new("TextLabel")
detailName.Name = "DetailName"
detailName.Size = UDim2.new(1, -20, 0, 30)
detailName.Position = UDim2.new(0, 10, 0.25, 0)
detailName.BackgroundTransparency = 1
detailName.Text = "???"
detailName.TextColor3 = Color3.new(1, 1, 1)
detailName.Font = Enum.Font.Arcade
detailName.TextSize = 24
detailName.Parent = detailPanel
-- Detail: Type + Rarity
local detailTypeRarity = Instance.new("TextLabel")
detailTypeRarity.Name = "DetailTypeRarity"
detailTypeRarity.Size = UDim2.new(1, -20, 0, 20)
detailTypeRarity.Position = UDim2.new(0, 10, 0.35, 0)
detailTypeRarity.BackgroundTransparency = 1
detailTypeRarity.Text = "??? Stud - Common"
detailTypeRarity.TextColor3 = Color3.fromRGB(180, 180, 180)
detailTypeRarity.Font = Enum.Font.Arcade
detailTypeRarity.TextSize = 16
detailTypeRarity.TextXAlignment = Enum.TextXAlignment.Left
detailTypeRarity.Parent = detailPanel
-- Detail: Description
local detailDesc = Instance.new("TextLabel")
detailDesc.Name = "DetailDesc"
detailDesc.Size = UDim2.new(1, -20, 0, 50)
detailDesc.Position = UDim2.new(0, 10, 0.45, 0)
detailDesc.BackgroundTransparency = 1
detailDesc.Text = ""
detailDesc.TextColor3 = Color3.fromRGB(160, 160, 170)
detailDesc.Font = Enum.Font.Arcade
detailDesc.TextSize = 14
detailDesc.TextWrapped = true
detailDesc.TextXAlignment = Enum.TextXAlignment.Left
detailDesc.TextYAlignment = Enum.TextYAlignment.Top
detailDesc.Parent = detailPanel
-- Detail: Story aside — the "these were people" layer (Seven Ways Home).
-- Only rendered for caught species while Story mode is on; Casual sees
-- the exact same dex minus this line.
local detailAside = Instance.new("TextLabel")
detailAside.Name = "DetailAside"
detailAside.Size = UDim2.new(1, -20, 0, 34)
detailAside.Position = UDim2.new(0, 10, 0.45, 52)
detailAside.BackgroundTransparency = 1
detailAside.Text = ""
detailAside.TextColor3 = Color3.fromRGB(215, 190, 130)
detailAside.Font = Enum.Font.Arcade
detailAside.TextSize = 11
detailAside.TextWrapped = true
detailAside.TextXAlignment = Enum.TextXAlignment.Left
detailAside.TextYAlignment = Enum.TextYAlignment.Top
detailAside.Parent = detailPanel
-- Detail: Type effectiveness
local detailEffLabel = Instance.new("TextLabel")
detailEffLabel.Name = "DetailEffectiveness"
detailEffLabel.Size = UDim2.new(1, -20, 0, 60)
detailEffLabel.Position = UDim2.new(0, 10, 0.65, 0)
detailEffLabel.BackgroundTransparency = 1
detailEffLabel.Text = ""
detailEffLabel.TextColor3 = Color3.fromRGB(140, 140, 150)
detailEffLabel.Font = Enum.Font.Arcade
detailEffLabel.TextSize = 12
detailEffLabel.TextWrapped = true
detailEffLabel.TextXAlignment = Enum.TextXAlignment.Left
detailEffLabel.TextYAlignment = Enum.TextYAlignment.Top
detailEffLabel.Parent = detailPanel
-- Detail: Location hint (derived from spawn tables — shown even for
-- uncaught studs, since it's how you FIND them)
local detailLocation = Instance.new("TextLabel")
detailLocation.Name = "DetailLocation"
detailLocation.Size = UDim2.new(1, -20, 0, 34)
detailLocation.Position = UDim2.new(0, 10, 0.79, 0)
detailLocation.BackgroundTransparency = 1
detailLocation.Text = ""
detailLocation.TextColor3 = Color3.fromRGB(150, 210, 160)
detailLocation.Font = Enum.Font.Arcade
detailLocation.TextSize = 12
detailLocation.TextWrapped = true
detailLocation.TextXAlignment = Enum.TextXAlignment.Left
detailLocation.TextYAlignment = Enum.TextYAlignment.Top
detailLocation.Parent = detailPanel
-- Detail: Catch count
local detailCatchCount = Instance.new("TextLabel")
detailCatchCount.Name = "DetailCatchCount"
detailCatchCount.Size = UDim2.new(1, -20, 0, 20)
detailCatchCount.Position = UDim2.new(0, 10, 0.88, 0)
detailCatchCount.BackgroundTransparency = 1
detailCatchCount.Text = ""
detailCatchCount.TextColor3 = Color3.fromRGB(255, 220, 100)
detailCatchCount.Font = Enum.Font.Arcade
detailCatchCount.TextSize = 14
detailCatchCount.TextXAlignment = Enum.TextXAlignment.Left
detailCatchCount.Parent = detailPanel
-- Build the StudDex entries
local caughtIds = {}
local catchCounts = {}
local shinyIds = {} -- species with at least one shiny copy owned

-- "📍 Studville, Emberpeak · more at night"
local function locationText(stud)
	local worlds, note = StudData.GetSpeciesLocations(stud.id)
	if not worlds or #worlds == 0 then return "" end
	return "📍 " .. table.concat(worlds, ", ") .. (note and (" · " .. note) or "")
end

local function showDetail(stud)
	detailPanel.Visible = true
	local isCaught = caughtIds[stud.id]
	if isCaught then
		detailTile.BackgroundColor3 = StudData.GetStudColor(stud)
		detailName.Text = stud.name .. (shinyIds[stud.id] and " ✨" or "")
		detailTypeRarity.Text = stud.studType .. " Stud - " .. stud.rarity
		detailTypeRarity.TextColor3 = StudData.Rarity[stud.rarity] and StudData.Rarity[stud.rarity].color or Color3.fromRGB(180, 180, 180)
		detailDesc.Text = stud.description
		local aside = StoryData.DexAsides[stud.id]
		if aside and player:GetAttribute("StoryMode") ~= false then
			detailAside.Text = "🖊️ " .. aside
		else
			detailAside.Text = ""
		end
		-- Show type effectiveness
		local effs = StudData.TypeEffectiveness[stud.studType] or {}
		local effText = "Type Effectiveness:\n"
		for defType, mult in pairs(effs) do
			if mult > 1 then
				effText = effText .. "  Strong vs " .. defType .. " (" .. math.floor(mult * 100) .. "%)\n"
			elseif mult < 1 then
				effText = effText .. "  Weak vs " .. defType .. " (" .. math.floor(mult * 100) .. "%)\n"
			end
		end
		detailEffLabel.Text = effText
		detailLocation.Text = locationText(stud)
		-- Show catch count
		local count = catchCounts[stud.id] or 0
		detailCatchCount.Text = "Caught: " .. count .. "x" .. (shinyIds[stud.id] and "  ·  ✨ Shiny owned!" or "")
	else
		detailTile.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
		detailName.Text = "???"
		detailTypeRarity.Text = "Undiscovered"
		detailTypeRarity.TextColor3 = Color3.fromRGB(120, 120, 130)
		detailDesc.Text = "This Stud has not been caught yet. Explore different zones to find it!"
		detailAside.Text = ""
		detailEffLabel.Text = ""
		-- The hint is how players FIND undiscovered studs
		detailLocation.Text = locationText(stud)
		detailCatchCount.Text = ""
	end
end
-- Pull the collection from the server (only on open — filter/search
-- changes re-render locally from this cache instead of re-invoking)
local function fetchCollection()
	local collection = StudEvents.RequestCollection:InvokeServer()
	caughtIds = {}
	catchCounts = {}
	shinyIds = {}
	for _, entry in collection do
		caughtIds[entry.id] = true
		catchCounts[entry.id] = (catchCounts[entry.id] or 0) + 1
		if entry.isShiny then
			shinyIds[entry.id] = true
		end
	end
end

function renderCollection()
	-- Clear existing entries (Destroy, not Parent=nil — detached frames
	-- with connections were leaking on every refresh)
	for _, child in scrollFrame:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	-- Create an entry for every Stud that passes the active filters
	for i, stud in ipairs(StudData.Studs) do
		local isCaught = caughtIds[stud.id] or false
		if activeFilter ~= "All" and stud.studType ~= activeFilter then
			continue
		end
		if activeRarity ~= "All" and stud.rarity ~= activeRarity then
			continue
		end
		if caughtOnly and not isCaught then
			continue
		end
		-- Search matches the name only when caught ("???" studs stay hidden
		-- mysteries) but always matches when the query is empty
		if searchQuery ~= "" then
			if not isCaught or not string.find(string.lower(stud.name), searchQuery, 1, true) then
				continue
			end
		end
		local entry = Instance.new("Frame")
		entry.Name = stud.id
		entry.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
		entry.BorderSizePixel = 0
		entry.LayoutOrder = i
		entry.Parent = scrollFrame

		-- Type-colored border for caught studs
		if isCaught then
			local border = Instance.new("UIStroke")
			border.Color = StudData.GetStudColor(stud)
			border.Thickness = 2
			border.Parent = entry
		end
		-- Stud color tile
		local tile = Instance.new("Frame")
		tile.Name = "Tile"
		tile.Size = UDim2.new(0, 44, 0, 44)
		tile.Position = UDim2.new(0.5, -22, 0.05, 0)
		tile.BackgroundColor3 = isCaught and StudData.GetStudColor(stud) or Color3.fromRGB(60, 60, 70)
		tile.BorderSizePixel = 0
		tile.Parent = entry

		-- Shiny sparkle for species with a shiny copy owned
		if shinyIds[stud.id] then
			local sparkle = Instance.new("TextLabel")
			sparkle.Size = UDim2.new(0, 20, 0, 20)
			sparkle.Position = UDim2.new(1, -22, 0, 2)
			sparkle.BackgroundTransparency = 1
			sparkle.Text = "✨"
			sparkle.TextSize = 14
			sparkle.Font = Enum.Font.Arcade
			sparkle.TextColor3 = Color3.fromRGB(255, 215, 0)
			sparkle.ZIndex = 3
			sparkle.Parent = entry
		end
		-- Rarity glow for caught rare/legendary
		if isCaught and (stud.rarity == "Rare" or stud.rarity == "Legendary") then
			local glow = Instance.new("ImageLabel")
			glow.Size = UDim2.new(0, 52, 0, 52)
			glow.Position = UDim2.new(0.5, -26, 0.03, 0)
			glow.BackgroundTransparency = 1
			glow.Image = "rbxassetid://2618688380"
			glow.ImageColor3 = StudData.Rarity[stud.rarity].color
			glow.ImageTransparency = 0.5
			glow.Parent = entry
		end
		-- Name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0.15, 0)
		nameLabel.Position = UDim2.new(0, 0, 0.5, 0)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = isCaught and stud.name or "???"
		nameLabel.TextColor3 = Color3.new(1, 1, 1)
		nameLabel.Font = Enum.Font.Arcade
		nameLabel.TextSize = 11
		nameLabel.Parent = entry
		-- Type
		local typeLabel = Instance.new("TextLabel")
		typeLabel.Size = UDim2.new(1, 0, 0.12, 0)
		typeLabel.Position = UDim2.new(0, 0, 0.65, 0)
		typeLabel.BackgroundTransparency = 1
		typeLabel.Text = isCaught and stud.studType or "???"
		typeLabel.TextColor3 = isCaught and typeColors[stud.studType] or Color3.fromRGB(150, 150, 160)
		typeLabel.Font = Enum.Font.Arcade
		typeLabel.TextSize = 10
		typeLabel.Parent = entry
		-- Rarity dot
		local rarityDot = Instance.new("Frame")
		rarityDot.Size = UDim2.new(0, 10, 0, 10)
		rarityDot.Position = UDim2.new(0.5, -5, 0.82, 0)
		rarityDot.BackgroundColor3 = isCaught and StudData.Rarity[stud.rarity].color or Color3.fromRGB(60, 60, 70)
		rarityDot.BorderSizePixel = 0
		rarityDot.Parent = entry
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(1, 0)
		dotCorner.Parent = rarityDot
		-- Silhouette overlay for uncaught
		if not isCaught then
			local qLabel = Instance.new("TextLabel")
			qLabel.Size = UDim2.new(1, 0, 0.3, 0)
			qLabel.Position = UDim2.new(0, 0, 0.1, 0)
			qLabel.BackgroundTransparency = 1
			qLabel.Text = "?"
			qLabel.TextColor3 = Color3.fromRGB(80, 80, 90)
			qLabel.Font = Enum.Font.Arcade
			qLabel.TextSize = 28
			qLabel.Parent = entry
		end
		-- Click to show detail
		local clickBtn = Instance.new("TextButton")
		clickBtn.Size = UDim2.new(1, 0, 1, 0)
		clickBtn.BackgroundTransparency = 1
		clickBtn.Text = ""
		clickBtn.Parent = entry
		clickBtn.MouseButton1Click:Connect(function()
			showDetail(stud)
		end)
	end
	-- Count total caught across all types for stats
	local totalCaught = 0
	for _ in pairs(caughtIds) do
		totalCaught = totalCaught + 1
	end
	local shinySpecies = 0
	for _ in pairs(shinyIds) do
		shinySpecies += 1
	end
	statsLabel.Text = "Caught: " .. totalCaught .. " / " .. #StudData.Studs .. "  ·  ✨ " .. shinySpecies
	local pct = totalCaught / #StudData.Studs
	progressFill.Size = UDim2.new(pct, 0, 1, 0)
	progressLabel.Text = math.floor(pct * 100) .. "%"
	if pct >= 1 then
		progressFill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
	elseif pct >= 0.5 then
		progressFill.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	else
		progressFill.BackgroundColor3 = Color3.fromRGB(80, 150, 220)
	end
	-- Hide detail panel on refresh
	detailPanel.Visible = false
end
-- Toggle visibility
local function toggle()
	screenGui.Enabled = not screenGui.Enabled
	if screenGui.Enabled then
		fetchCollection()
		renderCollection()
	end
end
-- Keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.C then
		toggle()
	end
end)
-- Close button
closeBtn.MouseButton1Click:Connect(function()
	screenGui.Enabled = false
end)
print("[StudDexUI] Initialized - Press C to open")