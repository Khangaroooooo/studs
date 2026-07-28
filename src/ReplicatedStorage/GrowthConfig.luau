--!strict
--[[
	GrowthConfig — live-ops tunables for the growth/retention systems
	(ReferralSystem, AnalyticsSystem, EncounterSystem FTUE bias).

	Grounded in the Evervault studs-growth research charter:
	  - Referral rewards are gated on the INVITEE's first catch, not their join,
	    so multi-account farming pays nothing (Q3 policy finding).
	  - The FTUE bias exists to hit first-catch-in-60s (Q2: official "get to the
	    fun in 5 minutes" guidance; TTFC is the launch make-or-break metric).

	Everything here is deliberately flat/numeric so these values can be migrated
	to Roblox Configs (remote config) at launch and retuned live without a
	republish (Q7: treat referral/FTUE reward sizes as live-tuned Configs).
]]

local GrowthConfig = {
	Referral = {
		enabled = true,
		-- Both sides get a named, specific reward when the invitee completes
		-- their first catch ("Bring Them Home" — a rescue, not a coupon).
		inviteeCoins = 100,
		inviterCoins = 150,
	},

	FTUE = {
		-- Pre-first-catch: encounter chance multiplier so a brand-new player
		-- meets their first stud fast (design target: catch inside ~60s).
		firstEncounterRateMult = 4,
		-- Pre-first-catch: the catch minigame is tuned to succeed on
		-- near-any input (generous bar, slow decay, low tap floor).
		firstCatchGenerous = true,
	},

	Coplay = {
		-- Track (never gate): first session with a friend in the server is
		-- stamped into the save + telemetry so Studs measures its own real
		-- friend-retention number instead of folk "3x" claims (Q15).
		trackingEnabled = true,
		checkIntervalSeconds = 60,
	},
}

return GrowthConfig
