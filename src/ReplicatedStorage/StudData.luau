-- StudData: Central database of all Stud types, names, colors, and rarity
-- This module is shared between server and client
--
-- DEX v2: 105 species (15 per type — 6 Common, 4 Uncommon, 3 Rare,
-- 2 Legendary). Every stud has a regular human name (the joke is the
-- mundanity: a living boulder named Steve). Each species also has its own
-- stat spread and its own 3-move kit picked from its type's move pool, so
-- two studs of the same type can play differently.

local StudData = {}

-- Rarity tiers and their properties for the catching minigame.
-- TUNING INVARIANT: each tier must be winnable. Per tap the bar gains
-- barFillRate * 15, the 12s timer decays ~24 total, and circle count is
-- roughly 12 / (circleSpawnRate * 0.85). Required tap accuracy should land
-- near 60% (Common) up to ~80% (Legendary) — the old Legendary values
-- (0.3 fill / 200 target) capped out at 82/200 even with perfect play.
StudData.Rarity = {
	Common = {
		name = "Common",
		barFillRate = 1.0,
		circleSize = 60,
		circleLifespan = 2.0,
		circleSpawnRate = 1.0,
		catchBarTarget = 100,
		color = Color3.fromRGB(180, 180, 180),
	},
	Uncommon = {
		name = "Uncommon",
		barFillRate = 0.9,
		circleSize = 48,
		circleLifespan = 1.6,
		circleSpawnRate = 0.9,
		catchBarTarget = 120,
		color = Color3.fromRGB(50, 200, 50),
	},
	Rare = {
		name = "Rare",
		barFillRate = 0.8,
		circleSize = 38,
		circleLifespan = 1.2,
		circleSpawnRate = 0.75,
		catchBarTarget = 150,
		color = Color3.fromRGB(50, 100, 255),
	},
	Legendary = {
		name = "Legendary",
		barFillRate = 0.7,
		circleSize = 30,
		circleLifespan = 0.9,
		circleSpawnRate = 0.55,
		catchBarTarget = 190,
		color = Color3.fromRGB(255, 200, 0),
	},
}

-- Type definitions with associated colors.
-- Icons are real emoji: Roblox renders emoji as Twemoji images in TextLabels
-- regardless of font, so these are safe — unlike dingbat/symbol glyphs
-- (◎ ‹ ← etc.), which fall outside Roblox's font coverage and draw as
-- empty rectangles.
StudData.Types = {
	Fire     = { color = Color3.fromRGB(230, 60, 40),   icon = "🔥" },
	Water    = { color = Color3.fromRGB(40, 120, 230),  icon = "💧" },
	Grass    = { color = Color3.fromRGB(40, 180, 60),   icon = "🍃" },
	Electric = { color = Color3.fromRGB(240, 210, 30),  icon = "⚡" },
	Rock     = { color = Color3.fromRGB(160, 140, 100), icon = "🪨" },
	Ice      = { color = Color3.fromRGB(140, 210, 240), icon = "❄️" },
	Shadow   = { color = Color3.fromRGB(80, 50, 120),   icon = "🌙" },
}

