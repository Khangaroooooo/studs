-- UIGate: keeps the ambient HUD hidden until the player is actually in the
-- game. On a brand-new save the sequence is:
--   save-slot menu → starter pick (ONLY UI on screen) → tutorial → HUD/rest.
-- The server drives this with two attributes: GameStarted (set on
-- NewGame/LoadGame) and StarterChosen (false while the starter pick is up,
-- true once picked — and true immediately on loaded saves).
--
-- We toggle ScreenGui.Enabled from the outside so the individual UI scripts
-- don't each need their own gating logic. Guis not in this list (battle,
-- catch, dialogue, menus the player opens themselves) are event-driven and
-- can't appear before gameplay anyway.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GATED_GUIS = {
	GameHUD = true,
	QuestUI = true, -- quest toggle button + tracker live at top level of this gui
	SettingsMenu = true,
	LeaderboardUI = true,
	WeatherDisplay = true,
	AreaNameDisplay = true,
	NotificationUI = true,
	CatchStreak = true,
}

local function gateOpen()
	-- StarterChosen ~= false (rather than == true) so sessions from before
	-- the attribute existed fail open instead of hiding the HUD forever
	return player:GetAttribute("GameStarted") == true
		and player:GetAttribute("StarterChosen") ~= false
end

local function applyToGui(gui)
	if gui:IsA("ScreenGui") and GATED_GUIS[gui.Name] then
		gui.Enabled = gateOpen()
	end
end

local function applyAll()
	for _, gui in ipairs(playerGui:GetChildren()) do
		applyToGui(gui)
	end
end

playerGui.ChildAdded:Connect(applyToGui)
player:GetAttributeChangedSignal("GameStarted"):Connect(applyAll)
player:GetAttributeChangedSignal("StarterChosen"):Connect(applyAll)
applyAll()
