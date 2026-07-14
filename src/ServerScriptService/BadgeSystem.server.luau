-- BadgeSystem: awards Roblox platform badges when milestones are earned.
--
-- SETUP: badge IDs live in ReplicatedStorage/MonetizationConfig (Badges).
-- Entries left at 0 are skipped, so this ships safe before badges exist.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))
local Config = require(ReplicatedStorage:WaitForChild("MonetizationConfig"))

-- milestone id (MilestoneSystem) -> Roblox badge ID
local BADGE_IDS = Config.Badges

ServerRegistry.Register("OnMilestoneEarned", function(player, milestoneId)
	local badgeId = BADGE_IDS[milestoneId]
	if not badgeId or badgeId == 0 then return end

	task.spawn(function()
		local ok, err = pcall(function()
			-- AwardBadge no-ops gracefully if the player already owns it
			BadgeService:AwardBadge(player.UserId, badgeId)
		end)
		if not ok then
			warn("[BadgeSystem] Failed to award badge " .. badgeId .. " to " .. player.Name .. ": " .. tostring(err))
		end
	end)
end)

print("[BadgeSystem] Initialized (configure BADGE_IDS to enable awards)")