-- ─── MOVE POOLS ─────────────────────────────────────────────────────────
-- Each type has a pool of 6 moves: two light (slots 1-2), two mid (3-4),
-- two heavy (5-6). A species' kit is 3 pool indices — one light, one mid,
-- one heavy — declared in its `moves` field, so kits differ within a type
-- (a fast jab/riptide/cannon Water stud vs a drizzle/wave/maelstrom one).
-- A 4th slot (the species' OTHER heavy) unlocks at Lv50, so late levels
-- still pay out and every stud eventually owns both heavies.
-- Kit slots unlock at MoveUnlockLevels; the server enforces this
-- (Combat.ResolveMove), UIs grey out locked rows.
--
-- ACCURACY TRADEOFF: lights always hit; mids hit 95%; the 1.85x heavy hits
-- 90% and the 2.1x heavy only 80%. Expected damage still rises with power
-- (1.85*0.9=1.67 vs 2.1*0.8=1.68), but the big number can whiff — so
-- "reliable vs swingy" is a real choice instead of always-press-the-biggest.
StudData.MoveUnlockLevels = { 1, 10, 25, 50 }

StudData.TypeMovePools = {
	Fire = {
		{ name = "Ember Jab", power = 0.95, description = "A quick fiery poke." },
		{ name = "Warm Slap", power = 1.05, description = "An uncomfortably warm slap." },
		{ name = "Flame Burst", power = 1.3, accuracy = 0.95, status = "burn", statusChance = 0.25, description = "A burst of intense flame." },
		{ name = "Scorch", power = 1.5, accuracy = 0.95, status = "burn", statusChance = 0.25, description = "A slow, searing burn." },
		{ name = "Inferno Blast", power = 1.85, accuracy = 0.9, description = "A devastating fire explosion." },
		{ name = "Supernova", power = 2.1, accuracy = 0.8, description = "Everything gets very bright." },
	},
	Water = {
		{ name = "Splash Jab", power = 0.95, description = "A swift wet strike." },
		{ name = "Drizzle", power = 1.05, description = "Persistent, demoralizing rain." },
		{ name = "Tidal Wave", power = 1.3, accuracy = 0.95, description = "A crashing wave of water." },
		{ name = "Riptide", power = 1.5, accuracy = 0.95, description = "Drags the foe out to sea." },
		{ name = "Hydro Cannon", power = 1.85, accuracy = 0.9, description = "A massive water cannon blast." },
		{ name = "Maelstrom", power = 2.1, accuracy = 0.8, description = "The ocean, but angry." },
	},
	Grass = {
		{ name = "Vine Whip", power = 0.95, description = "A lash of thorny vines." },
		{ name = "Leaf Flick", power = 1.05, description = "A leaf, flicked with intent." },
		{ name = "Leaf Storm", power = 1.3, accuracy = 0.95, description = "A swirling storm of leaves." },
		{ name = "Thorn Lash", power = 1.5, accuracy = 0.95, description = "Sharp thorns rake the enemy." },
		{ name = "Nature's Wrath", power = 1.85, accuracy = 0.9, description = "The fury of nature unleashed." },
		{ name = "Overgrowth", power = 2.1, accuracy = 0.8, description = "The garden wins." },
	},
	Electric = {
		{ name = "Spark Jab", power = 0.95, description = "A quick electric jab." },
		{ name = "Static Zap", power = 1.05, description = "Like a doorknob in winter." },
		{ name = "Thunder Wave", power = 1.3, accuracy = 0.95, status = "paralyze", statusChance = 0.25, description = "A wave of thunder energy." },
		{ name = "Volt Surge", power = 1.5, accuracy = 0.95, status = "paralyze", statusChance = 0.25, description = "A surging electric charge." },
		{ name = "Lightning Bolt", power = 1.85, accuracy = 0.9, description = "A devastating bolt of lightning." },
		{ name = "Gigavolt", power = 2.1, accuracy = 0.8, description = "The lights dim citywide." },
	},
	Rock = {
		{ name = "Rock Throw", power = 0.95, description = "Hurl a rock at the foe." },
		{ name = "Gravel Toss", power = 1.05, description = "A fistful of driveway." },
		{ name = "Stone Edge", power = 1.3, accuracy = 0.95, description = "Sharp stones slash the enemy." },
		{ name = "Rockslide", power = 1.5, accuracy = 0.95, description = "The hillside joins the fight." },
		{ name = "Earthquake", power = 1.85, accuracy = 0.9, description = "A devastating ground tremor." },
		{ name = "Tectonic Slam", power = 2.1, accuracy = 0.8, description = "Continental drift, expedited." },
	},
	Ice = {
		{ name = "Ice Shard", power = 0.95, description = "A sharp shard of ice." },
		{ name = "Cold Snap", power = 1.05, description = "A sudden chill in the air." },
		{ name = "Frost Breath", power = 1.3, accuracy = 0.95, status = "freeze", statusChance = 0.2, description = "A chilling blast of frost." },
		{ name = "Hailstorm", power = 1.5, accuracy = 0.95, status = "freeze", statusChance = 0.2, description = "Ice falls from a clear sky." },
		{ name = "Blizzard", power = 1.85, accuracy = 0.9, description = "A raging blizzard attack." },
		{ name = "Deep Freeze", power = 2.1, accuracy = 0.8, description = "Winter, permanently." },
	},
	Shadow = {
		{ name = "Shadow Claw", power = 0.95, description = "A slash of dark energy." },
		{ name = "Dark Jab", power = 1.05, description = "A punch from somewhere unlit." },
		{ name = "Dark Pulse", power = 1.3, accuracy = 0.95, description = "A wave of shadow energy." },
		{ name = "Night Slash", power = 1.5, accuracy = 0.95, description = "A cut from the dark itself." },
		{ name = "Void Strike", power = 1.85, accuracy = 0.9, description = "An attack from the void itself." },
		{ name = "Total Eclipse", power = 2.1, accuracy = 0.8, description = "The light gives up." },
	},
}

-- ─── ABILITIES ──────────────────────────────────────────────────────────
-- Passive combat modifiers carried by the SPECIES (only Rare/Legendary have
-- one — chasing a rare should feel mechanically special). Assigned in
-- SpeciesAbilities below. Held items (further down) use the SAME effect
-- schema, so Combat.GatherEffects can merge an ability + a held item into one
-- list and apply them uniformly. Every effect key is optional:
--   outMult      flat outgoing-damage multiplier (gated by outType if set)
--   outType      only apply outMult when the attacker IS this type
--   vsType/vsMult  outgoing multiplier only when the DEFENDER is vsType
--   inMult       incoming-damage multiplier (defender side)
--   inVsType/inVsMult  incoming multiplier only when the ATTACKER is inVsType
--   critBonus    added to crit chance when attacking
--   berserkMult  outgoing multiplier while own HP < 1/3 (see Combat)
--   statusOutMult  multiplies your own move's status-proc chance
--   statusImmune true = cannot be burned/frozen/paralyzed
-- BALANCE: keep single-effect multipliers ≤1.3; stacked (ability+item)
-- ceilings land ~1.6x. Combat clamps nothing, so author conservatively.
StudData.Abilities = {
	-- Universal (shared across types for variety within a rarity)
	bruiser     = { name = "Bruiser",      icon = "💪", description = "+12% damage dealt.",                        outMult = 1.12 },
	berserker   = { name = "Berserker",    icon = "🩸", description = "+55% damage while below 1/3 HP.",           berserkMult = 1.55 },
	bulwark     = { name = "Bulwark",      icon = "🛡️", description = "-15% damage taken.",                        inMult = 0.85 },
	deadeye     = { name = "Deadeye",      icon = "🎯", description = "+15% critical-hit chance.",                 critBonus = 0.15 },
	juggernaut  = { name = "Juggernaut",   icon = "🐗", description = "+10% damage dealt, -10% taken.",            outMult = 1.10, inMult = 0.90 },
	glasscannon = { name = "Glass Cannon", icon = "💎", description = "+30% damage dealt, +15% taken.",            outMult = 1.30, inMult = 1.15 },
	stalwart    = { name = "Stalwart",     icon = "⛨",  description = "Immune to status effects, -6% taken.",      statusImmune = true, inMult = 0.94 },
	apex        = { name = "Apex",         icon = "👑", description = "+15% dealt, -12% taken, +5% crit.",          outMult = 1.15, inMult = 0.88, critBonus = 0.05 },
	-- Type signatures (thematic; usually type-gated)
	scorcher       = { name = "Scorcher",       icon = "🔥", description = "Double burn chance, +8% damage.",       statusOutMult = 2.0, outMult = 1.08 },
	undertow       = { name = "Undertow",       icon = "🌊", description = "+30% damage against Fire foes.",        vsType = "Fire", vsMult = 1.30 },
	photosynthesis = { name = "Photosynthesis", icon = "🌿", description = "-16% damage taken.",                    inMult = 0.84 },
	overcharge     = { name = "Overcharge",     icon = "⚡", description = "Double paralyze chance, +6% crit.",      statusOutMult = 2.0, critBonus = 0.06 },
	bedrock        = { name = "Bedrock",        icon = "🪨", description = "-22% damage taken.",                    inMult = 0.78 },
	deepfreeze     = { name = "Deep Freeze",    icon = "❄️", description = "Double freeze chance, +6% damage.",      statusOutMult = 2.0, outMult = 1.06 },
	ambush         = { name = "Ambush",         icon = "🌑", description = "+20% critical-hit chance.",             critBonus = 0.20 },
}

-- Which ability each Rare/Legendary species carries (Common/Uncommon: none).
-- Kept as a lookup table rather than a field on each species so the Studs list
-- stays readable and abilities can be retuned in one place.
StudData.SpeciesAbilities = {
	-- Fire
	bruce = "berserker", diane = "bruiser", craig = "scorcher", bob = "apex", karen = "glasscannon",
	-- Water
	cheryl = "undertow", dennis = "deadeye", gail = "bulwark", ted = "apex", barb = "juggernaut",
	-- Grass
	norm = "photosynthesis", sheila = "bruiser", wayne = "berserker", greg = "apex", ethel = "bulwark",
	-- Electric
	rick = "overcharge", cindy = "deadeye", neil = "glasscannon", chuck = "apex", pam = "berserker",
	-- Rock
	walt = "bedrock", marcia = "bulwark", bert = "bruiser", al = "apex", doris = "stalwart",
	-- Ice
	kirk = "deepfreeze", bonnie = "bulwark", roy = "deadeye", gus = "apex", edna = "glasscannon",
	-- Shadow
	dean = "ambush", vicky = "berserker", boyd = "deadeye", hal = "apex", myrna = "glasscannon",
}

-- ─── HELD ITEMS ─────────────────────────────────────────────────────────
-- Permanent equips (one slot per species — see data.heldItems in SaveManager).
-- Same effect schema as abilities. `island`/`typeLock` drive the shop:
--   island = nil  → sold at every island's shop; else only on that island
--   typeLock = "Fire" → only equippable on Fire studs (nil = any)
-- Island-exclusive items are BOTH sold only on their island AND type-locked,
-- so they reward travelling to the island whose studs they empower.
StudData.HeldItems = {
	-- Universal (any island, any stud)
	power_band  = { name = "Power Band",  icon = "💪", price = 400, description = "+10% damage dealt.",       outMult = 1.10 },
	guard_stone = { name = "Guard Stone", icon = "🛡️", price = 400, description = "-12% damage taken.",       inMult = 0.88 },
	keen_lens   = { name = "Keen Lens",   icon = "🔎", price = 350, description = "+10% critical-hit chance.", critBonus = 0.10 },
	focus_charm = { name = "Focus Charm", icon = "🧿", price = 500, description = "Immune to status effects.", statusImmune = true },
	-- Island-exclusive + type-locked
	verdant_charm = { name = "Verdant Charm", icon = "🌿", price = 800, island = "Studville",    typeLock = "Grass",    description = "Grass only: +15% dealt, -8% taken.",      outMult = 1.15, inMult = 0.92 },
	storm_coil    = { name = "Storm Coil",    icon = "⚡", price = 800, island = "Studville",    typeLock = "Electric", description = "Electric only: +15% crit, +50% paralyze.", critBonus = 0.15, statusOutMult = 1.5 },
	tidal_pearl   = { name = "Tidal Pearl",   icon = "🫧", price = 900, island = "TidepoolCove", typeLock = "Water",    description = "Water only: +12% dealt, +20% vs Fire.",    outMult = 1.12, vsType = "Fire", vsMult = 1.20 },
	frost_lens    = { name = "Frost Lens",    icon = "❄️", price = 900, island = "TidepoolCove", typeLock = "Ice",      description = "Ice only: double freeze, +5% dealt.",      statusOutMult = 2.0, outMult = 1.05 },
	cinder_charm  = { name = "Cinder Charm",  icon = "🔥", price = 900, island = "Emberpeak",    typeLock = "Fire",     description = "Fire only: double burn, +8% dealt.",       statusOutMult = 2.0, outMult = 1.08 },
	magma_core    = { name = "Magma Core",    icon = "🌋", price = 900, island = "Emberpeak",    typeLock = "Rock",     description = "Rock only: -20% taken, +5% dealt.",        inMult = 0.80, outMult = 1.05 },
	umbral_totem  = { name = "Umbral Totem",  icon = "🌑", price = 900, island = "Emberpeak",    typeLock = "Shadow",   description = "Shadow only: +20% critical-hit chance.",   critBonus = 0.20 },
}

-- Ability def for a species (table or id), or nil for Common/Uncommon.
function StudData.GetAbility(studOrId)
	local id = type(studOrId) == "table" and studOrId.id or studOrId
	local abilityId = id and StudData.SpeciesAbilities[id]
	return abilityId and StudData.Abilities[abilityId] or nil
end

-- Held-item def by id (nil-safe).
function StudData.GetHeldItem(itemId)
	return itemId and StudData.HeldItems[itemId] or nil
end

-- Items purchasable at a given island's shop: every universal held item plus
-- that island's exclusives. Unknown/nil island → universal only. Each entry is
-- a shallow clone with `.id` set, sorted by price then id for a stable UI.
function StudData.GetShopHeldItems(islandName)
	local list = {}
	for id, item in pairs(StudData.HeldItems) do
		if item.island == nil or item.island == islandName then
			local entry = table.clone(item)
			entry.id = id
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) < (b.price or 0) end
		return a.id < b.id
	end)
	return list
end

-- Is this item sold at islandName? (Universal items sell everywhere.) The
-- server checks this on purchase so island exclusives can't be bought remotely.
function StudData.IsHeldItemSoldAt(itemId, islandName)
	local item = StudData.HeldItems[itemId]
	if not item then return false end
	return item.island == nil or item.island == islandName
end

-- Can this item be equipped on a stud of studType? Enforces typeLock.
function StudData.CanEquipHeldItem(itemId, studType)
	local item = StudData.HeldItems[itemId]
	if not item then return false end
	if item.typeLock and item.typeLock ~= studType then return false end
	return true
end

