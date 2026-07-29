local LabUI = {}

-- Stud Lab research interface
-- Shows collection progress by type, research tips, evolution, and Stud type info

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:FindFirstChild("StudEvents")
local StudData = require(ReplicatedStorage:FindFirstChild("StudData"))

-- Type info
local typeInfo = {
    Fire = {color = Color3.fromRGB(255, 80, 60), desc = "Hot-headed and powerful. Found in rocky volcanic areas."},
    Water = {color = Color3.fromRGB(60, 140, 255), desc = "Calm and adaptable. Found near shores and rivers."},
    Grass = {color = Color3.fromRGB(80, 200, 80), desc = "Resilient and nurturing. Found in meadows and forests."},
    Electric = {color = Color3.fromRGB(255, 230, 50), desc = "Fast and shocking. Found in open fields during storms."},
    Rock = {color = Color3.fromRGB(160, 140, 120), desc = "Sturdy and enduring. Found in mountain ridges."},
    Ice = {color = Color3.fromRGB(150, 220, 255), desc = "Cool and precise. Found in cold, frosty areas."},
    Shadow = {color = Color3.fromRGB(100, 60, 160), desc = "Mysterious and elusive. Only appears at night."},
}

-- Research tips that rotate
local researchTips = {
    "Each zone has 2 Stud types. Explore all zones to catch them all!",
    "Rare Studs are harder to catch but worth more coins.",
    "Legendary Studs appear only 3% of the time. Keep searching!",
    "Selling duplicate Studs at the Shop earns you coins.",
    "Visit the Stud Center to heal and prevent encounters temporarily.",
    "Rest at home for a small coin bonus and healing.",
    "Catch streaks give bonus excitement - try to chain catches!",
    "Weather changes affect the atmosphere. Some Studs may prefer certain conditions.",
    "The catch minigame gets harder if you fail. Stay focused!",
    "Check your StudDex with C to track your collection progress.",
    "Catch duplicate studs to earn Evo Points for evolution!",
    "Evolve your studs at the Lab to unlock higher rarity forms!",
}

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LabUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false

-- Main frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 560, 0, 500)
mainFrame.Position = UDim2.new(0.5, -280, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui



local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(80, 80, 120)
mainStroke.Thickness = 2
mainStroke.Parent = mainFrame

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 50)
titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame



local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "\240\159\148\172 Stud Research Lab"
titleLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Font = Enum.Font.Arcade
titleLabel.TextSize = 20
titleLabel.Parent = titleBar

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "CloseBtn"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -43, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.Text = "\226\156\149"
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Font = Enum.Font.Arcade
closeBtn.TextSize = 18
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar



-- Content area (scrollable)
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "Content"
scrollFrame.Size = UDim2.new(1, -20, 1, -65)
scrollFrame.Position = UDim2.new(0, 10, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 140)
scrollFrame.BorderSizePixel = 0
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = scrollFrame

-- Section: Collection by Type
local typeSectionLabel = Instance.new("TextLabel")
typeSectionLabel.Name = "TypeSectionLabel"
typeSectionLabel.Size = UDim2.new(1, 0, 0, 25)
typeSectionLabel.BackgroundTransparency = 1
typeSectionLabel.Text = "Collection by Type"
typeSectionLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
typeSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
typeSectionLabel.Font = Enum.Font.Arcade
typeSectionLabel.TextSize = 16
typeSectionLabel.LayoutOrder = 1
typeSectionLabel.Parent = scrollFrame

-- Type rows
local typeRows = {}
local typeOrder = {"Fire", "Water", "Grass", "Electric", "Rock", "Ice", "Shadow"}

