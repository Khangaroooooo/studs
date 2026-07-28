--!strict
-- MonetizationConfig: the ONE place to paste your Roblox IDs.
--
-- Everything here ships safe while the IDs are 0 / empty — the systems that
-- read this module no-op on a 0 id, so you can wire real IDs in at launch
-- without touching any other code.
--
--   1. Passes   -> Creator Dashboard > Monetization > Passes
--   2. Products -> Creator Dashboard > Monetization > Developer Products
--   3. Badges   -> Creations > (your experience) > Engagement > Badges
--
-- Design rule (keep it): convenience & cosmetics only. Nothing here sells
-- power a free player can't earn — shiny odds and save slots don't win fights.

export type Gamepass = { id: number, attr: string, value: any, label: string }

local MonetizationConfig = {}

-- ─── GAMEPASSES ────────────────────────────────────────────────────────
-- On purchase/ownership the player gets `attr` set to `value`; game systems
-- read that attribute (EncounterSystem reads "ShinyCharm", SaveManager reads
-- "ExtraSaveSlots"). `label` is only for your own reference here.
MonetizationConfig.Gamepasses = {
	{ id = 1918299156, attr = "ShinyCharm",     value = true, label = "Shiny Charm (2x shiny odds)" },
	{ id = 1917621174, attr = "ExtraSaveSlots", value = 5,    label = "Slot Bundle (+5 save slots)" },
} :: { Gamepass }

-- ─── DEVELOPER PRODUCTS (coin packs) ───────────────────────────────────
-- [productId] = coins granted. Add a row per pack once the product exists.
--   [1234567] = 250,
MonetizationConfig.Products = {} :: { [number]: number }

-- ─── BADGES ────────────────────────────────────────────────────────────
-- milestone id (from MilestoneSystem) -> Roblox badge id. 0 = not created yet.
MonetizationConfig.Badges = {
	first_catch     = 0,
	collector_5     = 0,
	collector_10    = 0,
	collector_18    = 0,
	collector_all   = 0,
	first_rare      = 0,
	first_legendary = 0,
	coins_500       = 0,
	catches_50      = 0,
	first_shiny     = 0,
	first_evolution = 0,
	first_trade     = 0,
	first_pvp_win   = 0,
	first_coop      = 0,
} :: { [string]: number }

return MonetizationConfig
