-- Evolution UI: Shows evolution chains and lets players evolve their Studs

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

-- State
local evoPoints = {}
local collection = {}
local isAnimating = false

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "EvolutionUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 520, 0, 480)
mainFrame.Position = UDim2.new(0.5, -260, 0.5, -240)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 35)
mainFrame.BackgroundTransparency = 0.05
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui



local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(100, 100, 160)
mainStroke.Thickness = 2
mainStroke.Transparency = 0.3
mainStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 44)
titleBar.BackgroundColor3 = Color3.fromRGB(30, 25, 50)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame



local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "\226\156\168 Evolution Lab"
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 18
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.Position = UDim2.new(1, -40, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.BackgroundTransparency = 0.3
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar



-- Info label
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 28)
infoLabel.Position = UDim2.new(0, 10, 0, 48)
infoLabel.BackgroundTransparency = 1
infoLabel.Text = "Catch duplicates to earn EvoPoints! Spend them to evolve your Studs."
infoLabel.TextColor3 = Color3.fromRGB(160, 160, 190)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 11
infoLabel.TextWrapped = true
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Parent = mainFrame

-- Scrollable content area
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -85)
scrollFrame.Position = UDim2.new(0, 10, 0, 78)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 160)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local contentLayout = Instance.new("UIListLayout")
contentLayout.FillDirection = Enum.FillDirection.Vertical
contentLayout.Padding = UDim.new(0, 6)
contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
contentLayout.Parent = scrollFrame

-- Build evolution chain rows for each type
local chainRows = {}
local typeOrder = {"Fire", "Water", "Grass", "Electric", "Rock", "Ice", "Shadow"}

for typeIdx, typeName in ipairs(typeOrder) do
	local typeData = StudData.Types[typeName]
	if not typeData then continue end

	local chain = StudData.EvolutionChains[typeName]
	if not chain then continue end

	-- Section header with type name and evoPoints
	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 28)
	header.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	header.BackgroundTransparency = 0.3
	header.BorderSizePixel = 0
	header.LayoutOrder = typeIdx * 10
	header.Parent = scrollFrame



	local headerLabel = Instance.new("TextLabel")
	headerLabel.Size = UDim2.new(0.6, 0, 1, 0)
	headerLabel.Position = UDim2.new(0, 10, 0, 0)
	headerLabel.BackgroundTransparency = 1
	headerLabel.Text = typeData.icon .. " " .. typeName
	headerLabel.TextColor3 = typeData.color
	headerLabel.Font = Enum.Font.GothamBold
	headerLabel.TextSize = 14
	headerLabel.TextXAlignment = Enum.TextXAlignment.Left
	headerLabel.Parent = header

	local pointsLabel = Instance.new("TextLabel")
	pointsLabel.Name = "PointsLabel"
	pointsLabel.Size = UDim2.new(0.4, -10, 1, 0)
	pointsLabel.Position = UDim2.new(0.6, 0, 0, 0)
	pointsLabel.BackgroundTransparency = 1
	pointsLabel.Text = "0 EvoPoints"
	pointsLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
	pointsLabel.Font = Enum.Font.GothamBold
	pointsLabel.TextSize = 12
	pointsLabel.TextXAlignment = Enum.TextXAlignment.Right
	pointsLabel.Parent = header

	-- Chain row showing all 4 studs with arrows
	local chainRow = Instance.new("Frame")
	chainRow.Size = UDim2.new(1, 0, 0, 70)
	chainRow.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
	chainRow.BackgroundTransparency = 0.2
	chainRow.BorderSizePixel = 0
	chainRow.LayoutOrder = typeIdx * 10 + 1
	chainRow.Parent = scrollFrame



	-- Stud slots in the chain
	local studSlots = {}
	for slotIdx, studId in ipairs(chain) do
		local stud = StudData.GetStudById(studId)
		if not stud then continue end

		local slotX = (slotIdx - 1) * 120 + 10

		-- Stud tile
		local tile = Instance.new("Frame")
		tile.Name = studId .. "Tile"
		tile.Size = UDim2.new(0, 90, 0, 58)
		tile.Position = UDim2.new(0, slotX, 0, 6)
		tile.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
		tile.BackgroundTransparency = 0.1
		tile.BorderSizePixel = 0
		tile.Parent = chainRow



		local tileStroke = Instance.new("UIStroke")
		tileStroke.Color = typeData.color
		tileStroke.Thickness = 1.5
		tileStroke.Transparency = 0.5
		tileStroke.Parent = tile

		-- Stud name
		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, 0, 0, 18)
		nameLabel.Position = UDim2.new(0, 0, 0, 4)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = stud.name
		nameLabel.TextColor3 = typeData.color
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextSize = 12
		nameLabel.Parent = tile

		-- Rarity label
		local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, 0, 0, 14)
		rarityLabel.Position = UDim2.new(0, 0, 0, 22)
		rarityLabel.BackgroundTransparency = 1
		rarityLabel.Text = stud.rarity
		rarityLabel.TextColor3 = StudData.Rarity[stud.rarity] and StudData.Rarity[stud.rarity].color or Color3.fromRGB(180, 180, 180)
		rarityLabel.Font = Enum.Font.Gotham
		rarityLabel.TextSize = 10
		rarityLabel.Parent = tile

		-- Status label (owned / locked / can evolve)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "Status"
		statusLabel.Size = UDim2.new(1, 0, 0, 14)
		statusLabel.Position = UDim2.new(0, 0, 0, 38)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Text = "???"
		statusLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextSize = 9
		statusLabel.Parent = tile

		-- Evolve button (only for owned studs that can evolve)
		local evolveBtn = Instance.new("TextButton")
		evolveBtn.Name = "EvolveBtn"
		evolveBtn.Size = UDim2.new(1, -4, 0, 14)
		evolveBtn.Position = UDim2.new(0, 2, 1, -16)
		evolveBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
		evolveBtn.BackgroundTransparency = 0.2
		evolveBtn.Text = "Evolve!"
		evolveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		evolveBtn.Font = Enum.Font.GothamBold
		evolveBtn.TextSize = 9
		evolveBtn.BorderSizePixel = 0
		evolveBtn.Visible = false
		evolveBtn.Parent = tile



		-- Evolve button click handler
		evolveBtn.MouseButton1Click:Connect(function()
			if isAnimating then return end
			performEvolution(studId)
		end)

		studSlots[studId] = {
			tile = tile,
			nameLabel = nameLabel,
			rarityLabel = rarityLabel,
			statusLabel = statusLabel,
			evolveBtn = evolveBtn,
			tileStroke = tileStroke,
		}

		-- Arrow between studs
		if slotIdx < #chain then
			local arrow = Instance.new("TextLabel")
			arrow.Size = UDim2.new(0, 20, 0, 58)
			arrow.Position = UDim2.new(0, slotX + 90, 0, 6)
			arrow.BackgroundTransparency = 1
			arrow.Text = "\226\158\156"
			arrow.TextColor3 = Color3.fromRGB(120, 120, 160)
			arrow.Font = Enum.Font.GothamBold
			arrow.TextSize = 16
			arrow.Parent = chainRow

			-- Cost label below arrow
			local costLabel = Instance.new("TextLabel")
			costLabel.Size = UDim2.new(0, 20, 0, 12)
			costLabel.Position = UDim2.new(0, slotX + 90, 0, 56)
			costLabel.BackgroundTransparency = 1
			local cost = StudData.EvolutionCosts[stud.rarity]
			costLabel.Text = cost and tostring(cost) or "?"
			costLabel.TextColor3 = Color3.fromRGB(180, 180, 200)
			costLabel.Font = Enum.Font.Gotham
			costLabel.TextSize = 9
			costLabel.Parent = chainRow
		end
	end

	chainRows[typeName] = {
		header = header,
		pointsLabel = pointsLabel,
		studSlots = studSlots,
	}