-- All Studs indexed by ID. `moves` = {lightIdx, midIdx, heavyIdx} into the
-- type's move pool. Stat archetypes: bruiser (atk), tank (def), runner (spd),
-- or balanced — so species within a rarity play differently (see Combat).
StudData.Studs = {
	-- ── Fire ────────────────────────────────────────────────────────────
	{ id = "gary",    name = "Gary",    studType = "Fire", rarity = "Common", description = "Gary runs warm. Doctors say it's fine.",
		stats = { attack = 12, defense = 8, speed = 10 }, moves = { 1, 3, 5 } },
	{ id = "doug",    name = "Doug",    studType = "Fire", rarity = "Common", description = "Doug once grilled for nine straight hours.",
		stats = { attack = 14, defense = 7, speed = 8 }, moves = { 2, 4, 5 } },
	{ id = "phil",    name = "Phil",    studType = "Fire", rarity = "Common", description = "Phil is a slow burn. Literally and socially.",
		stats = { attack = 9, defense = 12, speed = 8 }, moves = { 2, 4, 6 } },
	{ id = "todd",    name = "Todd",    studType = "Fire", rarity = "Common", description = "Todd sparks when he's excited, which is always.",
		stats = { attack = 10, defense = 6, speed = 14 }, moves = { 1, 3, 6 } },
	{ id = "carol",   name = "Carol",   studType = "Fire", rarity = "Common", description = "Carol keeps the whole meadow at a cozy 78°F.",
		stats = { attack = 11, defense = 10, speed = 9 }, moves = { 2, 3, 5 } },
	{ id = "brenda",  name = "Brenda",  studType = "Fire", rarity = "Common", description = "Brenda's glare has been known to toast bread.",
		stats = { attack = 13, defense = 8, speed = 9 }, moves = { 1, 4, 6 } },
	{ id = "kevin",   name = "Kevin",   studType = "Fire", rarity = "Uncommon", description = "Kevin peaked in high school and never cooled down.",
		stats = { attack = 20, defense = 12, speed = 14 }, moves = { 1, 3, 5 } },
	{ id = "linda",   name = "Linda",   studType = "Fire", rarity = "Uncommon", description = "Linda's temper is a registered heat source.",
		stats = { attack = 21, defense = 10, speed = 15 }, moves = { 1, 4, 6 } },
	{ id = "frank",   name = "Frank",   studType = "Fire", rarity = "Uncommon", description = "Frank smolders quietly and holds a grudge.",
		stats = { attack = 15, defense = 20, speed = 11 }, moves = { 2, 4, 5 } },
	{ id = "marge",   name = "Marge",   studType = "Fire", rarity = "Uncommon", description = "Marge bakes. Nobody asks what.",
		stats = { attack = 17, defense = 15, speed = 14 }, moves = { 2, 3, 6 } },
	{ id = "bruce",   name = "Bruce",   studType = "Fire", rarity = "Rare", description = "Bruce does hot yoga. Bruce IS hot yoga.",
		stats = { attack = 30, defense = 17, speed = 20 }, moves = { 1, 4, 5 } },
	{ id = "diane",   name = "Diane",   studType = "Fire", rarity = "Rare", description = "Diane's book club ends in flames every month.",
		stats = { attack = 24, defense = 22, speed = 21 }, moves = { 2, 3, 6 } },
	{ id = "craig",   name = "Craig",   studType = "Fire", rarity = "Rare", description = "Craig is banned from three fireworks stores.",
		stats = { attack = 26, defense = 15, speed = 27 }, moves = { 1, 3, 6 } },
	{ id = "bob",     name = "Bob",     studType = "Fire", rarity = "Legendary", description = "Bob invented fire. He doesn't bring it up.",
		stats = { attack = 38, defense = 25, speed = 29 }, moves = { 1, 4, 6 } },
	{ id = "karen",   name = "Karen",   studType = "Fire", rarity = "Legendary", description = "Karen would like to speak to the sun's manager.",
		stats = { attack = 36, defense = 22, speed = 34 }, moves = { 2, 3, 5 } },

	-- ── Water ───────────────────────────────────────────────────────────
	{ id = "susan",   name = "Susan",   studType = "Water", rarity = "Common", description = "Susan is 90% water. The rest is opinions.",
		stats = { attack = 10, defense = 12, speed = 8 }, moves = { 1, 3, 5 } },
	{ id = "dave",    name = "Dave",    studType = "Water", rarity = "Common", description = "Dave drips. It's a lifestyle.",
		stats = { attack = 12, defense = 10, speed = 9 }, moves = { 2, 4, 5 } },
	{ id = "wendy",   name = "Wendy",   studType = "Water", rarity = "Common", description = "Wendy makes waves at every gathering.",
		stats = { attack = 9, defense = 9, speed = 13 }, moves = { 1, 3, 6 } },
	{ id = "brian",   name = "Brian",   studType = "Water", rarity = "Common", description = "Brian is technically a puddle with ambition.",
		stats = { attack = 8, defense = 14, speed = 7 }, moves = { 2, 4, 6 } },
	{ id = "paula",   name = "Paula",   studType = "Water", rarity = "Common", description = "Paula's small talk is measurably damp.",
		stats = { attack = 11, defense = 11, speed = 9 }, moves = { 2, 3, 5 } },
	{ id = "keith",   name = "Keith",   studType = "Water", rarity = "Common", description = "Keith has never once dried off.",
		stats = { attack = 13, defense = 8, speed = 10 }, moves = { 1, 4, 5 } },
	{ id = "sandra",  name = "Sandra",  studType = "Water", rarity = "Uncommon", description = "Sandra does laps around the reef. For fun.",
		stats = { attack = 14, defense = 13, speed = 20 }, moves = { 1, 3, 5 } },
	{ id = "gene",    name = "Gene",    studType = "Water", rarity = "Uncommon", description = "Gene keeps his cool. All of it. Always.",
		stats = { attack = 13, defense = 21, speed = 12 }, moves = { 2, 4, 6 } },
	{ id = "rhonda",  name = "Rhonda",  studType = "Water", rarity = "Uncommon", description = "Rhonda's cannonball emptied a public pool.",
		stats = { attack = 21, defense = 13, speed = 13 }, moves = { 1, 4, 5 } },
	{ id = "marty",   name = "Marty",   studType = "Water", rarity = "Uncommon", description = "Marty flows downhill and calls it strategy.",
		stats = { attack = 16, defense = 16, speed = 15 }, moves = { 2, 3, 6 } },
	{ id = "cheryl",  name = "Cheryl",  studType = "Water", rarity = "Rare", description = "Cheryl has a rip current where a hug should be.",
		stats = { attack = 24, defense = 25, speed = 18 }, moves = { 1, 4, 5 } },
	{ id = "dennis",  name = "Dennis",  studType = "Water", rarity = "Rare", description = "Dennis holds his breath indefinitely. He IS the water.",
		stats = { attack = 18, defense = 31, speed = 16 }, moves = { 2, 4, 6 } },
	{ id = "gail",    name = "Gail",    studType = "Water", rarity = "Rare", description = "Gail is a storm warning with a nice smile.",
		stats = { attack = 23, defense = 16, speed = 28 }, moves = { 1, 3, 6 } },
	{ id = "ted",     name = "Ted",     studType = "Water", rarity = "Legendary", description = "Ted moves tides. He calls it 'stretching'.",
		stats = { attack = 32, defense = 36, speed = 24 }, moves = { 2, 4, 5 } },
	{ id = "barb",    name = "Barb",    studType = "Water", rarity = "Legendary", description = "Barb is why sailors knock on wood.",
		stats = { attack = 35, defense = 26, speed = 31 }, moves = { 1, 3, 6 } },

	-- ── Grass ───────────────────────────────────────────────────────────
	{ id = "terry",   name = "Terry",   studType = "Grass", rarity = "Common", description = "Terry photosynthesizes out of spite.",
		stats = { attack = 8, defense = 10, speed = 12 }, moves = { 1, 3, 5 } },
	{ id = "joyce",   name = "Joyce",   studType = "Grass", rarity = "Common", description = "Joyce composts her enemies. Eventually.",
		stats = { attack = 10, defense = 12, speed = 8 }, moves = { 2, 4, 6 } },
	{ id = "alan",    name = "Alan",    studType = "Grass", rarity = "Common", description = "Alan is mostly lawn. Do not mow Alan.",
		stats = { attack = 8, defense = 14, speed = 8 }, moves = { 2, 4, 5 } },
	{ id = "peggy",   name = "Peggy",   studType = "Grass", rarity = "Common", description = "Peggy grows on people. Like ivy.",
		stats = { attack = 9, defense = 8, speed = 14 }, moves = { 1, 3, 6 } },
	{ id = "stan",    name = "Stan",    studType = "Grass", rarity = "Common", description = "Stan hasn't moved since spring. He's thriving.",
		stats = { attack = 12, defense = 11, speed = 7 }, moves = { 2, 3, 5 } },
	{ id = "rita",    name = "Rita",    studType = "Grass", rarity = "Common", description = "Rita's garden gnomes report to her.",
		stats = { attack = 11, defense = 9, speed = 11 }, moves = { 1, 4, 5 } },
	{ id = "herb",    name = "Herb",    studType = "Grass", rarity = "Uncommon", description = "Herb. His name is Herb. He's a plant. Herb.",
		stats = { attack = 14, defense = 16, speed = 18 }, moves = { 1, 3, 5 } },
	{ id = "donna",   name = "Donna",   studType = "Grass", rarity = "Uncommon", description = "Donna's roots run deeper than your family drama.",
		stats = { attack = 13, defense = 22, speed = 11 }, moves = { 2, 4, 6 } },
	{ id = "roger",   name = "Roger",   studType = "Grass", rarity = "Uncommon", description = "Roger swings vine to vine to avoid small talk.",
		stats = { attack = 15, defense = 12, speed = 21 }, moves = { 1, 3, 6 } },
	{ id = "faye",    name = "Faye",    studType = "Grass", rarity = "Uncommon", description = "Faye's allergies are other people.",
		stats = { attack = 20, defense = 13, speed = 14 }, moves = { 2, 4, 5 } },
	{ id = "norm",    name = "Norm",    studType = "Grass", rarity = "Rare", description = "Norm is old growth. Respect the rings.",
		stats = { attack = 21, defense = 26, speed = 20 }, moves = { 2, 4, 5 } },
	{ id = "sheila",  name = "Sheila",  studType = "Grass", rarity = "Rare", description = "Sheila's thorns have their own thorns.",
		stats = { attack = 28, defense = 18, speed = 21 }, moves = { 1, 4, 6 } },
	{ id = "wayne",   name = "Wayne",   studType = "Grass", rarity = "Rare", description = "Wayne runs a hedge fund. It's a fund of hedges.",
		stats = { attack = 20, defense = 17, speed = 30 }, moves = { 1, 3, 6 } },
	{ id = "greg",    name = "Greg",    studType = "Grass", rarity = "Legendary", description = "Greg remembers when this was all fields. He was the fields.",
		stats = { attack = 30, defense = 32, speed = 32 }, moves = { 2, 4, 6 } },
	{ id = "ethel",   name = "Ethel",   studType = "Grass", rarity = "Legendary", description = "Ethel's houseplants fear disappointing her.",
		stats = { attack = 34, defense = 24, speed = 33 }, moves = { 1, 3, 5 } },

	-- ── Electric ────────────────────────────────────────────────────────
	{ id = "chad",    name = "Chad",    studType = "Electric", rarity = "Common", description = "Chad is fully charged and it shows.",
		stats = { attack = 14, defense = 6, speed = 14 }, moves = { 1, 3, 5 } },
	{ id = "tina",    name = "Tina",    studType = "Electric", rarity = "Common", description = "Tina shocks people. Conversationally and otherwise.",
		stats = { attack = 12, defense = 8, speed = 13 }, moves = { 2, 3, 6 } },
	{ id = "randy",   name = "Randy",   studType = "Electric", rarity = "Common", description = "Randy licked a battery once. Now he is one.",
		stats = { attack = 13, defense = 9, speed = 11 }, moves = { 1, 4, 5 } },
	{ id = "deb",     name = "Deb",     studType = "Electric", rarity = "Common", description = "Deb hums at exactly 60 hertz.",
		stats = { attack = 10, defense = 11, speed = 12 }, moves = { 2, 4, 6 } },
	{ id = "larry",   name = "Larry",   studType = "Electric", rarity = "Common", description = "Larry shuffles on carpet before every handshake.",
		stats = { attack = 11, defense = 7, speed = 15 }, moves = { 1, 3, 6 } },
	{ id = "kim",     name = "Kim",     studType = "Electric", rarity = "Common", description = "Kim's phone has never been below 100%.",
		stats = { attack = 12, defense = 10, speed = 12 }, moves = { 2, 4, 5 } },
	{ id = "vince",   name = "Vince",   studType = "Electric", rarity = "Uncommon", description = "Vince jump-starts cars by pointing at them.",
		stats = { attack = 21, defense = 9, speed = 19 }, moves = { 1, 4, 5 } },
	{ id = "tammy",   name = "Tammy",   studType = "Electric", rarity = "Uncommon", description = "Tammy's hair has been like that since the incident.",
		stats = { attack = 18, defense = 11, speed = 20 }, moves = { 1, 3, 6 } },
	{ id = "earl",    name = "Earl",    studType = "Electric", rarity = "Uncommon", description = "Earl grounds himself. Emotionally, too.",
		stats = { attack = 14, defense = 19, speed = 14 }, moves = { 2, 4, 6 } },
	{ id = "jan",     name = "Jan",     studType = "Electric", rarity = "Uncommon", description = "Jan is the reason your wifi flickers.",
		stats = { attack = 16, defense = 12, speed = 21 }, moves = { 2, 3, 5 } },
	{ id = "rick",    name = "Rick",    studType = "Electric", rarity = "Rare", description = "Rick strikes twice. Rules don't apply to Rick.",
		stats = { attack = 29, defense = 13, speed = 28 }, moves = { 1, 3, 5 } },
	{ id = "cindy",   name = "Cindy",   studType = "Electric", rarity = "Rare", description = "Cindy powers the town when she's in a good mood.",
		stats = { attack = 24, defense = 20, speed = 23 }, moves = { 2, 4, 5 } },
	{ id = "neil",    name = "Neil",    studType = "Electric", rarity = "Rare", description = "Neil moves at the speed of light gossip.",
		stats = { attack = 21, defense = 12, speed = 33 }, moves = { 1, 3, 6 } },
	{ id = "chuck",   name = "Chuck",   studType = "Electric", rarity = "Legendary", description = "Chuck IS the storm the weatherman apologized for.",
		stats = { attack = 39, defense = 19, speed = 36 }, moves = { 1, 4, 6 } },
	{ id = "pam",     name = "Pam",     studType = "Electric", rarity = "Legendary", description = "Pam short-circuited the northern lights. Allegedly.",
		stats = { attack = 34, defense = 24, speed = 38 }, moves = { 2, 3, 5 } },

	-- ── Rock ────────────────────────────────────────────────────────────
	{ id = "steve",   name = "Steve",   studType = "Rock", rarity = "Common", description = "Steve is a rock. Steve is doing great.",
		stats = { attack = 8, defense = 14, speed = 6 }, moves = { 1, 3, 5 } },
	{ id = "nancy",   name = "Nancy",   studType = "Rock", rarity = "Common", description = "Nancy collects rocks. It's complicated.",
		stats = { attack = 9, defense = 13, speed = 8 }, moves = { 2, 4, 6 } },
	{ id = "bill",    name = "Bill",    studType = "Rock", rarity = "Common", description = "Bill has been leaning on that fence since 2019.",
		stats = { attack = 11, defense = 12, speed = 7 }, moves = { 2, 3, 5 } },
	{ id = "ruth",    name = "Ruth",    studType = "Rock", rarity = "Common", description = "Ruth is sedimentary, my dear.",
		stats = { attack = 7, defense = 16, speed = 6 }, moves = { 2, 4, 5 } },
	{ id = "hank",    name = "Hank",    studType = "Rock", rarity = "Common", description = "Hank skips across ponds. Against his will.",
		stats = { attack = 12, defense = 10, speed = 9 }, moves = { 1, 4, 5 } },
	{ id = "lois",    name = "Lois",    studType = "Rock", rarity = "Common", description = "Lois holds doors open. Permanently. She's a doorstop.",
		stats = { attack = 10, defense = 15, speed = 5 }, moves = { 1, 3, 6 } },
	{ id = "carl",    name = "Carl",    studType = "Rock", rarity = "Uncommon", description = "Carl takes 'set in his ways' literally.",
		stats = { attack = 14, defense = 23, speed = 9 }, moves = { 1, 3, 5 } },
	{ id = "betty",   name = "Betty",   studType = "Rock", rarity = "Uncommon", description = "Betty's fruitcake doubles as a paving stone.",
		stats = { attack = 16, defense = 20, speed = 11 }, moves = { 2, 4, 6 } },
	{ id = "ron",     name = "Ron",     studType = "Rock", rarity = "Uncommon", description = "Ron hasn't budged an inch. Ask his wife.",
		stats = { attack = 20, defense = 17, speed = 10 }, moves = { 1, 4, 5 } },
	{ id = "gladys",  name = "Gladys",  studType = "Rock", rarity = "Uncommon", description = "Gladys rolls downhill exactly once a year, for the festival.",
		stats = { attack = 13, defense = 18, speed = 16 }, moves = { 2, 3, 6 } },
	{ id = "walt",    name = "Walt",    studType = "Rock", rarity = "Rare", description = "Walt is load-bearing. Do not remove Walt.",
		stats = { attack = 19, defense = 33, speed = 13 }, moves = { 2, 4, 5 } },
	{ id = "marcia",  name = "Marcia",  studType = "Rock", rarity = "Rare", description = "Marcia is granite countertop royalty.",
		stats = { attack = 25, defense = 26, speed = 15 }, moves = { 1, 4, 6 } },
	{ id = "bert",    name = "Bert",    studType = "Rock", rarity = "Rare", description = "Bert took up jogging. Seismographs noticed.",
		stats = { attack = 27, defense = 20, speed = 19 }, moves = { 1, 3, 5 } },
	{ id = "al",      name = "Al",      studType = "Rock", rarity = "Legendary", description = "Al is the mountain they named after Al.",
		stats = { attack = 28, defense = 41, speed = 18 }, moves = { 2, 4, 6 } },
	{ id = "doris",   name = "Doris",   studType = "Rock", rarity = "Legendary", description = "Doris predates the continent she's standing on.",
		stats = { attack = 33, defense = 34, speed = 22 }, moves = { 1, 3, 5 } },

	-- ── Ice ─────────────────────────────────────────────────────────────
	{ id = "brad",    name = "Brad",    studType = "Ice", rarity = "Common", description = "Brad keeps things chill. Aggressively.",
		stats = { attack = 10, defense = 10, speed = 10 }, moves = { 1, 3, 5 } },
	{ id = "judy",    name = "Judy",    studType = "Ice", rarity = "Common", description = "Judy's handshake requires mittens.",
		stats = { attack = 9, defense = 13, speed = 9 }, moves = { 2, 4, 6 } },
	{ id = "glen",    name = "Glen",    studType = "Ice", rarity = "Common", description = "Glen is what's left of a snowman with a plan.",
		stats = { attack = 12, defense = 9, speed = 10 }, moves = { 1, 4, 5 } },
	{ id = "elaine",  name = "Elaine",  studType = "Ice", rarity = "Common", description = "Elaine's stare lowers the room rate.",
		stats = { attack = 11, defense = 8, speed = 13 }, moves = { 1, 3, 6 } },
	{ id = "curt",    name = "Curt",    studType = "Ice", rarity = "Common", description = "Curt is, in every sense, an ice cube.",
		stats = { attack = 8, defense = 15, speed = 7 }, moves = { 2, 4, 5 } },
	{ id = "sue",     name = "Sue",     studType = "Ice", rarity = "Common", description = "Sue scrapes windshields with her personality.",
		stats = { attack = 12, defense = 11, speed = 8 }, moves = { 2, 3, 5 } },
	{ id = "lance",   name = "Lance",   studType = "Ice", rarity = "Uncommon", description = "Lance is an icicle with sponsorship deals.",
		stats = { attack = 18, defense = 12, speed = 18 }, moves = { 1, 3, 5 } },
	{ id = "vera",    name = "Vera",    studType = "Ice", rarity = "Uncommon", description = "Vera shimmers with inner cold light.",
		stats = { attack = 15, defense = 17, speed = 16 }, moves = { 2, 3, 6 } },
	{ id = "dale",    name = "Dale",    studType = "Ice", rarity = "Uncommon", description = "Dale zambonis the lake nightly. Nobody hired him.",
		stats = { attack = 13, defense = 21, speed = 13 }, moves = { 2, 4, 5 } },
	{ id = "nadine",  name = "Nadine",  studType = "Ice", rarity = "Uncommon", description = "Nadine's freezer burn is a battle technique.",
		stats = { attack = 20, defense = 13, speed = 14 }, moves = { 1, 4, 6 } },
	{ id = "kirk",    name = "Kirk",    studType = "Ice", rarity = "Rare", description = "Kirk moves slow and freezes everything he touches.",
		stats = { attack = 24, defense = 27, speed = 15 }, moves = { 2, 4, 5 } },
	{ id = "bonnie",  name = "Bonnie",  studType = "Ice", rarity = "Rare", description = "Bonnie is a blizzard with a bake sale.",
		stats = { attack = 26, defense = 18, speed = 23 }, moves = { 1, 3, 6 } },
	{ id = "roy",     name = "Roy",     studType = "Ice", rarity = "Rare", description = "Roy skates everywhere. There is not always ice.",
		stats = { attack = 20, defense = 16, speed = 31 }, moves = { 1, 3, 5 } },
	{ id = "gus",     name = "Gus",     studType = "Ice", rarity = "Legendary", description = "Gus is absolute zero with a flannel shirt.",
		stats = { attack = 34, defense = 34, speed = 30 }, moves = { 2, 4, 6 } },
	{ id = "edna",    name = "Edna",    studType = "Ice", rarity = "Legendary", description = "Edna ended an ice age by asking it to leave.",
		stats = { attack = 31, defense = 29, speed = 36 }, moves = { 1, 3, 5 } },

	-- ── Shadow (night-exclusive) ────────────────────────────────────────
	{ id = "wade",    name = "Wade",    studType = "Shadow", rarity = "Common", description = "Wade is standing behind you. He's always been.",
		stats = { attack = 12, defense = 8, speed = 12 }, moves = { 1, 3, 5 } },
	{ id = "mona",    name = "Mona",    studType = "Shadow", rarity = "Common", description = "Mona is the draft under your door.",
		stats = { attack = 10, defense = 10, speed = 12 }, moves = { 2, 3, 6 } },
	{ id = "lyle",    name = "Lyle",    studType = "Shadow", rarity = "Common", description = "Lyle flickers when the lights do. Or vice versa.",
		stats = { attack = 11, defense = 7, speed = 14 }, moves = { 1, 4, 5 } },
	{ id = "tricia",  name = "Tricia",  studType = "Shadow", rarity = "Common", description = "Tricia's shadow casts a Tricia.",
		stats = { attack = 13, defense = 9, speed = 10 }, moves = { 2, 4, 6 } },
	{ id = "vern",    name = "Vern",    studType = "Shadow", rarity = "Common", description = "Vern lives in your peripheral vision.",
		stats = { attack = 9, defense = 12, speed = 11 }, moves = { 2, 4, 5 } },
	{ id = "nina",    name = "Nina",    studType = "Shadow", rarity = "Common", description = "Nina is why the basement light stays on.",
		stats = { attack = 12, defense = 6, speed = 14 }, moves = { 1, 3, 6 } },
	{ id = "cliff",   name = "Cliff",   studType = "Shadow", rarity = "Uncommon", description = "Cliff is a ghost story that files taxes.",
		stats = { attack = 18, defense = 12, speed = 18 }, moves = { 1, 3, 5 } },
	{ id = "sonia",   name = "Sonia",   studType = "Shadow", rarity = "Uncommon", description = "Sonia hums lullabies from inside the walls.",
		stats = { attack = 15, defense = 17, speed = 16 }, moves = { 2, 4, 6 } },
	{ id = "rex",     name = "Rex",     studType = "Shadow", rarity = "Uncommon", description = "Rex fetches things that were never thrown.",
		stats = { attack = 21, defense = 10, speed = 17 }, moves = { 1, 4, 5 } },
	{ id = "opal",    name = "Opal",    studType = "Shadow", rarity = "Uncommon", description = "Opal collects the dark from under beds.",
		stats = { attack = 14, defense = 15, speed = 19 }, moves = { 2, 3, 6 } },
	{ id = "dean",    name = "Dean",    studType = "Shadow", rarity = "Rare", description = "Dean appears and vanishes without a trace. Or a reason.",
		stats = { attack = 27, defense = 17, speed = 26 }, moves = { 1, 4, 5 } },
	{ id = "vicky",   name = "Vicky",   studType = "Shadow", rarity = "Rare", description = "Vicky borrowed the night once. Kept it.",
		stats = { attack = 22, defense = 24, speed = 22 }, moves = { 2, 3, 6 } },
	{ id = "boyd",    name = "Boyd",    studType = "Shadow", rarity = "Rare", description = "Boyd is the silence right before the fridge hums.",
		stats = { attack = 24, defense = 14, speed = 32 }, moves = { 1, 3, 6 } },
	{ id = "hal",     name = "Hal",     studType = "Shadow", rarity = "Legendary", description = "Hal was born when the light surrendered.",
		stats = { attack = 37, defense = 23, speed = 36 }, moves = { 1, 4, 6 } },
	{ id = "myrna",   name = "Myrna",   studType = "Shadow", rarity = "Legendary", description = "Myrna knits with threads of midnight. Sells scarves.",
		stats = { attack = 33, defense = 28, speed = 35 }, moves = { 2, 3, 5 } },
}