for i, typeName in ipairs(typeOrder) do
    local info = typeInfo[typeName]
    if not info then continue end

    local row = Instance.new("Frame")
    row.Name = typeName .. "Row"
    row.Size = UDim2.new(1, 0, 0, 55)
    row.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    row.BorderSizePixel = 0
    row.LayoutOrder = i + 1
    row.Parent = scrollFrame


    local colorBar = Instance.new("Frame")
    colorBar.Name = "ColorBar"
    colorBar.Size = UDim2.new(0, 4, 1, -8)
    colorBar.Position = UDim2.new(0, 4, 0, 4)
    colorBar.BackgroundColor3 = info.color
    colorBar.BorderSizePixel = 0
    colorBar.Parent = row

    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "TypeName"
    nameLabel.Size = UDim2.new(0, 80, 0, 20)
    nameLabel.Position = UDim2.new(0, 16, 0, 5)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = typeName
    nameLabel.TextColor3 = info.color
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Font = Enum.Font.Arcade
    nameLabel.TextSize = 14
    nameLabel.Parent = row

    local progressBg = Instance.new("Frame")
    progressBg.Name = "ProgressBg"
    progressBg.Size = UDim2.new(1, -110, 0, 10)
    progressBg.Position = UDim2.new(0, 100, 0, 8)
    progressBg.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
    progressBg.BorderSizePixel = 0
    progressBg.Parent = row


    local progressFill = Instance.new("Frame")
    progressFill.Name = "ProgressFill"
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = info.color
    progressFill.BorderSizePixel = 0
    progressFill.Parent = progressBg


    local countLabel = Instance.new("TextLabel")
    countLabel.Name = "Count"
    countLabel.Size = UDim2.new(0, 60, 0, 20)
    countLabel.Position = UDim2.new(1, -60, 0, 5)
    countLabel.BackgroundTransparency = 1
    countLabel.Text = "0/4"
    countLabel.TextColor3 = Color3.fromRGB(200, 200, 220)
    countLabel.Font = Enum.Font.Arcade
    countLabel.TextSize = 12
    countLabel.Parent = row

    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Desc"
    descLabel.Size = UDim2.new(1, -20, 0, 20)
    descLabel.Position = UDim2.new(0, 16, 0, 28)
    descLabel.BackgroundTransparency = 1
    descLabel.Text = info.desc
    descLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
    descLabel.TextXAlignment = Enum.TextXAlignment.Left
    descLabel.Font = Enum.Font.Arcade
    descLabel.TextSize = 11
    descLabel.TextTruncate = Enum.TextTruncate.AtEnd
    descLabel.Parent = row

    typeRows[typeName] = {
        row = row,
        progressFill = progressFill,
        countLabel = countLabel
    }
end

-- Section: Research Tips
local tipSectionLabel = Instance.new("TextLabel")
tipSectionLabel.Name = "TipSectionLabel"
tipSectionLabel.Size = UDim2.new(1, 0, 0, 25)
tipSectionLabel.BackgroundTransparency = 1
tipSectionLabel.Text = "Research Tips"
tipSectionLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
tipSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
tipSectionLabel.Font = Enum.Font.Arcade
tipSectionLabel.TextSize = 16
tipSectionLabel.LayoutOrder = 10
tipSectionLabel.Parent = scrollFrame

local tipFrame = Instance.new("Frame")
tipFrame.Name = "TipFrame"
tipFrame.Size = UDim2.new(1, 0, 0, 50)
tipFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
tipFrame.BorderSizePixel = 0
tipFrame.LayoutOrder = 11
tipFrame.Parent = scrollFrame


local tipLabel = Instance.new("TextLabel")
tipLabel.Name = "TipText"
tipLabel.Size = UDim2.new(1, -20, 1, -10)
tipLabel.Position = UDim2.new(0, 10, 0, 5)
tipLabel.BackgroundTransparency = 1
tipLabel.Text = researchTips[1]
tipLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
tipLabel.TextWrapped = true
tipLabel.Font = Enum.Font.Arcade
tipLabel.TextSize = 13
tipLabel.TextXAlignment = Enum.TextXAlignment.Left
tipLabel.TextYAlignment = Enum.TextYAlignment.Top
tipLabel.Parent = tipFrame

local nextTipBtn = Instance.new("TextButton")
nextTipBtn.Name = "NextTipBtn"
nextTipBtn.Size = UDim2.new(0, 80, 0, 24)
nextTipBtn.Position = UDim2.new(1, -90, 0, -30)
nextTipBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 90)
nextTipBtn.Text = "Next Tip"
nextTipBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
nextTipBtn.Font = Enum.Font.Arcade
nextTipBtn.TextSize = 11
nextTipBtn.BorderSizePixel = 0
nextTipBtn.Parent = tipFrame


local currentTipIndex = 1

