local WishNotification = {}

-- Shows wish result notification when player uses the Wishing Well

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WishNotification"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Wish notification frame
local notifFrame = Instance.new("Frame")
notifFrame.Name = "WishNotif"
notifFrame.Size = UDim2.new(0, 280, 0, 60)
notifFrame.Position = UDim2.new(0.5, -140, 0.3, 0)
notifFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
notifFrame.BackgroundTransparency = 0.2
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
notifFrame.Parent = screenGui



local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(100, 150, 255)
notifStroke.Thickness = 1.5
notifStroke.Transparency = 0.3
notifStroke.Parent = notifFrame

local notifIcon = Instance.new("TextLabel")
notifIcon.Name = "Icon"
notifIcon.Size = UDim2.new(0, 50, 1, 0)
notifIcon.Position = UDim2.new(0, 5, 0, 0)
notifIcon.BackgroundTransparency = 1
notifIcon.Text = "⭐"
notifIcon.TextScaled = true
notifIcon.Parent = notifFrame

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "Label"
notifLabel.Size = UDim2.new(1, -60, 1, 0)
notifLabel.Position = UDim2.new(0, 55, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = "Your wish came true!"
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextXAlignment = Enum.TextXAlignment.Left
notifLabel.Font = Enum.Font.Arcade
notifLabel.TextSize = 14
notifLabel.TextWrapped = true
notifLabel.Parent = notifFrame

screenGui.Parent = playerGui

-- Wish result messages
local wishMessages = {
    jackpot = {icon = "💎", text = "JACKPOT! +100 coins!", color = Color3.fromRGB(255, 100, 255)},
    lucky = {icon = "⭐", text = "Lucky wish! +50 coins!", color = Color3.fromRGB(255, 220, 50)},
    nice = {icon = "✨", text = "Nice wish! +25 coins!", color = Color3.fromRGB(100, 200, 255)},
    small = {icon = "💧", text = "Small wish... +10 coins", color = Color3.fromRGB(150, 180, 200)},
    none = {icon = "🌊", text = "The well ripples quietly...", color = Color3.fromRGB(120, 120, 140)}
}

local function showWishResult(result)
    local info = wishMessages[result]
    if not info then return end
    
    notifIcon.Text = info.icon
    notifLabel.Text = info.text
    notifLabel.TextColor3 = info.color
    notifStroke.Color = info.color
    
    -- Animate in
    notifFrame.Visible = true
    notifFrame.BackgroundTransparency = 1
    notifFrame.Position = UDim2.new(0.5, -140, 0.3, -20)
    
    TweenService:Create(notifFrame, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.2,
        Position = UDim2.new(0.5, -140, 0.3, 0)
    }):Play()
    
    -- Animate out after 3 seconds
    task.delay(3, function()
        TweenService:Create(notifFrame, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -140, 0.3, -20)
        }):Play()
        
        task.delay(0.6, function()
            notifFrame.Visible = false
        end)
    end)
end

-- Listen for WishResult attribute
player:GetAttributeChangedSignal("WishResult"):Connect(function()
    local result = player:GetAttribute("WishResult")
    if result then
        showWishResult(result)
    end
end)

print("[WishNotification] Initialized")