-- ─── LOOKUP INDEXES (built once at load) ────────────────────────────────
-- PERF: GetStudById used to linear-scan Studs and is called from loops over
-- entire collections (quests, battles, trades) — O(dex) per call adds up
-- fast at 105 species. These indexes make every lookup O(1).
local studById = {}
local studsByType = {}
local studsByRarity = {}
local studsByTypeRarity = {} -- [type][rarity] = { stud, ... }
local movesetById = {} -- [id] = resolved 3-move list with unlockLevel

for _, stud in ipairs(StudData.Studs) do
	studById[stud.id] = stud

	studsByType[stud.studType] = studsByType[stud.studType] or {}
	table.insert(studsByType[stud.studType], stud)

	studsByRarity[stud.rarity] = studsByRarity[stud.rarity] or {}
	table.insert(studsByRarity[stud.rarity], stud)

	studsByTypeRarity[stud.studType] = studsByTypeRarity[stud.studType] or {}
	local byRarity = studsByTypeRarity[stud.studType]
	byRarity[stud.rarity] = byRarity[stud.rarity] or {}
	table.insert(byRarity[stud.rarity], stud)

	-- Resolve the species kit: pool indices -> concrete move tables with
	-- slot-based unlock levels (1/10/25/50). Slot 4 is the species' OTHER
	-- heavy: kits with the swingy 2.1x learn the reliable 1.85x at Lv50
	-- and vice versa.
	local pool = StudData.TypeMovePools[stud.studType]
	local kitIdx = stud.moves or { 1, 3, 5 }
	local slotIdx = { kitIdx[1], kitIdx[2], kitIdx[3], kitIdx[3] == 6 and 5 or 6 }
	local kit = {}
	for slot = 1, 4 do
		local poolMove = pool[slotIdx[slot]] or pool[slot]
		kit[slot] = {
			name = poolMove.name,
			power = poolMove.power,
			accuracy = poolMove.accuracy,
			status = poolMove.status,
			statusChance = poolMove.statusChance,
			description = poolMove.description,
			unlockLevel = StudData.MoveUnlockLevels[slot],
		}
	end
	movesetById[stud.id] = kit
