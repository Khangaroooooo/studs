local WeatherSystem = {}

-- Dynamic weather system: Clear, Cloudy, Rain, Fog
-- Cycles every 3-8 minutes, transitions smoothly
-- Rain uses ParticleEmitters, fog uses Atmosphere/Fog properties

local Lighting = game.Lighting
local TweenService = game:GetService("TweenService")

local studville = game.Workspace.Studville

-- Weather states
local WEATHER = {
    CLEAR = "Clear",
    CLOUDY = "Cloudy",
    RAIN = "Rain",
    FOG = "Fog"
}

local currentWeather = WEATHER.CLEAR
local weatherDuration = math.random(180, 480) -- 3-8 minutes
local transitionDuration = 10 -- seconds for smooth transitions

-- Weather configs
local weatherConfigs = {
    [WEATHER.CLEAR] = {
        fogEnd = 1000,
        fogStart = 0,
        fogColor = Color3.fromRGB(192, 192, 192),
        atmosphereDensity = 0.3,
        atmosphereColor = Color3.fromRGB(170, 170, 170),
        brightness = 2,
        outdoorAmbient = Color3.fromRGB(127, 127, 127),
        rainRate = 0
    },
    [WEATHER.CLOUDY] = {
        fogEnd = 600,
        fogStart = 50,
        fogColor = Color3.fromRGB(150, 155, 160),
        atmosphereDensity = 0.4,
        atmosphereColor = Color3.fromRGB(140, 145, 150),
        brightness = 1.5,
        outdoorAmbient = Color3.fromRGB(100, 105, 110),
        rainRate = 0
    },
    [WEATHER.RAIN] = {
        fogEnd = 300,
        fogStart = 30,
        fogColor = Color3.fromRGB(120, 125, 135),
        atmosphereDensity = 0.5,
        atmosphereColor = Color3.fromRGB(110, 115, 125),
        brightness = 1,
        outdoorAmbient = Color3.fromRGB(80, 85, 95),
        rainRate = 80
    },
    [WEATHER.FOG] = {
        fogEnd = 150,
        fogStart = 10,
        fogColor = Color3.fromRGB(180, 185, 190),
        atmosphereDensity = 0.6,
        atmosphereColor = Color3.fromRGB(170, 175, 180),
        brightness = 1.2,
        outdoorAmbient = Color3.fromRGB(110, 115, 120),
        rainRate = 0
    }
}

-- Transition weights (what weather can transition to)
local transitions = {
    [WEATHER.CLEAR] = {WEATHER.CLOUDY, WEATHER.FOG},
    [WEATHER.CLOUDY] = {WEATHER.CLEAR, WEATHER.RAIN, WEATHER.FOG},
    [WEATHER.RAIN] = {WEATHER.CLOUDY, WEATHER.FOG},
    [WEATHER.FOG] = {WEATHER.CLEAR, WEATHER.CLOUDY, WEATHER.RAIN}
}

-- ===== RAIN SYSTEM =====
local rainFolder = Instance.new("Folder")
rainFolder.Name = "Rain"
rainFolder.Parent = studville

-- Create rain emitters spread across the town
local rainEmitters = {}
for i = 1, 9 do
    local x = (i % 3 - 1) * 30
    local z = math.floor(i / 3 - 1) * 30
    
    local emitter = Instance.new("Part")
    emitter.Name = "RainEmitter_" .. i
    emitter.Size = Vector3.new(0.1, 0.1, 0.1)
    emitter.Position = Vector3.new(x, 30, z)
    emitter.Anchored = true
    emitter.CanCollide = false
    emitter.Transparency = 1
    emitter.Parent = rainFolder
    
    local rain = Instance.new("ParticleEmitter")
    rain.Name = "Rain"
    rain.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
    rain.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.03),
        NumberSequenceKeypoint.new(1, 0.03)
    })
    rain.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.3),
        NumberSequenceKeypoint.new(1, 0.5)
    })
    rain.Lifetime = NumberRange.new(0.5, 1)
    rain.Rate = 0 -- Start with no rain
    rain.Speed = NumberRange.new(25, 35)
    rain.SpreadAngle = Vector2.new(5, 5)
    rain.EmissionDirection = Enum.NormalId.Bottom
    rain.Acceleration = Vector3.new(0, -10, 0)
    rain.LightInfluence = 0.3
    rain.RotSpeed = NumberRange.new(0, 0)
    rain.Parent = emitter
    
    table.insert(rainEmitters, rain)
end

-- Rain splash on ground
local splashFolder = Instance.new("Folder")
splashFolder.Name = "RainSplashes"
splashFolder.Parent = studville