nextTipBtn.MouseButton1Click:Connect(function()
    currentTipIndex = (currentTipIndex % #researchTips) + 1
    tipLabel.Text = researchTips[currentTipIndex]
end)

-- Overall progress section
local overallSectionLabel = Instance.new("TextLabel")
overallSectionLabel.Name = "OverallSectionLabel"
overallSectionLabel.Size = UDim2.new(1, 0, 0, 25)
overallSectionLabel.BackgroundTransparency = 1
overallSectionLabel.Text = "Overall Progress"
overallSectionLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
overallSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
overallSectionLabel.Font = Enum.Font.Arcade
overallSectionLabel.TextSize = 16
overallSectionLabel.LayoutOrder = 12
overallSectionLabel.Parent = scrollFrame

local overallFrame = Instance.new("Frame")
overallFrame.Name = "OverallFrame"
overallFrame.Size = UDim2.new(1, 0, 0, 40)
overallFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
overallFrame.BorderSizePixel = 0
overallFrame.LayoutOrder = 13
overallFrame.Parent = scrollFrame


local overallLabel = Instance.new("TextLabel")
overallLabel.Name = "OverallText"
overallLabel.Size = UDim2.new(1, -20, 1, 0)
overallLabel.Position = UDim2.new(0, 10, 0, 0)
overallLabel.BackgroundTransparency = 1
overallLabel.Text = "0 / 24 Studs Discovered (0%)"
overallLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
overallLabel.Font = Enum.Font.Arcade
overallLabel.TextSize = 14
overallLabel.TextXAlignment = Enum.TextXAlignment.Left
overallLabel.Parent = overallFrame

-- ===== EVOLUTION SECTION =====
local evoSectionLabel = Instance.new("TextLabel")
evoSectionLabel.Name = "EvoSectionLabel"
evoSectionLabel.Size = UDim2.new(1, 0, 0, 25)
evoSectionLabel.BackgroundTransparency = 1
evoSectionLabel.Text = "Evolution Lab"
evoSectionLabel.TextColor3 = Color3.fromRGB(200, 160, 255)
evoSectionLabel.TextXAlignment = Enum.TextXAlignment.Left
evoSectionLabel.Font = Enum.Font.Arcade
evoSectionLabel.TextSize = 16
evoSectionLabel.LayoutOrder = 20
evoSectionLabel.Parent = scrollFrame

local evoInfoLabel = Instance.new("TextLabel")
evoInfoLabel.Name = "EvoInfo"
evoInfoLabel.Size = UDim2.new(1, 0, 0, 30)
evoInfoLabel.BackgroundTransparency = 1
evoInfoLabel.Text = "Catch duplicate studs to earn Evo Points! Spend them here to evolve your studs to the next tier."
evoInfoLabel.TextColor3 = Color3.fromRGB(140, 140, 160)
evoInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
evoInfoLabel.Font = Enum.Font.Arcade
evoInfoLabel.TextSize = 11
evoInfoLabel.TextWrapped = true
evoInfoLabel.LayoutOrder = 21
evoInfoLabel.Parent = scrollFrame

local evoContainer = Instance.new("Frame")
evoContainer.Name = "EvoContainer"
evoContainer.Size = UDim2.new(1, 0, 0, 0)
evoContainer.BackgroundTransparency = 1
evoContainer.AutomaticSize = Enum.AutomaticSize.Y
evoContainer.LayoutOrder = 22
evoContainer.Parent = scrollFrame

local evoLayout = Instance.new("UIListLayout")
evoLayout.SortOrder = Enum.SortOrder.LayoutOrder
evoLayout.Padding = UDim.new(0, 6)
evoLayout.Parent = evoContainer

local evoRows = {}
local evoRowOrder = 0

for _, typeName in ipairs(typeOrder) do
    local info = typeInfo[typeName]
    if not info then continue end
    local chain = StudData.EvolutionChains[typeName]
    if not chain then continue end

    evoRowOrder = evoRowOrder + 1

    local row = Instance.new("Frame")
    row.Name = typeName .. "EvoRow"
    row.Size = UDim2.new(1, 0, 0, 70)
    row.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    row.BorderSizePixel = 0
    row.LayoutOrder = evoRowOrder
    row.Parent = evoContainer


    local colorBar = Instance.new("Frame")
    colorBar.Size = UDim2.new(0, 4, 1, -8)
    colorBar.Position = UDim2.new(0, 4, 0, 4)
    colorBar.BackgroundColor3 = info.color
    colorBar.BorderSizePixel = 0
    colorBar.Parent = row

    local typeLabel = Instance.new("TextLabel")
    typeLabel.Name = "TypeLabel"
    typeLabel.Size = UDim2.new(0, 150, 0, 18)
    typeLabel.Position = UDim2.new(0, 14, 0, 4)
    typeLabel.BackgroundTransparency = 1
    typeLabel.Text = typeName .. "  |  0 pts"
    typeLabel.TextColor3 = info.color
    typeLabel.TextXAlignment = Enum.TextXAlignment.Left
    typeLabel.Font = Enum.Font.Arcade
    typeLabel.TextSize = 12
    typeLabel.Parent = row

    local chainFrame = Instance.new("Frame")
    chainFrame.Name = "ChainFrame"
    chainFrame.Size = UDim2.new(1, -20, 0, 22)
    chainFrame.Position = UDim2.new(0, 14, 0, 24)
    chainFrame.BackgroundTransparency = 1
    chainFrame.Parent = row

    local chainLayout = Instance.new("UIListLayout")
    chainLayout.FillDirection = Enum.FillDirection.Horizontal
    chainLayout.Padding = UDim.new(0, 4)
    chainLayout.SortOrder = Enum.SortOrder.LayoutOrder
    chainLayout.Parent = chainFrame

    local chainLabels = {}
    for i, studId in ipairs(chain) do
        local studData = StudData.GetStudById(studId)
        if not studData then continue end

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0, 70, 1, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = studData.name
        nameLabel.TextColor3 = Color3.fromRGB(100, 100, 120)
        nameLabel.Font = Enum.Font.Arcade
        nameLabel.TextSize = 10
        nameLabel.LayoutOrder = i * 2 - 1
        nameLabel.Parent = chainFrame

        chainLabels[studId] = nameLabel

        if i < #chain then
            local arrow = Instance.new("TextLabel")
            arrow.Size = UDim2.new(0, 14, 1, 0)
            arrow.BackgroundTransparency = 1
            arrow.Text = "->"
            arrow.TextColor3 = Color3.fromRGB(80, 80, 100)
            arrow.Font = Enum.Font.Arcade
            arrow.TextSize = 12
            arrow.LayoutOrder = i * 2
            arrow.Parent = chainFrame
        end
    end

    local evolveBtn = Instance.new("TextButton")
    evolveBtn.Name = "EvolveBtn"
    evolveBtn.Size = UDim2.new(0, 90, 0, 22)
    evolveBtn.Position = UDim2.new(1, -100, 0, 46)
    evolveBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 80)
    evolveBtn.Text = "Evolve"
    evolveBtn.TextColor3 = Color3.fromRGB(180, 140, 220)
    evolveBtn.Font = Enum.Font.Arcade
    evolveBtn.TextSize = 11
    evolveBtn.BorderSizePixel = 0
    evolveBtn.Visible = false
    evolveBtn.Parent = row



    local evoInfo = Instance.new("TextLabel")
    evoInfo.Name = "EvoInfo"
    evoInfo.Size = UDim2.new(1, -110, 0, 22)
    evoInfo.Position = UDim2.new(0, 14, 0, 46)
    evoInfo.BackgroundTransparency = 1
    evoInfo.Text = ""
    evoInfo.TextColor3 = Color3.fromRGB(140, 140, 160)
    evoInfo.TextXAlignment = Enum.TextXAlignment.Left
    evoInfo.Font = Enum.Font.Arcade
    evoInfo.TextSize = 10
    evoInfo.Parent = row

    evoRows[typeName] = {
        row = row,
        typeLabel = typeLabel,
        chainLabels = chainLabels,
        evolveBtn = evolveBtn,
        evoInfo = evoInfo,
        chain = chain,
    }
