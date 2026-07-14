-- SoundEffects: Plays UI and gameplay sound effects
-- Uses Sound objects parented to the PlayerGui for client-side playback

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

-- Create a ScreenGui to hold sounds
local soundGui = Instance.new("ScreenGui")
soundGui.Name = "SoundEffects"
soundGui.ResetOnSpawn = false
soundGui.Parent = playerGui

-- Sound definitions (using Roblox built-in asset IDs)
local sounds = {
	encounterAlert = { id = 6432593850, volume = 0.4 },   -- Alert/whoosh
	catchSuccess = { id = 258057783, volume = 0.5 },      -- Success jingle
	catchFail = { id = 16903690359, volume = 0.3 },          -- Fail buzz
	healChime = { id = 92852865488633, volume = 0.4 },          -- Heal chime
	coinPickup = { id = 4612375051, volume = 0.3 },         -- Coin sound
	shopBuy = { id = 6432593850, volume = 0.35 },            -- Purchase sound
	questComplete = { id = 1840076509, volume = 0.5 },      -- Quest fanfare
	wishMade = { id = 92852865488633, volume = 0.3 },            -- Wish sound
	milestoneUnlock = { id = 1840076509, volume = 0.6 },    -- Milestone fanfare
	typeAdvantage = { id = 6432593850, volume = 0.25 },     -- Advantage indicator
}

-- Create Sound instances
local soundInstances = {}
for name, info in pairs(sounds) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. info.id
	sound.Volume = info.volume
	sound.Parent = soundGui
	soundInstances[name] = sound
end

-- Play a sound by name
local function playSound(name)
	local sound = soundInstances[name]
	if sound then
		sound:Stop()
		sound:Play()
	end
end

-- Register playSound with UIManager for other client scripts
UIManager.Register("PlaySound", playSound)

-- Listen for encounter start
StudEvents.EncounterStart.OnClientEvent:Connect(function(studInfo)
	playSound("encounterAlert")
	-- Play type advantage sound if applicable
	if studInfo.typeAdvantage and studInfo.typeAdvantage > 1.0 then
		task.delay(0.3, function()
			playSound("typeAdvantage")
		end)
	end
end)

-- Listen for coin updates
StudEvents.UpdateCoins.OnClientEvent:Connect(function(coins)
	playSound("coinPickup")
end)

-- Listen for healing
StudEvents.HealPlayer.OnClientEvent:Connect(function()
	playSound("healChime")
end)

-- Listen for milestone notifications
StudEvents.MilestoneNotify.OnClientEvent:Connect(function()
	playSound("milestoneUnlock")
end)

-- Listen for weather changes
StudEvents.WeatherChange.OnClientEvent:Connect(function()
	-- Subtle sound for weather change
end)

-- Catch celebration sound is now handled by CatchResultUI via UIManager.Call("PlaySound", ...)
-- This avoids load-order issues that existed with the old _G wrapping pattern.

print("[SoundEffects] Initialized")