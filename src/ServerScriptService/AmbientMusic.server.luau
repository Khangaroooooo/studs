-- AmbientMusic: Plays background music that changes with the time of day
-- Uses Roblox's built-in audio assets for a peaceful vibe

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

-- Create a Sound in Workspace.Sounds for ambient music
local soundsFolder = workspace:FindFirstChild("Sounds")
if not soundsFolder then
	soundsFolder = Instance.new("Folder")
	soundsFolder.Name = "Sounds"
	soundsFolder.Parent = workspace
end

local ambientSound = Instance.new("Sound")
ambientSound.Name = "AmbientMusic"
ambientSound.Volume = 0.3
ambientSound.Looped = true
ambientSound.SoundId = "rbxassetid://135768426522329" -- Peaceful ambient track
ambientSound.Parent = soundsFolder

-- Day/night music tracks
local DAY_MUSIC = "rbxassetid://135768426522329"  -- Peaceful
local NIGHT_MUSIC = "rbxassetid://139476737350790" -- Calm night

-- Start playing
ambientSound:Play()

-- Adjust volume based on time of day
local function updateMusic()
	local clockTime = Lighting.ClockTime

	if clockTime >= 6 and clockTime < 18 then
		-- Daytime
		if ambientSound.SoundId ~= DAY_MUSIC then
			ambientSound.SoundId = DAY_MUSIC
			ambientSound:Play()
		end
		ambientSound.Volume = 0.3
	else
		-- Nighttime
		if ambientSound.SoundId ~= NIGHT_MUSIC then
			ambientSound.SoundId = NIGHT_MUSIC
			ambientSound:Play()
		end
		ambientSound.Volume = 0.2
	end
end

task.spawn(function()
	while true do
		updateMusic()
		task.wait(30) -- Check every 30 seconds
	end
end)

print("[AmbientMusic] Initialized")