end

-- Evolution animation overlay
local evoOverlay = Instance.new("Frame")
evoOverlay.Name = "EvoOverlay"
evoOverlay.Size = UDim2.new(1, 0, 1, 0)
evoOverlay.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
evoOverlay.BackgroundTransparency = 1
evoOverlay.ZIndex = 100
evoOverlay.Visible = false
evoOverlay.Parent = screenGui

local evoText = Instance.new("TextLabel")
evoText.Size = UDim2.new(0.6, 0, 0, 60)
evoText.Position = UDim2.new(0.2, 0, 0.4, 0)
evoText.BackgroundTransparency = 1
evoText.Text = ""
evoText.TextColor3 = Color3.fromRGB(255, 220, 100)
evoText.Font = Enum.Font.GothamBold
evoText.TextSize = 28
evoText.ZIndex = 101
evoText.Parent = evoOverlay

-- Perform evolution
local function performEvolution(studId)
	if isAnimating then return end
	isAnimating = true

	-- Call server
	local result = StudEvents.EvolveStud:InvokeServer(studId)

	if result and result.success then
		-- Show evolution animation
		evoOverlay.Visible = true

		local oldStud = StudData.GetStudById(result.oldStud)
		local newStud = StudData.GetStudById(result.newStud)

		-- Flash white
		evoText.Text = (oldStud and oldStud.name or "?") .. " is evolving!"
		local flashIn = TweenService:Create(evoOverlay, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0.3
		})
		flashIn:Play()
		flashIn.Completed:Wait()

		task.wait(0.5)

		-- Show new name
		evoText.Text = "Congratulations! " .. (newStud and newStud.name or "?") .. "!"
		evoText.TextColor3 = Color3.fromRGB(255, 200, 50)

		local flashOut = TweenService:Create(evoOverlay, TweenInfo.new(1.0, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		})
		flashOut:Play()
		flashOut.Completed:Wait()

		evoOverlay.Visible = false
		evoText.TextColor3 = Color3.fromRGB(255, 220, 100)

		-- Refresh data
		refreshData()
	else
		-- Show error notification
		local reason = result and result.reason or "unknown"
		local msg = "Evolution failed!"
		if reason == "insufficient_points" then
			msg = "Not enough EvoPoints! Need " .. tostring(result.cost) .. ", have " .. tostring(result.current)
		elseif reason == "max_evolved" then
			msg = "This Stud is already at max evolution!"
		elseif reason == "not_owned" then
			msg = "You don't own this Stud!"
		end

		local notif = Instance.new("TextLabel")
		notif.Size = UDim2.new(0.4, 0, 0, 40)
		notif.Position = UDim2.new(0.3, 0, 0.85, 0)
		notif.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
		notif.TextColor3 = Color3.fromRGB(255, 150, 150)
		notif.Text = msg
		notif.Font = Enum.Font.GothamBold
		notif.TextSize = 13
		notif.ZIndex = 50
		notif.Parent = screenGui



		task.delay(2.5, function()
			if notif then notif:Destroy() end
		end)
	end

	isAnimating = false
