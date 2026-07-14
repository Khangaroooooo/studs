--!strict
-- Combat: the single shared combat/EXP core used by EncounterSystem (wild
-- encounters), BattleSystem (arena), and PvPSystem (duels).
--
-- HISTORY: each of those three systems used to carry its own copy-pasted
-- calculateDamage/awardExp, and every balance change had to be patched three
-- times (and drifted). All tuning now lives here and in StudData.
--
-- BALANCE INVARIANT: species ATK/DEF stats replace the old flat rarity
-- multiplier (Common 1.0 → Legendary 2.0). Stats scale with rarity anyway
-- (Common ~8-14, Legendary ~28-40), so (10+atk)/(10+def) lands in the same
-- range for cross-rarity matchups — but now species WITHIN a rarity differ
-- (a Spark hits harder than a Pebble; a Boulder tanks harder than a Blaze),
-- which is what makes species choice and branching evolutions matter.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))

local Combat = {}

-- Shared shapes. Species/move/status tables come from StudData (typed `any`
-- here because StudData is required via a non-literal path); these aliases
-- document the fields Combat actually reads.
type Stats = { attack: number?, defense: number?, speed: number? }
type Stud = { rarity: string?, studType: string?, stats: Stats? }
type DamageParams = {
	attacker: Stud,
	defender: Stud,
	attackerLevel: number?,
	defenderLevel: number?,
	movePower: number?,
	accuracy: number?,
	atkNature: string?,
	defNature: string?,
	isDefending: boolean?,
	-- Passive modifiers (ability + held item) from Combat.GatherEffects.
	-- Each is an array of effect tables; nil/empty = no passives (wild studs).
	atkEffects: { any }?,
	defEffects: { any }?,
	-- Attacker's current HP fraction (0-1), for berserk-style abilities. nil
	-- disables HP-conditional effects rather than treating the stud as full.
	attackerHpFrac: number?,
}
type Entry = { level: number?, exp: number? }
type Move = { name: string?, power: number?, accuracy: number?, status: string?, statusChance: number? }
type Status = { kind: string, turnsLeft: number }

Combat.CONFIG = {
	BASE_DAMAGE = 15,
	CRITICAL_CHANCE = 0.1,
	CRITICAL_MULTIPLIER = 1.5,
	DEFEND_REDUCTION = 0.5,
	-- Faint penalty tuning (see CalculateFaintPenalty)
	FAINT_LOSS_BASE = 0.10,
	FAINT_LOSS_MIN = 0.02,
	FAINT_LOSS_MAX = 0.20,
	FAINT_LOSS_CAP = 250,
	-- Status effect tuning (see RollMoveStatus / TickStatus)
	BURN_FRACTION = 0.06,
	BURN_TURNS = 3,
	PARALYZE_TURNS = 3,
	PARALYZE_SKIP_CHANCE = 0.25,
	-- Below this HP fraction, berserk-style ability effects switch on
	BERSERK_THRESHOLD = 1 / 3,
}

-- Stat helpers tolerate species tables without stats (old data, mods)
local function atkStat(stud: Stud): number
	return stud and stud.stats and stud.stats.attack or 10
end

local function defStat(stud: Stud): number
	return stud and stud.stats and stud.stats.defense or 10
end

-- Effective speed for turn order / first-strike / flee odds
function Combat.GetSpeed(stud: Stud, natureId: string?): number
	local spd = stud and stud.stats and stud.stats.speed or 10
	return spd * StudData.GetNature(natureId).spd
end

-- Collect the passive effect tables active for a combatant: its species
-- ability (Rare/Legendary only) plus its equipped held item, if any. Returns
-- an array (possibly empty) of effect tables that CalculateDamage /
-- RollMoveStatus read. `stud` is the species table; `heldItemId` comes from
-- data.heldItems[speciesId]. Wild studs pass no held item and have no ability
-- unless they're Rare/Legendary — so wild rares fight a little smarter too.
function Combat.GatherEffects(stud: any, heldItemId: string?): { any }
	local effects = {}
	local ability = stud and StudData.GetAbility(stud)
	if ability then table.insert(effects, ability) end
	local item = heldItemId and StudData.GetHeldItem(heldItemId)
	if item then table.insert(effects, item) end
	return effects
end

