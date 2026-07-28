-- ReferralUI: "Bring Them Home" — the player-facing front door for the
-- ReferralSystem. A persistent HUD pill opens a modal that fires Roblox's
-- native game-invite prompt (SocialService:PromptGameInvite), which is what
-- populates the invitee's GetJoinData().ReferredByPlayerId that ReferralSystem
-- reads on their join.
--
-- Research (Evervault studs-growth charter):
--   Q3 — the referral system feeds the algorithm's scored "intentional co-play"
--        signal (co-play sessions run ~1.9x longer). Reward copy must NAME the
--        specific reward ("a rescue, not a coupon"), not say "free reward".
--   Reward is gated server-side on the invitee's FIRST CATCH, so this UI is
--        honest about *when* the coins arrive — no "instant reward" bait.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))
local GrowthConfig = require(ReplicatedStorage:WaitForChild("GrowthConfig"))

local REWARD = GrowthConfig.Referral

-- ─── PERSISTENT HUD PILL ────────────────────────────────────────────────

local hudGui = Instance.new("ScreenGui")
hudGui.Name = "ReferralHUD"
hudGui.ResetOnSpawn = false
hudGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
hudGui.Parent = playerGui

local pill = UITheme.CreateButton({
	name = "InvitePill",
	text = "+ INVITE",
	size = UDim2.new(0, 116, 0, 30),
	pos = UDim2.new(1, -128, 0, 52), -- top-right, tucked under the coin display
	bg = UITheme.C_ACCENT,
	tc = UITheme.C_BORDER,
	ts = 13,
	zIndex = 5,
	parent = hudGui,
	strokeColor = UITheme.C_BORDER,
	strokeThickness = 2,
	autoButtonColor = false,
})
UITheme.ApplyGradient(pill, Color3.fromRGB(255, 216, 90), UITheme.C_ACCENT)
UITheme.AddGloss(pill)
UITheme.AddHoverPop(pill)

-- ─── MODAL ──────────────────────────────────────────────────────────────

local modal = UITheme.CreateModal({
	name = "ReferralModal",
	title = "BRING THEM HOME",
	size = UDim2.new(0, 360, 0, 384),
	parent = playerGui,
})

local content = modal.content

-- Hero line
UITheme.CreateLabel({
	name = "Hero",
	text = "Someone out there is still lost.",
	size = UDim2.new(1, 0, 0, 24),
	pos = UDim2.new(0, 0, 0, 4),
	color = UITheme.C_ACCENT,
	ts = 14,
	parent = content,
})

local body = UITheme.CreateLabel({
	name = "Body",
	text = "Invite a friend to Studs. When they catch their first stud and remember who they are, you BOTH get coins.",
	size = UDim2.new(1, -8, 0, 74),
	pos = UDim2.new(0, 4, 0, 34),
	color = UITheme.C_WHITE,
	ts = 12,
	ya = Enum.TextYAlignment.Top,
	parent = content,
})
body.TextWrapped = true

-- Reward breakdown — two cartridge chips, one per side of the deal
local function rewardChip(name, who, coins, xScale)
	local chip = UITheme.CreateFrame({
		name = name,
		size = UDim2.new(0.46, 0, 0, 78),
		pos = UDim2.new(xScale, 0, 0, 118),
		bg = UITheme.C_BG,
		parent = content,
	})
	UITheme.ApplyStroke(chip, UITheme.C_BORDER, 2)
	UITheme.CreateLabel({
		text = who, size = UDim2.new(1, -6, 0, 20), pos = UDim2.new(0, 3, 0, 8),
		color = UITheme.C_SEC, ts = 11, parent = chip,
	})
	UITheme.CreateLabel({
		text = "+" .. coins, size = UDim2.new(1, -6, 0, 30), pos = UDim2.new(0, 3, 0, 30),
		color = UITheme.C_ACCENT, ts = 22, parent = chip,
	})
	UITheme.CreateLabel({
		text = "coins", size = UDim2.new(1, -6, 0, 16), pos = UDim2.new(0, 3, 0, 58),
		color = UITheme.C_SEC, ts = 10, parent = chip,
	})
end

rewardChip("YouChip", "YOU GET", REWARD.inviterCoins, 0.02)
rewardChip("FriendChip", "THEY GET", REWARD.inviteeCoins, 0.52)

-- Honest fine print about *when* the reward lands (policy: gated on first catch)
UITheme.CreateLabel({
	name = "FinePrint",
	text = "Rewarded when your friend catches their first stud.",
	size = UDim2.new(1, -8, 0, 18),
	pos = UDim2.new(0, 4, 0, 204),
	color = UITheme.C_SEC,
	ts = 10,
	parent = content,
})

-- The action
local inviteBtn = UITheme.CreateJuicyButton({
	name = "DoInvite",
	text = "INVITE A FRIEND",
	size = UDim2.new(1, -8, 0, 52),
	pos = UDim2.new(0, 4, 0, 232),
	ts = 16,
	parent = content,
})

local statusLabel = UITheme.CreateLabel({
	name = "Status",
	text = "",
	size = UDim2.new(1, -8, 0, 20),
	pos = UDim2.new(0, 4, 0, 292),
	color = UITheme.C_SEC,
	ts = 10,
	parent = content,
})

-- ─── INVITE FLOW ────────────────────────────────────────────────────────

local inviting = false

local function promptInvite()
	if inviting then return end
	inviting = true
	statusLabel.Text = "Opening invite..."
	statusLabel.TextColor3 = UITheme.C_SEC

	task.spawn(function()
		local canInvite = false
		local ok = pcall(function()
			canInvite = SocialService:CanSendGameInviteAsync(player)
		end)
		if ok and canInvite then
			pcall(function()
				SocialService:PromptGameInvite(player)
			end)
			statusLabel.Text = "Pick a friend from the list!"
			statusLabel.TextColor3 = UITheme.C_SUCCESS
		else
			statusLabel.Text = "Invites unavailable right now — try again in a sec."
			statusLabel.TextColor3 = UITheme.C_WARNING
		end
		inviting = false
	end)
end

inviteBtn.MouseButton1Click:Connect(promptInvite)
pill.MouseButton1Click:Connect(modal.open)

print("[ReferralUI] Initialized (Bring Them Home invite front door)")