end

screenGui.Parent = playerGui

-- ===== UPDATE DATA =====
local function updateLabData()
    local success, collection = pcall(function()
        return StudEvents.RequestCollection:InvokeServer()
    end)

    if not success or not collection then return end

    local typeCounts = {}
    for _, typeName in ipairs(typeOrder) do
        typeCounts[typeName] = 0
    end

    local uniqueIds = {}
    local totalUnique = 0

    for _, caught in ipairs(collection) do
        local studId = caught.id
        if studId and not uniqueIds[studId] then
            uniqueIds[studId] = true
            totalUnique = totalUnique + 1
            local stud = StudData.GetStudById(studId)
            if stud then
                typeCounts[stud.studType] = (typeCounts[stud.studType] or 0) + 1
            end
        end
    end

    for _, typeName in ipairs(typeOrder) do
        local rowData = typeRows[typeName]
        if rowData then
            local caught = typeCounts[typeName] or 0
            local total = 4
            rowData.countLabel.Text = caught .. "/" .. total
            rowData.progressFill.Size = UDim2.new(caught / total, 0, 1, 0)
        end
    end

    overallLabel.Text = totalUnique .. " / 24 Studs Discovered (" .. math.floor(totalUnique / 24 * 100) .. "%)"

    -- ===== UPDATE EVOLUTION SECTION =====
    local statsSuccess, stats = pcall(function()
        return StudEvents.GetPlayerStats:InvokeServer()
    end)
    local evoPoints = (statsSuccess and stats) and (stats.evoPoints or {}) or {}

    local ownedIds = {}
    for _, caught in ipairs(collection) do
        ownedIds[caught.id] = true
    end

    for _, typeName in ipairs(typeOrder) do
        local rowData = evoRows[typeName]
        if not rowData then continue end

        local points = evoPoints[typeName] or 0
        local info = typeInfo[typeName]
        rowData.typeLabel.Text = typeName .. "  |  " .. points .. " pts"

        for studId, label in pairs(rowData.chainLabels) do
            if ownedIds[studId] then
                local studData = StudData.GetStudById(studId)
                local rarityColor = studData and StudData.Rarity[studData.rarity]
                if rarityColor then
                    label.TextColor3 = rarityColor.color
                else
                    label.TextColor3 = Color3.fromRGB(200, 200, 220)
                end
            else
                label.TextColor3 = Color3.fromRGB(80, 80, 100)
            end
        end

        local canEvolveId = nil
        local evolveCost = nil
        for _, studId in ipairs(rowData.chain) do
            if ownedIds[studId] then
                local evo = StudData.GetEvolution(studId)
                if evo then
                    canEvolveId = studId
                    evolveCost = StudData.GetEvolutionCost(studId)
                    break
                end
            end
        end

        if canEvolveId and evolveCost then
            local studData = StudData.GetStudById(canEvolveId)
            local evo = StudData.GetEvolution(canEvolveId)
            rowData.evoInfo.Text = studData.name .. " -> " .. evo.name .. " (" .. evolveCost .. " pts)"
            rowData.evoInfo.TextColor3 = Color3.fromRGB(140, 140, 160)
            rowData.evolveBtn.Visible = true

            if points >= evolveCost then
                rowData.evolveBtn.BackgroundColor3 = Color3.fromRGB(80, 50, 140)
                rowData.evolveBtn.TextColor3 = Color3.fromRGB(220, 180, 255)
                rowData.evolveBtn.Text = "Evolve!"
            else
                rowData.evolveBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 50)
                rowData.evolveBtn.TextColor3 = Color3.fromRGB(100, 90, 120)
                rowData.evolveBtn.Text = "Need " .. (evolveCost - points) .. " more"
            end

            rowData.evolveBtn:SetAttribute("EvolveTarget", canEvolveId)
        else
            local allOwned = true
            for _, studId in ipairs(rowData.chain) do
                if not ownedIds[studId] then
                    allOwned = false
                    break
                end
            end
            if allOwned then
                rowData.evoInfo.Text = "Chain complete!"
                rowData.evoInfo.TextColor3 = Color3.fromRGB(255, 220, 100)
            else
                rowData.evoInfo.Text = "Catch studs of this type to start evolving!"
                rowData.evoInfo.TextColor3 = Color3.fromRGB(140, 140, 160)
            end
            rowData.evolveBtn.Visible = false
        end
    end
