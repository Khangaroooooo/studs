if true then return end -- [Disabled] WeatherDisplay removed per user request

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Weather display data
local weatherInfo = {
    ["Clear"] = {icon = "☀️", label = "Clear Skies", color = Color3.fromRGB(255, 220, 100)},
    ["Cloudy"] = {icon = "☁️", label = "Cloudy", color = Color3.fromRGB(160, 165, 175)},
    ["Rain"] = {icon = "🌧️", label = "Rainy", color = Color3.fromRGB(100, 140, 200)},
    ["Fog"] = {icon = "🌫️", label = "Foggy", color = Color3.fromRGB(180, 185, 195)}
}

-- Create ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "WeatherDisplay"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Weather notification (appears on change, fades out)
local notifFrame = Instance.new("Frame")
notifFrame.Name = "WeatherNotif"
notifFrame.Size = UDim2.new(0, 250, 0, 50)
notifFrame.Position = UDim2.new(0.5, -125, 0.15, 0)
notifFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
notifFrame.BackgroundTransparency = 0.3
notifFrame.BorderSizePixel = 0
notifFrame.Visible = false
notifFrame.Parent = screenGui



local notifStroke = Instance.new("UIStroke")
notifStroke.Color = Color3.fromRGB(100, 100, 120)
notifStroke.Thickness = 1
notifStroke.Transparency = 0.5
notifStroke.Parent = notifFrame

local notifIcon = Instance.new("TextLabel")
notifIcon.Name = "Icon"
notifIcon.Size = UDim2.new(0, 40, 1, 0)
notifIcon.Position = UDim2.new(0, 8, 0, 0)
notifIcon.BackgroundTransparency = 1
notifIcon.Text = "☀️"
notifIcon.TextScaled = true
notifIcon.Parent = notifFrame

local notifLabel = Instance.new("TextLabel")
notifLabel.Name = "Label"
notifLabel.Size = UDim2.new(1, -56, 1, 0)
notifLabel.Position = UDim2.new(0, 48, 0, 0)
notifLabel.BackgroundTransparency = 1
notifLabel.Text = "Clear Skies"
notifLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
notifLabel.TextXAlignment = Enum.TextXAlignment.Left
notifLabel.Font = Enum.Font.Arcade
notifLabel.TextSize = 16
notifLabel.Parent = notifFrame

-- Current weather indicator (small, always visible in top-right area)
local indicatorFrame = Instance.new("Frame")
indicatorFrame.Name = "WeatherIndicator"
indicatorFrame.Size = UDim2.new(0, 36, 0, 36)
indicatorFrame.Position = UDim2.new(1, -46, 0, 50)
indicatorFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
indicatorFrame.BackgroundTransparency = 0.4
indicatorFrame.BorderSizePixel = 0
indicatorFrame.Parent = screenGui



local indicatorIcon = Instance.new("TextLabel")
indicatorIcon.Name = "Icon"
indicatorIcon.Size = UDim2.new(1, 0, 1, 0)
indicatorIcon.BackgroundTransparency = 1
indicatorIcon.Text = "☀️"
indicatorIcon.TextScaled = true
indicatorIcon.Parent = indicatorFrame

screenGui.Parent = playerGui

-- ===== NOTIFICATION ANIMATION =====
local notifVisible = false

local function showWeatherNotif(weather)
    local info = weatherInfo[weather]
    if not info then return end
    
    notifIcon.Text = info.icon
    notifLabel.Text = info.label
    notifLabel.TextColor3 = info.color
    indicatorIcon.Text = info.icon
    
    -- Animate in
    notifFrame.Visible = true
    notifFrame.BackgroundTransparency = 1
    notifFrame.Position = UDim2.new(0.5, -125, 0.15, -20)
    
    TweenService:Create(notifFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.3,
        Position = UDim2.new(0.5, -125, 0.15, 0)
    }):Play()
    
    -- Animate out after 3 seconds
    task.delay(3, function()
        TweenService:Create(notifFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            BackgroundTransparency = 1,
            Position = UDim2.new(0.5, -125, 0.15, -20)
        }):Play()
        
        task.delay(0.8, function()
            notifFrame.Visible = false
        end)
    end)
end

-- ===== LISTEN FOR WEATHER CHANGES =====
local studEvents = ReplicatedStorage:FindFirstChild("StudEvents")
if studEvents then
    local weatherEvent = studEvents:FindFirstChild("WeatherChange")
    if weatherEvent then
        weatherEvent.OnClientEvent:Connect(function(weather)
            showWeatherNotif(weather)
        end)
    end
end

print("[WeatherDisplay] Initialized")