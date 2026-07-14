-- PlayerSetup: Enables shift-lock for all players
-- (Previously named ForceR6, which was removed because LoadCharacterWithHumanoidDescription
-- cannot force R6 rig type and was causing the camera-freeze bug.)
--
-- To force R6 characters: Studio menu → Game Settings → Avatar → Avatar Type → R6

local Players = game:GetService("Players")

local function onPlayerAdded(player)
	pcall(function()
		player.DevEnableMouseLock = true
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end