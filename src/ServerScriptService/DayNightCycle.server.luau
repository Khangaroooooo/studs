-- DayNightCycle: Atmospheric lighting that cycles over time
-- Full cycle = 10 minutes (600s) for testing, can be adjusted
-- Phases: Dawn -> Day -> Dusk -> Night -> repeat

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local CYCLE_DURATION = 600 -- seconds for full cycle
local PHASE_DURATION = CYCLE_DURATION / 4

-- Phase definitions with lighting properties
local phases = {
	Dawn = {
		timeOfDay = "06:00:00",
		brightness = 1,
		ambient = Color3.fromRGB(120, 100, 130),
		outdoorAmbient = Color3.fromRGB(100, 90, 110),
		fogColor = Color3.fromRGB(180, 160, 200),
		fogEnd = 800,
		clockShade = 0.3,
		skyBk = Color3.fromRGB(180, 140, 200),
	},
	Day = {
		timeOfDay = "12:00:00",
		brightness = 2,
		ambient = Color3.fromRGB(150, 150, 150),
		outdoorAmbient = Color3.fromRGB(130, 130, 130),
		fogColor = Color3.fromRGB(200, 210, 230),
		fogEnd = 1000,
		clockShade = 0,
		skyBk = Color3.fromRGB(100, 150, 230),
	},
	Dusk = {
		timeOfDay = "18:00:00",
		brightness = 1,
		ambient = Color3.fromRGB(130, 90, 70),
		outdoorAmbient = Color3.fromRGB(110, 80, 60),
		fogColor = Color3.fromRGB(220, 150, 100),
		fogEnd = 700,
		clockShade = 0.2,
		skyBk = Color3.fromRGB(230, 120, 60),
	},
	Night = {
		timeOfDay = "00:00:00",
		brightness = 0.2,
		ambient = Color3.fromRGB(40, 40, 60),
		outdoorAmbient = Color3.fromRGB(30, 30, 50),
		fogColor = Color3.fromRGB(20, 20, 40),
		fogEnd = 400,
		clockShade = 0.8,
		skyBk = Color3.fromRGB(15, 15, 35),
	},
}

local phaseOrder = {"Dawn", "Day", "Dusk", "Night"}

-- Create atmosphere for color correction
local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0
atmosphere.Color = Color3.fromRGB(200, 200, 210)
atmosphere.Decay = Color3.fromRGB(120, 120, 140)
atmosphere.Glare = 0
atmosphere.Haze = 0
atmosphere.Parent = Lighting

-- Create a Bloom effect for day
local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 24
bloom.Threshold = 1.5
bloom.Parent = Lighting

-- Create ColorCorrection for time-of-day tinting
local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Brightness = 0
colorCorrection.Contrast = 0
colorCorrection.Saturation = 0
colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
colorCorrection.Parent = Lighting

local function applyPhase(phaseName, tweenDuration)
	local phase = phases[phaseName]
	if not phase then return end

	local tweenInfo = TweenInfo.new(tweenDuration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)

	-- Tween Lighting properties
	TweenService:Create(Lighting, tweenInfo, {
		Brightness = phase.brightness,
		Ambient = phase.ambient,
		OutdoorAmbient = phase.outdoorAmbient,
		FogColor = phase.fogColor,
		FogEnd = phase.fogEnd,
		-- A malformed timeOfDay would otherwise error here and freeze the
		-- cycle on whatever phase was last applied.
		ClockTime = (tonumber(phase.timeOfDay:sub(1, 2)) or 0)
			+ (tonumber(phase.timeOfDay:sub(4, 5)) or 0) / 60,
	}):Play()

	-- Tween atmosphere
	TweenService:Create(atmosphere, tweenInfo, {
		Color = phase.fogColor,
		Haze = phaseName == "Night" and 2 or 0,
		Glare = phaseName == "Day" and 0.5 or 0,
	}):Play()

	-- Tween bloom
	TweenService:Create(bloom, tweenInfo, {
		Intensity = phaseName == "Day" and 0.6 or 0.2,
		Threshold = phaseName == "Night" and 0.8 or 1.5,
	}):Play()

	-- Tween color correction
	local tintColor = phaseName == "Night" and Color3.fromRGB(180, 180, 220)
		or phaseName == "Dusk" and Color3.fromRGB(255, 220, 180)
		or phaseName == "Dawn" and Color3.fromRGB(255, 230, 210)
		or Color3.fromRGB(255, 255, 255)
	local saturation = phaseName == "Night" and -0.2 or 0

	TweenService:Create(colorCorrection, tweenInfo, {
		TintColor = tintColor,
		Saturation = saturation,
		Brightness = phaseName == "Night" and -0.05 or 0,
	}):Play()

	print("[DayNightCycle] Transitioning to", phaseName)
end

-- Start with Dawn
applyPhase("Dawn", 0)

-- Main cycle loop
task.spawn(function()
	while true do
		for i, phaseName in ipairs(phaseOrder) do
			-- Transition to this phase
			applyPhase(phaseName, PHASE_DURATION * 0.8) -- 80% of phase time for tween
			-- Wait for the full phase duration
			task.wait(PHASE_DURATION)
		end
	end
end)

print("[DayNightCycle] Initialized - full cycle:", CYCLE_DURATION, "seconds")