end

-- Refresh data from server
function refreshData()
	-- Get evoPoints
	local ok1, points = pcall(function()
		return StudEvents.RequestEvoPoints:InvokeServer()
	end)
	if ok1 then
		evoPoints = points or {}
	end

	-- Get collection
	local ok2, coll = pcall(function()
		return StudEvents.RequestCollection:InvokeServer()
	end)
	if ok2 then
		collection = coll or {}
	end

	-- Build owned set
	local ownedIds = {}
	for _, caught in ipairs(collection) do
		local id = type(caught) == "table" and caught.id or caught
		if id then ownedIds[id] = true end
	end

	-- Update UI
	for typeName, rowData in pairs(chainRows) do
		-- Update points label
		local pts = evoPoints[typeName] or 0
		rowData.pointsLabel.Text = tostring(pts) .. " EvoPoints"
		rowData.pointsLabel.TextColor3 = pts > 0 and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(200, 200, 220)

		-- Update stud slots
		for studId, slot in pairs(rowData.studSlots) do
			local stud = StudData.GetStudById(studId)
			local isOwned = ownedIds[studId]
			local canEvolve = StudData.GetEvolution(studId) ~= nil
			local evoCost = StudData.GetEvolutionCost(studId)
			local hasPoints = evoCost and (evoPoints[typeName] or 0) >= evoCost

			if isOwned then
				slot.statusLabel.Text = "Owned"
				slot.statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
				slot.tile.BackgroundColor3 = Color3.fromRGB(35, 45, 55)
				slot.tileStroke.Transparency = 0

				if canEvolve and hasPoints then
					slot.evolveBtn.Visible = true
					slot.evolveBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
				elseif canEvolve and not hasPoints then
					slot.evolveBtn.Visible = true
					slot.evolveBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
					slot.evolveBtn.Text = "Need " .. tostring(evoCost) .. " pts"
				else
					slot.evolveBtn.Visible = false
				end
			else
				slot.statusLabel.Text = "???"
				slot.statusLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
				slot.tile.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
				slot.tileStroke.Transparency = 0.7
				slot.evolveBtn.Visible = false
			end
		end
	end
end

-- Open/close functions
local function openEvoUI()
	screenGui.Enabled = true
	mainFrame.Size = UDim2.new(0, 0, 0, 0)
	mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

	local tweenIn = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 520, 0, 480),
		Position = UDim2.new(0.5, -260, 0.5, -240)
	})
	tweenIn:Play()

	refreshData()
end

local function closeEvoUI()
	local tweenOut = TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		Position = UDim2.new(0.5, 0, 0.5, 0)
	})
	tweenOut:Play()
	tweenOut.Completed:Connect(function()
		screenGui.Enabled = false
	end)
end

closeBtn.MouseButton1Click:Connect(closeEvoUI)

-- Keyboard shortcut removed (E key now opens Inventory)
-- Can still open via BuildingInteractions attribute or close with Escape
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
		closeEvoUI()
	end
end)

-- Listen for open attribute from BuildingInteractions
player:GetAttributeChangedSignal("OpenEvolution"):Connect(function()
	if player:GetAttribute("OpenEvolution") then
		openEvoUI()
		player:SetAttribute("OpenEvolution", false)
	end
end)

-- Listen for evolution results from server
StudEvents.EvolutionResult.OnClientEvent:Connect(function(oldStudId, newStudId, success)
	if success then
		refreshData()
	end
end)

print("[EvolutionUI] Initialized")