-- One damage roll. params:
--   attacker, defender  (species tables from StudData — need .rarity/.studType/.stats)
--   attackerLevel, defenderLevel
--   movePower           (multiplier, default 1.0)
--   accuracy            (hit chance 0-1, nil/1 = always hits)
--   atkNature, defNature (nature ids, nil = neutral)
--   isDefending         (defender braced: halves damage)
-- Returns dmg, isCritical, effectiveness, missed.
function Combat.CalculateDamage(params: DamageParams): (number, boolean, number, boolean)
	-- Accuracy roll first: heavy moves trade reliability for power.
	-- Wild/basic attacks pass no accuracy and never miss.
	if params.accuracy and params.accuracy < 1 and math.random() >= params.accuracy then
		return 0, false, 1.0, true
	end
	local dmg = Combat.CONFIG.BASE_DAMAGE
	-- Species stats: attack vs defense ratio (see BALANCE INVARIANT above)
	dmg = dmg * (10 + atkStat(params.attacker)) / (10 + defStat(params.defender))
	dmg = dmg * StudData.GetLevelDamageMultiplier(params.attackerLevel or 1)
	dmg = dmg / StudData.GetLevelDefenseMultiplier(params.defenderLevel or 1)
	dmg = dmg * StudData.GetNatureDamageMultiplier(params.atkNature, params.defNature)
	dmg = dmg * (params.movePower or 1.0)
	local effectiveness = StudData.GetTypeEffectiveness(params.attacker.studType, params.defender.studType)
	dmg = dmg * effectiveness

	-- Passive abilities / held items (StudData effect schema). Offensive
	-- effects come from the attacker, defensive from the defender; critBonus
	-- feeds the crit roll below instead of multiplying damage directly.
	local critChance = Combat.CONFIG.CRITICAL_CHANCE
	if params.atkEffects then
		local berserk = params.attackerHpFrac ~= nil
			and params.attackerHpFrac < Combat.CONFIG.BERSERK_THRESHOLD
		for _, e in ipairs(params.atkEffects) do
			if e.outMult and (not e.outType or params.attacker.studType == e.outType) then
				dmg = dmg * e.outMult
			end
			if e.vsMult and params.defender.studType == e.vsType then
				dmg = dmg * e.vsMult
			end
			if e.berserkMult and berserk then
				dmg = dmg * e.berserkMult
			end
			if e.critBonus then
				critChance = critChance + e.critBonus
			end
		end
	end
	if params.defEffects then
		for _, e in ipairs(params.defEffects) do
			if e.inMult then
				dmg = dmg * e.inMult
			end
			if e.inVsMult and params.attacker.studType == e.inVsType then
				dmg = dmg * e.inVsMult
			end
		end
	end

	dmg = dmg * (0.85 + math.random() * 0.3)
	local isCritical = math.random() < critChance
	if isCritical then
		dmg = dmg * Combat.CONFIG.CRITICAL_MULTIPLIER
	end
	if params.isDefending then
		dmg = dmg * Combat.CONFIG.DEFEND_REDUCTION
	end
	return math.floor(dmg + 0.5), isCritical, effectiveness, false
end

-- Add a raw EXP amount to a live caughtStuds entry and process level-ups.
-- Returns levelsGained, newLevel.
function Combat.GrantExp(entry: Entry, amount: number): (number, number)
	local level = entry.level or 1
	local exp = (entry.exp or 0) + amount
	local levelsGained = 0
	while level < StudData.MAX_LEVEL do
		local needed = StudData.GetExpToLevel(level)
		if exp < needed then break end
		exp -= needed
		level += 1
		levelsGained += 1
	end
	entry.level = level
	entry.exp = exp
	return levelsGained, level
end

-- Battle-win EXP relative to the beaten opponent's level.
-- Returns expGained, levelsGained, newLevel.
function Combat.AwardExp(entry: Entry, opponentLevel: number?): (number, number, number)
	local expGained = StudData.GetExpReward(entry.level or 1, opponentLevel or 1)
	local levelsGained, newLevel = Combat.GrantExp(entry, expGained)
	return expGained, levelsGained, newLevel
end

