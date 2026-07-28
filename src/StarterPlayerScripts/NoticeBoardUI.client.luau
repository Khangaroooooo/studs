-- NoticeBoardUI: Shows game tips when interacting with the Notice Board

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local TIPS = {
	"Walk in tall grass to encounter wild Studs!",
	"Tap the circles quickly during the catching minigame!",
	"Sell duplicate Studs at the Shop for coins.",
	"Heal up at the Stud Center between encounters.",
	"Make a wish at the Wishing Well for bonus coins!",
	"Press Q to open your Quest log.",
	"Press E to view your StudDex collection.",
	"Hold Shift to sprint around town faster.",
	"Type effectiveness matters in encounters!",
	"Fire beats Grass, Grass beats Water, Water beats Fire.",
	"Electric Studs are strong against Water types.",
	"Rock Studs resist Electric attacks.",
	"Ice Studs appear more at night in the south grass.",
	"Legendary Studs are very rare - keep trying!",
	"Catch streaks give bonus coin rewards!",
	"Visit Professor Brick in the Lab for research.",
	"Check the Shop for catching supplies!",
	"Rest at home for a small coin bonus.",
}

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NoticeBoardUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

-- Main Frame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 350)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -175)
mainFrame.BackgroundColor3 = Color3.fromRGB(210, 180, 130)
mainFrame.BorderSizePixel = 0
mainFrame.Visible = false
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui



local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(120, 80, 40)
mainStroke.Thickness = 3
mainStroke.Parent = mainFrame

-- Header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
header.BorderSizePixel = 0
header.Parent = mainFrame



local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 12)
headerFix.Position = UDim2.new(0, 0, 1, -12)
headerFix.BackgroundColor3 = Color3.fromRGB(120, 80, 40)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -50, 1, 0)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 230, 180)
titleLabel.TextSize = 22
titleLabel.Font = Enum.Font.Arcade
titleLabel.Text = "📌 Studville Tips"
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = header

-- Close button
local closeBtn = Instance.new("TextButton")
closeBtn.Text = "X"
closeBtn.Size = UDim2.new(0, 36, 0, 36)
closeBtn.Position = UDim2.new(1, -44, 0, 7)
closeBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 40)
closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
closeBtn.TextSize = 18
closeBtn.Font = Enum.Font.Arcade
closeBtn.BorderSizePixel = 0
closeBtn.Parent = header



-- Scroll frame for tips
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -60)
scrollFrame.Position = UDim2.new(0, 10, 0, 55)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 4
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(120, 80, 40)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = scrollFrame

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 4)
padding.PaddingBottom = UDim.new(0, 4)
padding.Parent = scrollFrame

-- Populate tips
for i, tip in ipairs(TIPS) do
	local tipFrame = Instance.new("Frame")
	tipFrame.Size = UDim2.new(1, 0, 0, 28)
	tipFrame.BackgroundColor3 = Color3.fromRGB(230, 210, 170)
	tipFrame.BorderSizePixel = 0
	tipFrame.LayoutOrder = i
	tipFrame.Parent = scrollFrame



	local tipLabel = Instance.new("TextLabel")
	tipLabel.Size = UDim2.new(1, -12, 1, 0)
	tipLabel.Position = UDim2.new(0, 6, 0, 0)
	tipLabel.BackgroundTransparency = 1
	tipLabel.TextColor3 = Color3.fromRGB(60, 40, 20)
	tipLabel.TextSize = 13
	tipLabel.Font = Enum.Font.Arcade
	tipLabel.Text = "- " .. tip
	tipLabel.TextXAlignment = Enum.TextXAlignment.Left
	tipLabel.TextTruncate = Enum.TextTruncate.AtEnd
	tipLabel.Parent = tipFrame
end

-- Toggle logic
local isOpen = false

local function toggleUI()
	isOpen = not isOpen
	if isOpen then
		mainFrame.Visible = true
		mainFrame.BackgroundTransparency = 1
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			BackgroundTransparency = 0
		})
		tween:Play()
	else
		local tween = TweenService:Create(mainFrame, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			BackgroundTransparency = 1
		})
		tween:Play()
		tween.Completed:Connect(function()
			mainFrame.Visible = false
		end)
	end
end

closeBtn.MouseButton1Click:Connect(function()
	if isOpen then toggleUI() end
end)

-- Listen for Notice Board prompt
local function setupNoticeBoard()
	local studville = workspace:FindFirstChild("Studville")
	if not studville then return end

	local noticeBoard = studville:FindFirstChild("NoticeBoard")
	if not noticeBoard then return end

	local prompt = noticeBoard:FindFirstChild("NoticePrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function()
		if not isOpen then
			toggleUI()
		end
	end)
end

-- Wait for game to load
task.delay(2, setupNoticeBoard)

print("[NoticeBoardUI] Initialized")