end

-- ===== OPEN/CLOSE =====
local function openLab()
    screenGui.Enabled = true
    mainFrame.Scale = UDim2.new(0, 0, 0, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)

    TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, 560, 0, 500),
        Position = UDim2.new(0.5, -280, 0.5, -250)
    }):Play()

    updateLabData()
end

local function closeLab()
    TweenService:Create(mainFrame, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        Position = UDim2.new(0.5, 0, 0.5, 0)
    }):Play()

    task.delay(0.2, function()
        screenGui.Enabled = false
    end)
end

closeBtn.MouseButton1Click:Connect(closeLab)

-- Handle evolve button clicks
for typeName, rowData in pairs(evoRows) do
    rowData.evolveBtn.MouseButton1Click:Connect(function()
        -- Despite the name, this holds the species being evolved FROM, which
        -- is what EvolveStud expects as its first argument. The optional
        -- second argument is the branch to evolve into; the Lab never
        -- branches, so it is omitted and the server picks the default path.
        local targetId = rowData.evolveBtn:GetAttribute("EvolveTarget")
        if not targetId then return end

        rowData.evolveBtn.Text = "Evolving..."
        rowData.evolveBtn.BackgroundColor3 = Color3.fromRGB(40, 35, 50)

        local success, result = pcall(function()
            return StudEvents.EvolveStud:InvokeServer(targetId)
        end)

        if success and result and result.success then
            local notif = Instance.new("Frame")
            notif.Name = "EvoSuccess"
            notif.Size = UDim2.new(0, 300, 0, 60)
            notif.Position = UDim2.new(0.5, -150, 0.3, 0)
            notif.BackgroundColor3 = Color3.fromRGB(40, 20, 70)
            notif.BackgroundTransparency = 0.05
            notif.BorderSizePixel = 0
            notif.ZIndex = 30
            notif.Parent = screenGui



            local nStroke = Instance.new("UIStroke")
            nStroke.Color = Color3.fromRGB(180, 100, 255)
            nStroke.Thickness = 2
            nStroke.Parent = notif

            local titleLbl = Instance.new("TextLabel")
            titleLbl.Size = UDim2.new(1, 0, 0, 24)
            titleLbl.Position = UDim2.new(0, 0, 0, 6)
            titleLbl.BackgroundTransparency = 1
            titleLbl.Text = "Evolution Success!"
            titleLbl.TextColor3 = Color3.fromRGB(220, 180, 255)
            titleLbl.Font = Enum.Font.Arcade
            titleLbl.TextSize = 16
            titleLbl.ZIndex = 31
            titleLbl.Parent = notif

            local detailLbl = Instance.new("TextLabel")
            detailLbl.Size = UDim2.new(1, 0, 0, 20)
            detailLbl.Position = UDim2.new(0, 0, 0, 32)
            detailLbl.BackgroundTransparency = 1
            local oldStud = StudData.GetStudById(result.oldStud)
            detailLbl.Text = (oldStud and oldStud.name or "?") .. " evolved into " .. (result.newName or "?") .. "!"
            detailLbl.TextColor3 = Color3.fromRGB(180, 160, 220)
            detailLbl.Font = Enum.Font.Arcade
            detailLbl.TextSize = 13
            detailLbl.ZIndex = 31
            detailLbl.Parent = notif

            notif.Position = UDim2.new(0.5, -150, -0.15, 0)
            TweenService:Create(notif, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Position = UDim2.new(0.5, -150, 0.3, 0)
            }):Play()

            task.delay(3, function()
                TweenService:Create(notif, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
                    Position = UDim2.new(0.5, -150, -0.15, 0),
                    BackgroundTransparency = 1
                }):Play()
                task.delay(0.5, function()
                    if notif then notif:Destroy() end
                end)
            end)

            task.delay(0.5, updateLabData)
        else
            rowData.evolveBtn.Text = "Failed!"
            task.delay(1, updateLabData)
        end
    end)
end

-- Listen for Lab open attribute
player:GetAttributeChangedSignal("OpenLab"):Connect(function()
    if player:GetAttribute("OpenLab") then
        openLab()
    end
end)

-- Close on ESC
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Escape and screenGui.Enabled then
        closeLab()
    end
end)



-- Stud Lab research interface