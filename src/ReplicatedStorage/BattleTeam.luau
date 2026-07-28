-- BattleTeam: the single shared battle-team model used by EncounterSystem
-- (wild encounters) and BattleSystem (arena/trainer battles), plus the one
-- MAX_TEAM cap read by SaveManager and the client UIs.
--
-- HISTORY: mirrors Combat.luau — both battle drivers initially carried
-- copy-pasted twins of these helpers (buildTeam/setActive/teamSnapshot/
-- hasReserve/getOwnedEntry), so every team-rule change had to land twice
-- and could drift. The team model now lives here; each driver keeps only
-- its own client transport (BattleState RemoteEvent push vs EncounterAction
-- RemoteFunction return).
--
-- A "state" is the driver's own battle/encounter table. This module owns its
-- team fields (team, activeIndex) and the active-stud mirror fields
-- (playerStud/playerEntry/playerLevel/playerMaxHP/playerHP/playerEffects);
-- everything else on the state belongs to the driver.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local Combat = require(ReplicatedStorage:WaitForChild("Combat"))

local BattleTeam = {}

-- The one team-size cap: roster length (SaveManager.normalizeTeam), studs
-- pulled into a battle (Build below), and switch-panel rows (BattleUI,
-- InventoryUI). Change it here and every consumer agrees.
BattleTeam.MAX_TEAM = 6

-- Find the caught entry for a species (highest level owned) and lazily
-- initialize level/exp fields on it.
function BattleTeam.GetOwnedEntry(playerInfo, studId)
	local best = nil
	for _, caught in ipairs(playerInfo.data.caughtStuds) do
		if caught.id == studId then
			caught.level = caught.level or 1
			caught.exp = caught.exp or 0
			if not best or caught.level > best.level then
				best = caught
			end
		end
	end
	return best
end

-- Build one battle-ready member for a species id (nil if unknown/not owned)
local function buildMember(playerInfo, id)
	local stud = StudData.GetStudById(id)
	local entry = BattleTeam.GetOwnedEntry(playerInfo, id)
	if not (stud and entry) then return nil end
	local level = entry.level or 1
	local maxHP = StudData.GetMaxHP(stud.rarity, level)
	local held = playerInfo.data.heldItems and playerInfo.data.heldItems[id] or nil
	return {
		id = id, stud = stud, entry = entry, level = level,
		maxHP = maxHP, hp = maxHP, heldItem = held,
		effects = Combat.GatherEffects(stud, held), fainted = false,
	}
end

-- Build the battle team from the saved roster (lead first), falling back to
-- the single equipped stud, then the first owned species, then fallbackId
-- (the lead the client asked for — covers saves with a stale/empty roster).
function BattleTeam.Build(playerInfo, fallbackId)
	local ids = {}
	local team = playerInfo.data.equippedTeam
	if type(team) == "table" and #team > 0 then
		for _, id in ipairs(team) do table.insert(ids, id) end
	elseif playerInfo.data.equippedStudId then
		ids = { playerInfo.data.equippedStudId }
	else
		local first = playerInfo.data.caughtStuds[1]
		if first then ids = { first.id } end
	end

	local members = {}
	local seen = {}
	for _, id in ipairs(ids) do
		if not seen[id] then
			seen[id] = true
			local member = buildMember(playerInfo, id)
			if member then
				table.insert(members, member)
				if #members >= BattleTeam.MAX_TEAM then break end
			end
		end
	end

	if #members == 0 and fallbackId then
		local member = buildMember(playerInfo, fallbackId)
		if member then members = { member } end
	end
	return members
end

-- Point the state's active-stud fields at team member idx
function BattleTeam.SetActive(state, idx)
	local m = state.team[idx]
	state.activeIndex = idx
	state.playerStud = m.stud
	state.playerEntry = m.entry
	state.playerLevel = m.level
	state.playerMaxHP = m.maxHP
	state.playerHP = m.hp
	state.playerEffects = m.effects
end

-- Payload describing the active stud (the client's player card / switch result)
function BattleTeam.ActivePayload(state)
	local m = state.team and state.team[state.activeIndex]
	if not m then return nil end
	return {
		id = m.id, name = m.stud.name, studType = m.stud.studType,
		rarity = m.stud.rarity, description = m.stud.description,
		level = m.level, exp = m.entry and m.entry.exp or 0, heldItem = m.heldItem,
	}
end

-- Client-facing snapshot of the whole team (active HP is the live state.playerHP)
function BattleTeam.Snapshot(state)
	local out = {}
	if state.team then
		for i, m in ipairs(state.team) do
			local isActive = (i == state.activeIndex)
			local hp = isActive and state.playerHP or m.hp
			table.insert(out, {
				index = i, id = m.id, name = m.stud.name, studType = m.stud.studType,
				rarity = m.stud.rarity, level = m.level,
				hp = math.max(0, math.floor(hp)), maxHP = m.maxHP,
				fainted = m.fainted or hp <= 0, active = isActive,
			})
		end
	end
	return out
end

-- Any live reserve to fall back on when the active faints?
function BattleTeam.HasReserve(state)
	if not state.team then return false end
	for i, m in ipairs(state.team) do
		if i ~= state.activeIndex and not m.fainted and m.hp > 0 then
			return true
		end
	end
	return false
end

-- Mark the current active member down (both drivers' faint flows start here)
function BattleTeam.MarkActiveFainted(state)
	local m = state.team and state.team[state.activeIndex]
	if m then
		m.fainted = true
		m.hp = 0
	end
end

return BattleTeam