end

-- Default per-type kit (used when only a type is known): light/mid/heavy/heavy
local defaultTypeMoves = {}
for typeName, pool in pairs(StudData.TypeMovePools) do
	local kit = {}
	for slot, poolIdx in ipairs({ 1, 3, 5, 6 }) do
		local poolMove = pool[poolIdx]
		kit[slot] = {
			name = poolMove.name,
			power = poolMove.power,
			accuracy = poolMove.accuracy,
			status = poolMove.status,
			statusChance = poolMove.statusChance,
			description = poolMove.description,
			unlockLevel = StudData.MoveUnlockLevels[slot],
		}
	end
	defaultTypeMoves[typeName] = kit
end

-- Helper: get a Stud by its ID — O(1) index lookup
function StudData.GetStudById(id)
	return studById[id]
end

-- Helper: get all Studs of a given type
function StudData.GetStudsByType(studType)
	return studsByType[studType] or {}
end

-- Helper: get all Studs of a given rarity
function StudData.GetStudsByRarity(rarity)
	return studsByRarity[rarity] or {}
end

-- Helper: get the Color3 for a Stud (based on its type)
function StudData.GetStudColor(stud)
	local typeData = StudData.Types[stud.studType]
	if typeData then
		return typeData.color
	end
	return Color3.fromRGB(200, 200, 200)
end

-- Helper: get rarity config for catching minigame
function StudData.GetRarityConfig(rarityName)
	return StudData.Rarity[rarityName]
end