for i = 1, 6 do
    local splashEmitter = Instance.new("Part")
    splashEmitter.Name = "SplashEmitter_" .. i
    splashEmitter.Size = Vector3.new(0.1, 0.1, 0.1)
    splashEmitter.Position = Vector3.new(math.random(-20, 20), 0.5, math.random(-20, 20))
    splashEmitter.Anchored = true
    splashEmitter.CanCollide = false
    splashEmitter.Transparency = 1
    splashEmitter.Parent = splashFolder
    
    local splash = Instance.new("ParticleEmitter")
    splash.Name = "Splash"
    splash.Color = ColorSequence.new(Color3.fromRGB(180, 200, 230))
    splash.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.2),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 0)
    })
    splash.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(0.5, 0.7),
        NumberSequenceKeypoint.new(1, 1)
    })
    splash.Lifetime = NumberRange.new(0.2, 0.4)
    splash.Rate = 0
    splash.Speed = NumberRange.new(0.5, 1.5)
    splash.SpreadAngle = Vector2.new(180, 180)
    splash.EmissionDirection = Enum.NormalId.Top
    splash.LightEmission = 0.2
    splash.Parent = splashEmitter
    
    table.insert(rainEmitters, splash) -- Share the rate control
end

-- ===== WEATHER TRANSITIONS =====
local function transitionWeather(newWeather)
    local config = weatherConfigs[newWeather]
    if not config then return end
    
    -- Tween Lighting properties
    local tweenInfo = TweenInfo.new(transitionDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    
    -- Fog
    TweenService:Create(Lighting, tweenInfo, {
        FogEnd = config.fogEnd,
        FogStart = config.fogStart,
        FogColor = config.fogColor
    }):Play()
    
    -- Brightness
    TweenService:Create(Lighting, tweenInfo, {
        Brightness = config.brightness,
        OutdoorAmbient = config.outdoorAmbient
    }):Play()
    
    -- Atmosphere
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmosphere then
        TweenService:Create(atmosphere, tweenInfo, {
            Density = config.atmosphereDensity,
            Color = config.atmosphereColor
        }):Play()
    end
    
    -- Rain rate (instant change for particles, but we'll ramp it)
    for _, emitter in ipairs(rainEmitters) do
        if emitter.Name == "Rain" then
            -- Ramp rain rate over transition duration
            spawn(function()
                local startRate = emitter.Rate
                local endRate = config.rainRate
                local elapsed = 0
                while elapsed < transitionDuration do
                    elapsed = elapsed + 0.5
                    local t = elapsed / transitionDuration
                    emitter.Rate = startRate + (endRate - startRate) * t
                    task.wait(0.5)
                end
                emitter.Rate = endRate
            end)
        elseif emitter.Name == "Splash" then
            spawn(function()
                local startRate = emitter.Rate
                local endRate = config.rainRate * 0.3
                local elapsed = 0
                while elapsed < transitionDuration do
                    elapsed = elapsed + 0.5
                    local t = elapsed / transitionDuration
                    emitter.Rate = startRate + (endRate - startRate) * t
                    task.wait(0.5)
                end
                emitter.Rate = endRate
            end)
        end
    end
    
    currentWeather = newWeather
    -- Gameplay systems (EncounterSystem spawn bias) and clients read this.
    -- (Inline GetService: the `local ReplicatedStorage` further down this
    -- file is declared AFTER this function, so it isn't in scope here.)
    game:GetService("ReplicatedStorage"):SetAttribute("CurrentWeather", newWeather)
    print("[WeatherSystem] Weather changed to: " .. newWeather)
end

-- ===== WEATHER ANNOUNCEMENT =====
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local studEvents = ReplicatedStorage:FindFirstChild("StudEvents")

local function announceWeather(weather)
    if studEvents then
        -- We can reuse or create a weather event
        local weatherEvent = studEvents:FindFirstChild("WeatherChange")
        if not weatherEvent then
            weatherEvent = Instance.new("RemoteEvent")
            weatherEvent.Name = "WeatherChange"
            weatherEvent.Parent = studEvents
        end
        weatherEvent:FireAllClients(weather)
    end
end

-- ===== MAIN WEATHER LOOP =====
-- Weather changes every 3–8 MINUTES, so accumulating a timer 60x/second via
-- Heartbeat was thousands of pointless callbacks per change. A sleeping task
-- loop wakes exactly once per weather cycle instead.
task.spawn(function()
    while true do
        task.wait(weatherDuration)
        weatherDuration = math.random(180, 480)

        -- Pick next weather
        local possibleTransitions = transitions[currentWeather]
        local nextWeather = possibleTransitions[math.random(1, #possibleTransitions)]

        transitionWeather(nextWeather)
        announceWeather(nextWeather)
    end
end)

-- Create the WeatherChange RemoteEvent if it doesn't exist
if studEvents and not studEvents:FindFirstChild("WeatherChange") then
    local weatherEvent = Instance.new("RemoteEvent")
    weatherEvent.Name = "WeatherChange"
    weatherEvent.Parent = studEvents
end

ReplicatedStorage:SetAttribute("CurrentWeather", currentWeather)

print("[WeatherSystem] Initialized. Starting weather: Clear. Next change in " .. math.floor(weatherDuration) .. " seconds")