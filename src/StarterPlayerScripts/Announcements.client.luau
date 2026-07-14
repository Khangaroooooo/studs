-- Announcements: shows server-wide GameAnnouncement broadcasts (legendary
-- events, etc.) as notification banners via NotificationUI's "Notify" hook.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

local announceEvent = StudEvents:WaitForChild("GameAnnouncement", 30)
if not announceEvent then return end

announceEvent.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end

	if data.type == "legendaryEvent" then
		UIManager.Call("Notify", "warning", data.title or "LEGENDARY SIGHTING!", data.text or "")
	elseif data.type == "legendaryEventEnd" then
		UIManager.Call("Notify", "info", data.title or "Event over", data.text or "")
	else
		UIManager.Call("Notify", "info", data.title or "Announcement", data.text or "")
	end
end)

print("[Announcements] Initialized")