-- Server-side move resolution WITH level gating. moveIndex from the client is
-- untrusted; a locked or invalid index silently falls back to the basic move
-- so exploiters can't use the 2.0x move at Lv1.
-- `stud` is the species table (per-species kits) — a bare type string still
-- works and resolves the type's default kit.
-- Returns movePower, moveName, accuracy (nil = always hits), move table.
function Combat.ResolveMove(stud: any, moveIndex: number?, level: number?): (number, string, number?, any)
	local moves = StudData.GetMoves(stud)
	local move = moveIndex and moves and moves[moveIndex] or nil
	if move and StudData.IsMoveUnlocked(move, level) then
		return move.power, move.name, move.accuracy, move
	end
	local basic = moves and moves[1]
	return basic and basic.power or 1.0, basic and basic.name or "Attack", basic and basic.accuracy or nil, basic
end

-- ─── FAINT PENALTY ─────────────────────────────────────────────────────
-- Coins lost when a stud faints. Scales INVERSELY with the opponent's level
-- relative to the loser's: losing to a stronger stud is expected (small
-- loss, floor 2%), getting knocked out by a weaker one stings (up to 20%).
-- 10% at even levels; hard cap so hoarders aren't wiped by one bad fight.
function Combat.CalculateFaintPenalty(coins: number?, loserLevel: number?, opponentLevel: number?): number
	coins = math.max(0, math.floor(coins or 0))
	if coins == 0 then return 0 end
	local ratio = math.max(1, opponentLevel or 1) / math.max(1, loserLevel or 1)
	local frac = math.clamp(
		Combat.CONFIG.FAINT_LOSS_BASE / ratio,
		Combat.CONFIG.FAINT_LOSS_MIN,
		Combat.CONFIG.FAINT_LOSS_MAX
	)
	return math.min(math.floor(coins * frac), Combat.CONFIG.FAINT_LOSS_CAP, coins)
end

-- ─── STATUS EFFECTS ────────────────────────────────────────────────────
-- burn: chip damage at the start of each of the victim's actions (3 turns)
-- freeze: victim's next action is skipped (1 turn)
-- paralyze: 25% chance to skip each action (3 turns)
-- Mid-tier Fire/Ice/Electric moves proc these (see StudData.TypeMovePools).
-- One status at a time: a new proc never overwrites an existing one.

-- Roll whether a landed move inflicts its status. Returns a fresh status
-- table ({ kind, turnsLeft }) or nil. atkEffects boost the proc chance
-- (statusOutMult from Scorcher/Overcharge/Cinder Charm…); defEffects can grant
-- immunity (statusImmune from Stalwart / Focus Charm). Both are optional so
-- wild/basic callers keep the old two-arg behaviour.
function Combat.RollMoveStatus(move: Move?, existingStatus: Status?, atkEffects: { any }?, defEffects: { any }?): Status?
	if existingStatus then return nil end
	if not (move and move.status) then return nil end
	if defEffects then
		for _, e in ipairs(defEffects) do
			if e.statusImmune then return nil end
		end
	end
	local chance = move.statusChance or 0
	if atkEffects then
		for _, e in ipairs(atkEffects) do
			if e.statusOutMult then chance = chance * e.statusOutMult end
		end
	end
	if math.random() < chance then
		local turns = move.status == "freeze" and 1
			or move.status == "burn" and Combat.CONFIG.BURN_TURNS
			or Combat.CONFIG.PARALYZE_TURNS
		return { kind = move.status, turnsLeft = turns }
	end
	return nil
end

-- Tick a status at the start of the victim's action.
-- Returns chipDamage, skipAction, cured, kind. Mutates status.turnsLeft;
-- the caller clears the status table when cured is true.
function Combat.TickStatus(status: Status?, maxHP: number?): (number, boolean, boolean, string?)
	if not status then return 0, false, false, nil end
	local chip, skip = 0, false
	if status.kind == "burn" then
		chip = math.max(1, math.floor((maxHP or 100) * Combat.CONFIG.BURN_FRACTION))
	elseif status.kind == "freeze" then
		skip = true
	elseif status.kind == "paralyze" then
		skip = math.random() < Combat.CONFIG.PARALYZE_SKIP_CHANCE
	end
	status.turnsLeft -= 1
	return chip, skip, status.turnsLeft <= 0, status.kind
end

-- Display strings shared by the battle systems' logs
Combat.STATUS_INFLICT_TEXT = {
	burn = "was burned!",
	freeze = "was frozen solid!",
	paralyze = "was paralyzed!",
}
Combat.STATUS_SKIP_TEXT = {
	freeze = "is frozen and can't move!",
	paralyze = "is paralyzed and can't move!",
}

return Combat