-- Helper: moves for a stud. Accepts a stud table (anything with .id), a stud
-- id, or — legacy — a type name (returns that type's default kit). Species
-- ids are lowercase names and type names are capitalized, so they can't
-- collide.
function StudData.GetMoves(studOrId)
	local key
	if type(studOrId) == "table" then
		key = studOrId.id
	elseif type(studOrId) == "string" then
		key = studOrId
	end
	if key and movesetById[key] then
		return movesetById[key]
	end
	if type(studOrId) == "table" then
		return defaultTypeMoves[studOrId.studType] or defaultTypeMoves.Fire
	end
	return defaultTypeMoves[studOrId] or defaultTypeMoves.Fire
end

-- Helper: is this move usable at this level? (nil unlockLevel = always)
function StudData.IsMoveUnlocked(move, level)
	return (level or 1) >= (move.unlockLevel or 1)
end

-- Sell values by rarity
StudData.SellValues = {
	Common = 5,
	Uncommon = 15,
	Rare = 30,
	Legendary = 75,
}

-- Helper: get sell price for a stud (scales +15% per level above 1)
function StudData.GetSellValue(studId, level)
	local stud = StudData.GetStudById(studId)
	if not stud then return 5 end
	local base = StudData.SellValues[stud.rarity] or 5
	level = math.clamp(tonumber(level) or 1, 1, StudData.MAX_LEVEL)
	return math.floor(base * (1 + 0.15 * (level - 1)) + 0.5)
end

-- ─── LEVELING SYSTEM ────────────────────────────────────────────────────
StudData.MAX_LEVEL = 100

-- EXP required to go from `level` to `level + 1`
function StudData.GetExpToLevel(level)
	return math.floor(20 + (level ^ 1.4) * 8)
end

-- EXP earned for a win, relative to the opponent's level vs your own.
-- Beating a higher-level Stud pays much more; beating a lower one pays less.
function StudData.GetExpReward(winnerLevel, loserLevel)
	winnerLevel = math.max(1, winnerLevel or 1)
	loserLevel = math.max(1, loserLevel or 1)
	local ratio = loserLevel / winnerLevel -- 2.5 at lvl2 vs lvl5, 0.5 at lvl2 vs lvl1
	local exp = 12 * loserLevel * math.clamp(ratio, 0.35, 3.0)
	return math.max(1, math.floor(exp + 0.5))
end

-- Damage multiplier from level (+5% per level above 1)
function StudData.GetLevelDamageMultiplier(level)
	level = math.clamp(tonumber(level) or 1, 1, StudData.MAX_LEVEL)
	return 1 + 0.05 * (level - 1)
end

-- Defense multiplier from level: incoming damage is divided by this
-- (+3% per level above 1). Kept below the attack curve so same-level
-- fights still trend offensive alongside the +8%/level HP curve.
function StudData.GetLevelDefenseMultiplier(level)
	level = math.clamp(tonumber(level) or 1, 1, StudData.MAX_LEVEL)
	return 1 + 0.03 * (level - 1)
end

-- Helper: get max HP based on rarity, scaled +8% per level above 1
function StudData.GetMaxHP(rarity, level)
	local hpTable = {
		Common = 80,
		Uncommon = 100,
		Rare = 130,
		Legendary = 180,
	}
	local base = hpTable[rarity] or 80
	level = math.clamp(tonumber(level) or 1, 1, StudData.MAX_LEVEL)
	return math.floor(base * (1 + 0.08 * (level - 1)) + 0.5)
end

-- ─── ZONE LEVEL BANDS ───────────────────────────────────────────────────
-- Wild stud level range per WORLD. Before this, wild levels were always the
-- player's level ±2 everywhere, so no region was ever dangerous or trivial.
-- Now exploration has a progression arc: Studville is the starter island,
-- Duskwood Hollow is endgame. Zones not listed fall back to player-relative
-- (see GetZoneLevelRange callers).
StudData.WorldLevelBands = {
	Studville       = { min = 1, max = 15 },
	TidepoolCove    = { min = 10, max = 25 },
	Emberpeak       = { min = 20, max = 35 },
	VoltWasteland   = { min = 30, max = 45 },
	CanyonDepths    = { min = 40, max = 55 },
	FrostbiteTundra = { min = 55, max = 75 },
	DuskwoodHollow  = { min = 70, max = 95 },
}

-- zone name prefix -> world (covers every key in ZoneTypes below)
local ZONE_WORLD_PREFIXES = {
	{ "Grass", "Studville" },
	{ "Shore", "TidepoolCove" }, { "Reef", "TidepoolCove" },
	{ "Fire", "Emberpeak" }, { "Magma", "Emberpeak" },
	{ "Storm", "VoltWasteland" }, { "Static", "VoltWasteland" },
	{ "Canyon", "CanyonDepths" }, { "Gorge", "CanyonDepths" },
	{ "Mesa", "CanyonDepths" }, { "Ridge", "CanyonDepths" },
	{ "Frost", "FrostbiteTundra" }, { "Glacier", "FrostbiteTundra" },
	{ "Shadow", "DuskwoodHollow" }, { "Dusk", "DuskwoodHollow" },
}

-- Helper: level band for a zone, or nil if the zone has no band
function StudData.GetZoneLevelRange(zoneName)
	if type(zoneName) ~= "string" then return nil end
	for _, entry in ipairs(ZONE_WORLD_PREFIXES) do
		if zoneName:sub(1, #entry[1]) == entry[1] then
			return StudData.WorldLevelBands[entry[2]]
		end
	end
	return nil
end

-- Helper: which world a zone belongs to ("ShoreWreck" -> "TidepoolCove")
local function zoneWorld(zoneName)
	for _, entry in ipairs(ZONE_WORLD_PREFIXES) do
		if zoneName:sub(1, #entry[1]) == entry[1] then
			return entry[2]
		end
	end
	return nil
end

-- Helper: "TidepoolCove" -> "Tidepool Cove" for display
function StudData.GetWorldDisplayName(world)
	return (tostring(world):gsub("(%l)(%u)", "%1 %2"))
end

-- Where a species can be found, derived from the zone spawn tables and its
-- day/night modifiers — no hand-authored location data to drift.
-- Returns (sorted list of world display names, timeNote or nil) where
-- timeNote is "night only" / "more at night" / "more by day".
function StudData.GetSpeciesLocations(studId)
	local stud = studById[studId]
	if not stud then return nil end

	local dayMod = StudData.GetTimeModifier(studId, false)
	local nightMod = StudData.GetTimeModifier(studId, true)

	local worlds = {}
	local function scan(zoneTable)
		for zoneName, types in pairs(zoneTable) do
			for _, typeName in ipairs(types) do
				if typeName == stud.studType then
					local world = zoneWorld(zoneName)
					if world then
						worlds[world] = true
					end
					break
				end
			end
		end
	end
	if dayMod > 0 then scan(StudData.ZoneTypes) end
	if nightMod > 0 then scan(StudData.NightZoneTypes) end

	local list = {}
	for world in pairs(worlds) do
		table.insert(list, StudData.GetWorldDisplayName(world))
	end
	table.sort(list)

	local note = nil
	if dayMod <= 0 then
		note = "night only"
	elseif nightMod > dayMod * 1.5 then
		note = "more at night"
	elseif dayMod > nightMod * 1.5 then
		note = "more by day"
	end
	return list, note
end

-- EXP for catching a stud (not just beating it up). Scaled by the wild's
-- level and rarity so catching is a real leveling path — otherwise the
-- optimal play was to never catch anything you could defeat.
StudData.CatchExpRarityMultiplier = {
	Common = 1.0,
	Uncommon = 1.3,
	Rare = 1.8,
	Legendary = 3.0,
}

function StudData.GetCatchExpReward(wildLevel, rarity)
	local mult = StudData.CatchExpRarityMultiplier[rarity] or 1.0
	return math.max(1, math.floor(8 * math.max(1, wildLevel or 1) * mult + 0.5))
end

-- Encounter weight tables per zone (which types can appear where)
StudData.ZoneTypes = {
	-- Studville (Grass world)
	GrassNorth = { "Grass", "Electric" },
	GrassSouth = { "Water", "Ice" },
	GrassWest  = { "Rock", "Fire" },
	GrassEast  = { "Grass", "Water" },

	-- Emberpeak (Fire world)
	FireNorth  = { "Fire", "Rock" },
	FireSouth  = { "Fire", "Rock" },
	MagmaWest  = { "Fire", "Electric" },
	MagmaEast  = { "Rock", "Fire" },

	-- Tidepool Cove (Water world)
	ShoreNorth = { "Water", "Ice" },
	ShoreSouth = { "Water", "Ice" },
	ReefWest  = { "Water", "Grass" },
	ReefEast  = { "Water", "Electric" },
	-- Tidepool Cove — outer island tall-sand patches
	ReefNortheast  = { "Water", "Electric" },
	ShoreSouthwest = { "Water", "Ice" },
	ShoreWreck     = { "Water", "Rock" },
	ReefLagoon     = { "Water", "Grass" },
	ShoreRuins     = { "Grass", "Rock" },
	ShoreVolcano   = { "Fire", "Rock" },
	ShoreTurtle    = { "Water", "Grass" },

	-- Volt Wasteland (Electric world)
	StormNorth = { "Electric", "Grass" },
	StormSouth = { "Electric", "Grass" },
	StaticWest = { "Electric", "Fire" },
	StaticEast = { "Electric", "Rock" },

	-- Canyon Depths (Rock world)
	CanyonNorth = { "Rock", "Fire" },
	CanyonSouth = { "Rock", "Fire" },
	GorgeWest  = { "Rock", "Electric" },
	GorgeEast  = { "Rock", "Grass" },
	MesaRidge  = { "Rock", "Fire" },
	CanyonFloor = { "Rock", "Ice" },
	RidgePass  = { "Rock", "Electric" },

	-- Frostbite Tundra (Ice world)
	FrostNorth  = { "Ice", "Water" },
	FrostSouth  = { "Ice", "Water" },
	GlacierWest = { "Ice", "Rock" },
	GlacierEast = { "Ice", "Grass" },

	-- Duskwood Hollow (Shadow world)
	ShadowNorth = { "Shadow", "Electric" },
	ShadowSouth = { "Shadow", "Ice" },
	DuskWest   = { "Shadow", "Fire" },
	DuskEast   = { "Shadow", "Water" },
}

-- Night zone variants (replace one type with Shadow at night)
StudData.NightZoneTypes = {
	-- Studville
	GrassNorth = { "Shadow", "Electric" },
	GrassSouth = { "Shadow", "Ice" },
	GrassWest  = { "Shadow", "Fire" },
	GrassEast  = { "Shadow", "Water" },

	-- Emberpeak
	FireNorth  = { "Shadow", "Rock" },
	FireSouth  = { "Shadow", "Rock" },
	MagmaWest  = { "Shadow", "Electric" },
	MagmaEast  = { "Shadow", "Fire" },

	-- Tidepool Cove
	ShoreNorth = { "Shadow", "Ice" },
	ShoreSouth = { "Shadow", "Ice" },
	ReefWest  = { "Shadow", "Grass" },
	ReefEast  = { "Shadow", "Electric" },
	-- Tidepool Cove — outer island tall-sand patches (night)
	ReefNortheast  = { "Shadow", "Electric" },
	ShoreSouthwest = { "Shadow", "Ice" },
	ShoreWreck     = { "Shadow", "Rock" },
	ReefLagoon     = { "Shadow", "Grass" },
	ShoreRuins     = { "Shadow", "Rock" },
	ShoreVolcano   = { "Shadow", "Rock" },
	ShoreTurtle    = { "Shadow", "Water" },

	-- Volt Wasteland
	StormNorth = { "Shadow", "Grass" },
	StormSouth = { "Shadow", "Grass" },
	StaticWest = { "Shadow", "Fire" },
	StaticEast = { "Shadow", "Rock" },

	-- Canyon Depths
	CanyonNorth = { "Shadow", "Fire" },
	CanyonSouth = { "Shadow", "Fire" },
	GorgeWest  = { "Shadow", "Electric" },
	GorgeEast  = { "Shadow", "Grass" },
	MesaRidge  = { "Shadow", "Fire" },
	CanyonFloor = { "Shadow", "Ice" },
	RidgePass  = { "Shadow", "Electric" },

	-- Frostbite Tundra
	FrostNorth  = { "Shadow", "Water" },
	FrostSouth  = { "Shadow", "Water" },
	GlacierWest = { "Shadow", "Rock" },
	GlacierEast = { "Shadow", "Grass" },

	-- Duskwood Hollow (Shadow always present at night)
	ShadowNorth = { "Shadow", "Electric" },
	ShadowSouth = { "Shadow", "Ice" },
	DuskWest   = { "Shadow", "Fire" },
	DuskEast   = { "Shadow", "Water" },
}

-- Rarity encounter weights (out of 100)
StudData.RarityWeights = {
	Common    = 60,
	Uncommon  = 25,
	Rare      = 12,
	Legendary = 3,
}

-- Type effectiveness chart (attacker type -> defender type -> multiplier)
StudData.TypeEffectiveness = {
	Fire     = { Grass = 1.3, Ice = 1.2, Water = 0.7, Rock = 0.8, Shadow = 0.9 },
	Water    = { Fire = 1.3, Rock = 1.1, Grass = 0.7, Electric = 0.8, Shadow = 0.9 },
	Grass    = { Water = 1.3, Rock = 1.1, Fire = 0.7, Ice = 0.8, Shadow = 0.9 },
	Electric = { Water = 1.3, Ice = 1.1, Rock = 0.7, Grass = 0.8, Shadow = 1.2 },
	Rock     = { Electric = 1.3, Fire = 1.1, Water = 0.7, Grass = 0.8, Shadow = 0.8 },
	Ice      = { Grass = 1.3, Rock = 1.1, Fire = 0.7, Water = 0.8, Shadow = 1.2 },
	Shadow   = { Electric = 1.3, Ice = 1.2, Fire = 0.8, Rock = 1.1, Water = 0.8, Grass = 0.8 },
}

-- Helper: get type effectiveness multiplier
function StudData.GetTypeEffectiveness(attackerType, defenderType)
	if StudData.TypeEffectiveness[attackerType] then
		return StudData.TypeEffectiveness[attackerType][defenderType] or 1.0
	end
	return 1.0
end

-- ─── DAY/NIGHT ENCOUNTER MODIFIERS ─────────────────────────────────────
-- Built programmatically over the whole dex (105 hand-written rows would
-- drift the moment a species is added):
--   * Shadow: strictly night-exclusive (day weight 0), like the old dex
--   * Fire/Grass Rares+Legendaries: day hunters
--   * Ice/Electric Rares+Legendaries: night hunters
-- Commons/Uncommons stay neutral so no zone ever feels empty.
StudData.TimeModifiers = {}
do
	local higherRarity = { Rare = true, Legendary = true }
	for _, stud in ipairs(StudData.Studs) do
		if stud.studType == "Shadow" then
			StudData.TimeModifiers[stud.id] = { night = 2.5, day = 0.0 }
		elseif higherRarity[stud.rarity] then
			if stud.studType == "Fire" or stud.studType == "Grass" then
				StudData.TimeModifiers[stud.id] = { day = 1.5, night = 0.5 }
			elseif stud.studType == "Ice" or stud.studType == "Electric" then
				StudData.TimeModifiers[stud.id] = { night = 1.8, day = 0.5 }
			end
		end
	end
end

-- Helper: get time modifier for a stud
function StudData.GetTimeModifier(studId, isNight)
	local mod = StudData.TimeModifiers[studId]
	if not mod then return 1.0 end
	if isNight then
		return mod.night or 1.0
	else
		return mod.day or 1.0
	end
end

-- Evolution chains: the SHOWCASE line per type (Common → Uncommon → Rare →
-- Legendary), rendered by EvolutionUI/LabUI as the type's headline chain.
-- The full evolution graph (all 105 species, including branches) lives in
-- EvolutionPaths below.
StudData.EvolutionChains = {
	Fire     = { "gary", "kevin", "bruce", "bob" },
	Water    = { "susan", "sandra", "cheryl", "ted" },
	Grass    = { "terry", "herb", "norm", "greg" },
	Electric = { "chad", "vince", "rick", "chuck" },
	Rock     = { "steve", "carl", "walt", "al" },
	Ice      = { "brad", "lance", "kirk", "gus" },
	Shadow   = { "wade", "cliff", "dean", "hal" },
}

-- Evolution point costs to evolve from one tier to the next
StudData.EvolutionCosts = {
	Common    = 5,   -- Common → Uncommon
	Uncommon  = 8,   -- Uncommon → Rare
	Rare      = 12,  -- Rare → Legendary
}

-- ─── EVOLUTION PATHS ────────────────────────────────────────────────────
-- Explicit path(s) for EVERY stud. First entry = default path.
-- Per type: 6 Commons feed 4 Uncommons (one Common branches), Uncommons
-- feed 3 Rares (one branches cross-type for build variety), Rares feed the
-- 2 Legendaries (the third Rare gets a choice of either).
-- Legendaries have no further evolution (empty table).
StudData.EvolutionPaths = {
	-- Fire
	gary = { "kevin" }, doug = { "kevin" }, phil = { "linda" },
	todd = { "frank" }, carol = { "marge" }, brenda = { "linda", "marge" },
	kevin = { "bruce" }, linda = { "diane", "neil" }, -- overheat → lightning branch
	frank = { "craig" }, marge = { "diane" },
	bruce = { "bob" }, diane = { "karen" }, craig = { "bob", "karen" },
	bob = {}, karen = {},
	-- Water
	susan = { "sandra" }, dave = { "sandra" }, wendy = { "gene" },
	brian = { "rhonda" }, paula = { "marty" }, keith = { "gene", "marty" },
	sandra = { "cheryl" }, gene = { "dennis", "kirk" }, -- deep water → ice branch
	rhonda = { "gail" }, marty = { "dennis" },
	cheryl = { "ted" }, dennis = { "barb" }, gail = { "ted", "barb" },
	ted = {}, barb = {},
	-- Grass
	terry = { "herb" }, joyce = { "herb" }, alan = { "donna" },
	peggy = { "roger" }, stan = { "faye" }, rita = { "donna", "faye" },
	herb = { "norm" }, donna = { "sheila", "marcia" }, -- roots → stone branch
	roger = { "wayne" }, faye = { "sheila" },
	norm = { "greg" }, sheila = { "ethel" }, wayne = { "greg", "ethel" },
	greg = {}, ethel = {},
	-- Electric
	chad = { "vince" }, tina = { "vince" }, randy = { "tammy" },
	deb = { "earl" }, larry = { "jan" }, kim = { "tammy", "earl" },
	vince = { "rick" }, tammy = { "cindy", "craig" }, -- overload → fire branch
	earl = { "neil" }, jan = { "cindy" },
	rick = { "chuck" }, cindy = { "pam" }, neil = { "chuck", "pam" },
	chuck = {}, pam = {},
	-- Rock
	steve = { "carl" }, nancy = { "carl" }, bill = { "betty" },
	ruth = { "ron" }, hank = { "gladys" }, lois = { "betty", "ron" },
	carl = { "walt" }, betty = { "marcia", "bonnie" }, -- mountain → ice branch
	ron = { "bert" }, gladys = { "marcia" },
	walt = { "al" }, marcia = { "doris" }, bert = { "al", "doris" },
	al = {}, doris = {},
	-- Ice
	brad = { "lance" }, judy = { "lance" }, glen = { "vera" },
	elaine = { "dale" }, curt = { "nadine" }, sue = { "vera", "dale" },
	lance = { "kirk" }, vera = { "bonnie", "bert" }, -- crystal → stone branch
	dale = { "roy" }, nadine = { "bonnie" },
	kirk = { "gus" }, bonnie = { "edna" }, roy = { "gus", "edna" },
	gus = {}, edna = {},
	-- Shadow (pure lines)
	wade = { "cliff" }, mona = { "cliff" }, lyle = { "sonia" },
	tricia = { "rex" }, vern = { "opal" }, nina = { "sonia", "rex" },
	cliff = { "dean" }, sonia = { "vicky" },
	rex = { "boyd" }, opal = { "vicky" },
	dean = { "hal" }, vicky = { "myrna" }, boyd = { "hal", "myrna" },
	hal = {}, myrna = {},
}

-- Helper: all evolution options for a stud (list of stud data tables)
function StudData.GetEvolutionOptions(studId)
	local options = {}
	for _, id in ipairs(StudData.EvolutionPaths[studId] or {}) do
		local s = StudData.GetStudById(id)
		if s then table.insert(options, s) end
	end
	return options
end

-- Helper: get the next evolution for a stud.
-- targetId (optional) selects a branch; must be a valid path. Defaults to first path.
function StudData.GetEvolution(studId, targetId)
	local paths = StudData.EvolutionPaths[studId]
	if not paths or #paths == 0 then return nil end
	if targetId then
		for _, id in ipairs(paths) do
			if id == targetId then
				return StudData.GetStudById(id)
			end
		end
		return nil -- invalid branch requested
	end
	return StudData.GetStudById(paths[1])
end

-- Helper: get the evolution cost for a stud (cost to evolve FROM this stud's tier)
function StudData.GetEvolutionCost(studId)
	local stud = StudData.GetStudById(studId)
	if not stud then return nil end
	return StudData.EvolutionCosts[stud.rarity]
end

-- Helper: get the position of a stud in its type's showcase chain (1-based;
-- 0 for studs outside the showcase line — use EvolutionPaths for those)
function StudData.GetChainPosition(studId)
	local stud = StudData.GetStudById(studId)
	if not stud then return 0 end
	local chain = StudData.EvolutionChains[stud.studType]
	if not chain then return 0 end
	for i, id in ipairs(chain) do
		if id == studId then return i end
	end
	return 0
end

-- ─── NATURES (per-copy stat variance) ──────────────────────────────────
-- Every caught copy rolls a nature, so two Steves are never quite the same.
-- atk scales damage dealt; def scales damage taken (higher = tankier);
-- spd breaks turn-order ties in PvP.
StudData.Natures = {
	{ id = "hardy",    name = "Hardy",    atk = 1.0,  def = 1.0,  spd = 1.0 },
	{ id = "fierce",   name = "Fierce",   atk = 1.1,  def = 0.95, spd = 1.0 },
	{ id = "sturdy",   name = "Sturdy",   atk = 0.95, def = 1.1,  spd = 1.0 },
	{ id = "swift",    name = "Swift",    atk = 1.0,  def = 0.95, spd = 1.1 },
	{ id = "reckless", name = "Reckless", atk = 1.15, def = 0.85, spd = 1.05 },
	{ id = "calm",     name = "Calm",     atk = 0.9,  def = 1.15, spd = 0.95 },
}

function StudData.RollNature()
	return StudData.Natures[math.random(#StudData.Natures)].id
end

function StudData.GetNature(natureId)
	for _, n in ipairs(StudData.Natures) do
		if n.id == natureId then
			return n
		end
	end
	return StudData.Natures[1] -- Hardy (neutral) for old entries with no nature
end

-- Damage multiplier for an attacker/defender nature pair
function StudData.GetNatureDamageMultiplier(attackerNatureId, defenderNatureId)
	local atk = StudData.GetNature(attackerNatureId).atk
	local def = StudData.GetNature(defenderNatureId).def
	return atk / def
end

-- ─── WEATHER SPAWN BIAS ────────────────────────────────────────────────
-- Types favored per weather; when a favored type exists in the zone's
-- spawn table, encounters lean toward it. Fog additionally counts as
-- night for spawn tables (Shadow studs prowl the mist even at noon).
StudData.WeatherFavoredTypes = {
	Clear  = { Fire = true, Grass = true },
	Cloudy = {},
	Rain   = { Water = true, Electric = true },
	Fog    = { Shadow = true, Ice = true },
}

-- ─── STARTERS ──────────────────────────────────────────────────────────
-- Offered once on a brand-new save (SaveManager ChooseStarter): the classic
-- Fire/Water/Grass trio of chain-head Commons.
StudData.Starters = { "gary", "susan", "terry" }

-- ─── TYPE DEX COMPLETION TITLES ────────────────────────────────────────
-- Own every species of a type (all 15) → one-time coin reward + a title
-- named for the type's iconic chain-head stud (SaveManager awards these).
StudData.TypeDexTitles = {
	Fire     = "Friend of Gary",
	Water    = "Friend of Susan",
	Grass    = "Friend of Terry",
	Electric = "Friend of Chad",
	Rock     = "Friend of Steve",
	Ice      = "Friend of Brad",
	Shadow   = "Friend of Wade",
}
StudData.TYPE_DEX_REWARD = 1000

-- ─── CATCH BALLS (consumable coin sink) ────────────────────────────────
-- Bought in the shop, stored as counts in save data (data.items), and
-- auto-consumed (best first) when a catch attempt starts. targetMult
-- shrinks the catch bar target for that attempt — the server scales its
-- anti-cheat minimum-tap floor by the same factor.
StudData.CatchBalls = {
	{ id = "super_ball", name = "Super Ball", desc = "Next catch is 25% easier (one use)", price = 40, targetMult = 0.75 },
	{ id = "mega_ball", name = "Mega Ball", desc = "Next catch is 45% easier (one use)", price = 120, targetMult = 0.55 },
}

function StudData.GetCatchBall(ballId)
	for _, ball in ipairs(StudData.CatchBalls) do
		if ball.id == ballId then
			return ball
		end
	end
	return nil
end

-- Shiny stud system
-- 1 in 64 chance any encounter is a shiny variant
StudData.SHINY_CHANCE = 1 / 64
StudData.ShinyColor = Color3.fromRGB(255, 215, 0)

-- Helper: determine if an encounter is shiny
function StudData.RollShiny()
	return math.random() < StudData.SHINY_CHANCE
end

-- Helper: get shiny-modified color (golden tint)
function StudData.GetShinyColor(baseColor)
	local shinyR = baseColor.R * 0.4 + 1.0 * 0.6
	local shinyG = baseColor.G * 0.4 + 0.84 * 0.6
	local shinyB = baseColor.B * 0.4 + 0.0 * 0.6
	return Color3.new(
		math.clamp(shinyR, 0, 1),
		math.clamp(shinyG, 0, 1),
		math.clamp(shinyB, 0, 1)
	)
end

-- Helper: get total number of unique stud species
function StudData.GetTotalSpecies()
	return #StudData.Studs
end

-- Pick a random Stud for an encounter in a given zone.
-- weather (optional): current weather name — biases the type roll toward
-- StudData.WeatherFavoredTypes and makes Fog count as night.
function StudData.PickRandomStud(zoneName, isNight, luckyCharm, weather)
	-- Fog counts as night for spawn tables
	local effectiveNight = isNight or weather == "Fog"

	-- Use night zone types if it's nighttime
	local zoneTypes
	if effectiveNight and StudData.NightZoneTypes[zoneName] then
		zoneTypes = StudData.NightZoneTypes[zoneName]
	else
		zoneTypes = StudData.ZoneTypes[zoneName]
	end
	if not zoneTypes then
		zoneTypes = {}
		for typeName, _ in pairs(StudData.Types) do
			table.insert(zoneTypes, typeName)
		end
	end

	-- Pick a type from the zone, leaning toward weather-favored types
	local chosenType = zoneTypes[math.random(#zoneTypes)]
	local favored = weather and StudData.WeatherFavoredTypes[weather]
	if favored then
		local favoredInZone = {}
		for _, typeName in ipairs(zoneTypes) do
			if favored[typeName] then
				table.insert(favoredInZone, typeName)
			end
		end
		-- 60% of the time, spawn one of the weather-favored types instead
		if #favoredInZone > 0 and math.random() < 0.6 then
			chosenType = favoredInZone[math.random(#favoredInZone)]
		end
	end

	-- Pick rarity based on weights (LuckyCharm shifts weights toward rare)
	local weights = {
		Common    = StudData.RarityWeights.Common,
		Uncommon  = StudData.RarityWeights.Uncommon,
		Rare      = StudData.RarityWeights.Rare,
		Legendary = StudData.RarityWeights.Legendary,
	}

	if luckyCharm then
		weights.Common = math.floor(weights.Common * 0.6)
		weights.Rare = math.floor(weights.Rare * 2.5)
		weights.Legendary = math.floor(weights.Legendary * 3)
	end

	local totalWeight = 0
	for _, w in pairs(weights) do totalWeight = totalWeight + w end

	local roll = math.random(totalWeight)
	local rarity = "Common"
	local cumulative = 0
	for rName, weight in pairs(weights) do
		cumulative = cumulative + weight
		if roll <= cumulative then
			rarity = rName
			break
		end
	end

	-- Pick a Stud of that type and rarity (via the type/rarity index),
	-- weighted by time of day
	local typeRarityPool = studsByTypeRarity[chosenType] and studsByTypeRarity[chosenType][rarity] or {}
	local candidates = {}
	local candidateWeights = {}
	for _, stud in ipairs(typeRarityPool) do
		local timeMod = StudData.GetTimeModifier(stud.id, effectiveNight)
		if timeMod > 0 then
			table.insert(candidates, stud)
			table.insert(candidateWeights, timeMod)
		end
	end

	if #candidates > 0 then
		local totalW = 0
		for _, w in ipairs(candidateWeights) do totalW = totalW + w end
		local pick = math.random() * totalW
		local cumulativeW = 0
		for i, stud in ipairs(candidates) do
			cumulativeW = cumulativeW + candidateWeights[i]
			if pick <= cumulativeW then
				return stud
			end
		end
		return candidates[#candidates]
	end

	-- Fallback: any common of that type
	local commonPool = studsByTypeRarity[chosenType] and studsByTypeRarity[chosenType].Common
	if commonPool and #commonPool > 0 then
		return commonPool[math.random(#commonPool)]
	end

	-- Ultimate fallback
	return StudData.Studs[1]
end

return StudData
