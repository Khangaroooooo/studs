-- BattleSystem: Turn-based PvE stud battles with type effectiveness
-- Players battle wild studs using their caught collection

local Players = game:GetService('Players')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local Lighting = game:GetService('Lighting')

local StudEvents = ReplicatedStorage:WaitForChild('StudEvents')
local StudData = require(ReplicatedStorage:WaitForChild('StudData'))
local Combat = require(ReplicatedStorage:WaitForChild('Combat'))
local BattleTeam = require(ReplicatedStorage:WaitForChild('BattleTeam'))
local ServerRegistry = require(ReplicatedStorage:WaitForChild('ServerRegistry'))

-- Active battles: playerId -> battleState
local activeBattles = {}

-- Battle configuration (damage tuning lives in ReplicatedStorage/Combat)
local CONFIG = {
    CATCH_BONUS = 0.15,
    WIN_COINS_MIN = 15,
    WIN_COINS_MAX = 50,
    WIN_EVO_POINTS = 2,
    MAX_TURNS = 20,
    AI_DELAY = 1.2,
}


-- Helper: one wild/trainer attack against the player's stud. Plain wilds
-- jab with the basic 1.0x move; TRAINER studs fight with their real kit —
-- a random unlocked move each turn, with its full power AND accuracy (so
-- they hit harder but can whiff their heavies, same rules as the player).
-- Returns dmg, isCrit, eff, missed, moveName (moveName nil for plain wilds).
local function wildAttack(battle)
    local movePower, moveName, accuracy = 1.0, nil, nil
    if battle.trainer then
        movePower, moveName, accuracy = Combat.ResolveMove(battle.wildStud, math.random(1, 4), battle.wildLevel)
    end
    local dmg, isCrit, eff, missed = Combat.CalculateDamage({
        attacker = battle.wildStud,
        defender = battle.playerStud,
        movePower = movePower,
        accuracy = accuracy,
        attackerLevel = battle.wildLevel,
        defenderLevel = battle.playerLevel,
        defNature = battle.playerEntry and battle.playerEntry.nature or nil,
        isDefending = battle.playerDefending,
        atkEffects = battle.wildEffects,
        defEffects = battle.playerEffects,
        attackerHpFrac = battle.wildHP / battle.wildMaxHP,
    })
    return dmg, isCrit, eff, missed, moveName
end

-- Log line for a wild/trainer attack (handles kit move names and misses)
local function wildAttackLog(battle, dmg, isCrit, eff, missed, moveName)
    local verb = moveName and (' used ' .. moveName) or ' attacks'
    if missed then
        return battle.wildStud.name .. verb .. '... it missed!'
    end
    local effText = ''
    if eff > 1.1 then effText = ' Super effective!'
    elseif eff < 0.9 then effText = ' Not very effective...'
    end
    local critText = isCrit and ' Critical!' or ''
    return battle.wildStud.name .. verb .. '! -' .. dmg .. ' HP' .. effText .. critText
end

-- Helper: get max HP based on rarity + level (delegates to StudData)
local function getMaxHP(stud, level)
    return StudData.GetMaxHP(stud.rarity, level or 1)
end

-- ─── BATTLE TEAM ───────────────────────────────────────────────────────
-- Arena/trainer battles are fought by a team of up to BattleTeam.MAX_TEAM
-- studs (data.equippedTeam, lead first). The active member fights; the player
-- can Switch to a reserve (costs the turn) or is forced to send one in on a
-- faint. The team model (build/snapshot/switch/reserve) is shared with
-- EncounterSystem via ReplicatedStorage/BattleTeam; only the transport here
-- (BattleState pushes) is battle-specific.

-- Resolve a player faint: mark the active stud down and, if a reserve is
-- alive, push a force_switch state and return true (battle continues).
-- Returns false when the whole team is down (caller runs the loss flow).
local function handlePlayerFaint(player, battle, log)
    BattleTeam.MarkActiveFainted(battle)
    if BattleTeam.HasReserve(battle) then
        battle.pendingSwitch = true
        table.insert(log, battle.playerStud.name .. ' fainted! Choose your next Stud.')
        StudEvents.BattleState:FireClient(player, {
            action = 'force_switch',
            playerHP = battle.playerHP,
            playerMaxHP = battle.playerMaxHP,
            wildHP = battle.wildHP,
            wildMaxHP = battle.wildMaxHP,
            turn = battle.turn,
            team = BattleTeam.Snapshot(battle),
            log = log,
        })
        return true
    end
    return false
end

-- Helper: losing costs coins — fewer when the wild outleveled you, more
-- when it was weaker (Combat.CalculateFaintPenalty). Appends a log line.
local function applyLossPenalty(player, battle, log)
    local apd = ServerRegistry.Get('ActivePlayers')
    local playerInfo = apd and apd[player.UserId]
    if not playerInfo or not playerInfo.data then return end
    local loss = Combat.CalculateFaintPenalty(playerInfo.data.coins, battle.playerLevel, battle.wildLevel)
    if loss > 0 then
        playerInfo.data.coins = (playerInfo.data.coins or 0) - loss
        StudEvents.UpdateCoins:FireClient(player, playerInfo.data.coins)
        player:SetAttribute('Coins', playerInfo.data.coins)
        table.insert(log, 'Dropped ' .. loss .. ' coins!')
    end
end

-- Helper: pick a wild stud for battle
local function pickWildStud(player)
    local isNight = (Lighting.ClockTime or 12) < 6 or (Lighting.ClockTime or 12) >= 20
    local zoneNames = {'GrassNorth', 'GrassSouth', 'GrassWest', 'GrassEast'}
    local zoneName = zoneNames[math.random(#zoneNames)]
    local luckyCharm = player:GetAttribute('LuckyCharm') and true or false
    local stud = StudData.PickRandomStud(zoneName, isNight, luckyCharm)
    return stud
end

-- Helper: AI chooses an action
local function aiChooseAction(wildStud, playerStud, battleState)
    local wildHP = battleState.wildHP
    local wildMaxHP = battleState.wildMaxHP
    local hpRatio = wildHP / wildMaxHP
    if hpRatio < 0.3 then
        if math.random() < 0.4 then
            return 'Defend'
        end
    end
    local effectiveness = StudData.GetTypeEffectiveness(wildStud.studType, playerStud.studType)
    if effectiveness > 1.0 then
        return 'Attack'
    end
    if effectiveness < 1.0 and math.random() < 0.35 then
        return 'Defend'
    end
    return 'Attack'
end

-- Start a battle
StudEvents.StartBattle.OnServerInvoke = function(player, studId)
    if activeBattles[player.UserId] then
        return { success = false, reason = 'already_in_battle' }
    end
    local activePlayersData = ServerRegistry.Get('ActivePlayers')
    local playerInfo = activePlayersData and activePlayersData[player.UserId]
    if not playerInfo or not playerInfo.data then
        return { success = false, reason = 'no_data' }
    end
    -- Build the battle team (the full team comes from the saved roster;
    -- studId — the lead the client sent — is the last-resort fallback).
    local team = BattleTeam.Build(playerInfo, studId)
    if #team == 0 then
        return { success = false, reason = 'not_owned' }
    end
    local wildStud = pickWildStud(player)
    -- Wild level scales around the lead stud's level (±2, min 1)
    local playerLevel = team[1].level
    local wildLevel = math.clamp(playerLevel + math.random(-2, 2), 1, StudData.MAX_LEVEL)
    local battleState = {
        team = team,
        activeIndex = 1,
        pendingSwitch = false,
        wildStud = wildStud,
        wildLevel = wildLevel,
        wildHP = getMaxHP(wildStud, wildLevel),
        wildMaxHP = getMaxHP(wildStud, wildLevel),
        turn = 1,
        playerDefending = false,
        wildDefending = false,
        log = {},
        isOver = false,
        result = nil,
        catchAttempts = 0,
        busy = false,
        wildEffects = Combat.GatherEffects(wildStud, nil),
    }
    BattleTeam.SetActive(battleState, 1)
    activeBattles[player.UserId] = battleState
    StudEvents.BattleState:FireClient(player, {
        action = 'battle_start',
        playerStud = BattleTeam.ActivePayload(battleState),
        team = BattleTeam.Snapshot(battleState),
        wildStud = {
            id = wildStud.id,
            name = wildStud.name,
            studType = wildStud.studType,
            rarity = wildStud.rarity,
            description = wildStud.description,
            level = wildLevel,
        },
        playerHP = battleState.playerHP,
        playerMaxHP = battleState.playerMaxHP,
        wildHP = battleState.wildHP,
        wildMaxHP = battleState.wildMaxHP,
        turn = battleState.turn,
    })
    return { success = true }
end

-- Handle player battle action
StudEvents.BattleAction.OnServerInvoke = function(player, action, moveIndex)
    if type(action) ~= 'string' then
        return { success = false, reason = 'invalid_action' }
    end
    if moveIndex ~= nil and type(moveIndex) ~= 'number' then
        moveIndex = nil
    end
    local battle = activeBattles[player.UserId]
    if not battle or battle.isOver then
        return { success = false, reason = 'no_battle' }
    end
    -- Re-entrancy guard: AI_DELAY yields inside this invoke, so a spamming
    -- client could otherwise interleave multiple turns at once
    if battle.busy then
        return { success = false, reason = 'busy' }
    end
    battle.busy = true
    local function finish(result)
        battle.busy = false
        return result
    end
    local log = {}
    if action == 'Flee' then
        -- Leaving the arena mid-battle: no rewards, no penalty
        battle.isOver = true
        battle.result = 'fled'
        StudEvents.BattleState:FireClient(player, {
            action = 'battle_end',
            result = 'fled',
            log = { 'You left the battle.' },
        })
        activeBattles[player.UserId] = nil
        return finish({ success = true, result = 'fled' })
    end
    -- While a faint is pending, the only legal move is sending in a reserve
    if battle.pendingSwitch and action ~= 'Switch' then
        return finish({ success = false, reason = 'must_switch' })
    end
    if action == 'Catch' then
        -- Trainer studs are not up for grabs (no turn consumed)
        if battle.trainer then
            StudEvents.BattleState:FireClient(player, {
                action = 'turn_update',
                playerHP = battle.playerHP,
                playerMaxHP = battle.playerMaxHP,
                wildHP = battle.wildHP,
                wildMaxHP = battle.wildMaxHP,
                turn = battle.turn,
                log = { "You can't catch a trainer's stud!" },
            })
            return finish({ success = false, reason = 'trainer' })
        end
        battle.catchAttempts = battle.catchAttempts + 1
        local hpRatio = battle.wildHP / battle.wildMaxHP
        local catchChance = (1 - hpRatio) * 0.6 + CONFIG.CATCH_BONUS * battle.catchAttempts
        local rarityPenalty = {
            Common = 1.0,
            Uncommon = 0.85,
            Rare = 0.65,
            Legendary = 0.4,
        }
        catchChance = catchChance * (rarityPenalty[battle.wildStud.rarity] or 1.0)
        catchChance = math.clamp(catchChance, 0.05, 0.95)
        local caught = math.random() < catchChance
        if caught then
            battle.isOver = true
            battle.result = 'catch'
            -- Shared server-authoritative grant path (SaveManager). Handles
            -- the collection insert, dupe economy, coins, attributes, and
            -- the quest/streak/milestone hooks — identical to wild-encounter
            -- catches, which this path previously drifted from (it inserted
            -- entries with no level/exp/isShiny and skipped every hook).
            local grant = ServerRegistry.Call('GrantCatch', player, battle.wildStud.id, {
                isShiny = false,
                level = battle.wildLevel or 1,
            })
            StudEvents.BattleState:FireClient(player, {
                action = 'battle_end',
                result = 'catch',
                studId = battle.wildStud.id,
                studName = battle.wildStud.name,
                coins = grant and grant.totalCoins or 0,
                log = { 'You caught ' .. battle.wildStud.name .. '!' },
            })
            activeBattles[player.UserId] = nil
            return finish({ success = true, result = 'catch' })
        else
            table.insert(log, 'Failed to catch ' .. battle.wildStud.name .. '!')
            local aiAction = aiChooseAction(battle.wildStud, battle.playerStud, battle)
            battle.playerDefending = false
            if aiAction == 'Attack' then
                local dmg, isCrit, eff, missed, wildMoveName = wildAttack(battle)
                battle.playerHP = math.max(0, battle.playerHP - dmg)
                table.insert(log, wildAttackLog(battle, dmg, isCrit, eff, missed, wildMoveName))
            elseif aiAction == 'Defend' then
                battle.wildDefending = true
                table.insert(log, battle.wildStud.name .. ' braces itself!')
            end
            if battle.playerHP <= 0 then
                if handlePlayerFaint(player, battle, log) then
                    return finish({ success = true, result = 'force_switch', log = log })
                end
                battle.isOver = true
                battle.result = 'lose'
                table.insert(log, battle.playerStud.name .. ' fainted! You lost!')
                applyLossPenalty(player, battle, log)
                StudEvents.BattleState:FireClient(player, {
                    action = 'battle_end',
                    result = 'lose',
                    log = log,
                })
                activeBattles[player.UserId] = nil
                return finish({ success = true, result = 'lose', log = log })
            end
            battle.turn = battle.turn + 1
            battle.wildDefending = false
            StudEvents.BattleState:FireClient(player, {
                action = 'turn_update',
                playerHP = battle.playerHP,
                playerMaxHP = battle.playerMaxHP,
                wildHP = battle.wildHP,
                wildMaxHP = battle.wildMaxHP,
                turn = battle.turn,
                log = log,
                wildAction = aiAction,
            })
            return finish({ success = true, log = log })
        end
    end
    if action == 'Switch' then
        -- Swap the active stud for a reserve. A voluntary switch costs the turn
        -- (the wild acts after); a forced switch after a faint is free.
        if not battle.team or #battle.team <= 1 then
            return finish({ success = false, reason = 'no_team' })
        end
        local targetIdx = moveIndex
        local target = targetIdx and battle.team[targetIdx]
        if not target or targetIdx == battle.activeIndex or target.fainted or target.hp <= 0 then
            return finish({ success = false, reason = 'invalid_switch' })
        end

        local forced = battle.pendingSwitch
        if not forced and battle.team[battle.activeIndex] then
            battle.team[battle.activeIndex].hp = battle.playerHP
        end
        BattleTeam.SetActive(battle, targetIdx)
        battle.pendingSwitch = false
        battle.playerDefending = false

        -- Forced (post-faint) switch: free, the player acts next
        if forced then
            StudEvents.BattleState:FireClient(player, {
                action = 'switch_done',
                playerStud = BattleTeam.ActivePayload(battle),
                team = BattleTeam.Snapshot(battle),
                playerHP = battle.playerHP,
                playerMaxHP = battle.playerMaxHP,
                wildHP = battle.wildHP,
                wildMaxHP = battle.wildMaxHP,
                turn = battle.turn,
                log = { 'Go, ' .. battle.playerStud.name .. '!' },
            })
            return finish({ success = true, result = 'switch_done' })
        end

        -- Voluntary switch: the wild takes its free turn
        table.insert(log, 'You switched to ' .. battle.playerStud.name .. '!')
        task.wait(CONFIG.AI_DELAY)
        local aiAction = aiChooseAction(battle.wildStud, battle.playerStud, battle)
        if aiAction == 'Attack' then
            local dmg, isCrit, eff, missed, wildMoveName = wildAttack(battle)
            battle.playerHP = math.max(0, battle.playerHP - dmg)
            table.insert(log, wildAttackLog(battle, dmg, isCrit, eff, missed, wildMoveName))
        elseif aiAction == 'Defend' then
            battle.wildDefending = true
            table.insert(log, battle.wildStud.name .. ' braces itself!')
        end
        if battle.playerHP <= 0 then
            if handlePlayerFaint(player, battle, log) then
                return finish({ success = true, result = 'force_switch', log = log })
            end
            battle.isOver = true
            battle.result = 'lose'
            table.insert(log, battle.playerStud.name .. ' fainted! You lost!')
            applyLossPenalty(player, battle, log)
            StudEvents.BattleState:FireClient(player, {
                action = 'battle_end',
                result = 'lose',
                log = log,
            })
            activeBattles[player.UserId] = nil
            return finish({ success = true, result = 'lose', log = log })
        end
        battle.turn = battle.turn + 1
        battle.wildDefending = false
        StudEvents.BattleState:FireClient(player, {
            action = 'turn_update',
            playerStud = BattleTeam.ActivePayload(battle), -- card follows the new active stud
            team = BattleTeam.Snapshot(battle),
            playerHP = battle.playerHP,
            playerMaxHP = battle.playerMaxHP,
            wildHP = battle.wildHP,
            wildMaxHP = battle.wildMaxHP,
            turn = battle.turn,
            log = log,
            wildAction = aiAction,
        })
        return finish({ success = true, log = log })
    end
    battle.wildDefending = false
    battle.playerDefending = false
    if action == 'Attack' then
        -- Level-gated move resolution (locked/invalid -> basic move)
        local movePower, moveName, accuracy, move = Combat.ResolveMove(battle.playerStud, moveIndex, battle.playerLevel)
        local dmg, isCrit, eff, missed = Combat.CalculateDamage({
            attacker = battle.playerStud,
            defender = battle.wildStud,
            movePower = movePower,
            accuracy = accuracy,
            attackerLevel = battle.playerLevel,
            defenderLevel = battle.wildLevel,
            atkNature = battle.playerEntry and battle.playerEntry.nature or nil,
            isDefending = battle.wildDefending,
            atkEffects = battle.playerEffects,
            defEffects = battle.wildEffects,
            attackerHpFrac = battle.playerHP / battle.playerMaxHP,
        })
        battle.wildHP = math.max(0, battle.wildHP - dmg)
        if missed then
            table.insert(log, battle.playerStud.name .. ' used ' .. moveName .. '... it missed!')
        else
            local effText = ''
            if eff > 1.1 then effText = ' Super effective!'
            elseif eff < 0.9 then effText = ' Not very effective...'
            end
            local critText = isCrit and ' Critical!' or ''
            table.insert(log, battle.playerStud.name .. ' used ' .. moveName .. '! -' .. dmg .. ' HP' .. effText .. critText)
            -- Status proc on a landed hit (mid-tier Fire/Ice/Electric moves)
            local newStatus = Combat.RollMoveStatus(move, battle.wildStatus, battle.playerEffects, battle.wildEffects)
            if newStatus then
                battle.wildStatus = newStatus
                table.insert(log, battle.wildStud.name .. ' ' .. Combat.STATUS_INFLICT_TEXT[newStatus.kind])
            end
        end
    elseif action == 'Defend' then
        battle.playerDefending = true
        table.insert(log, battle.playerStud.name .. ' braces itself!')
    end
    -- Wild status tick: burn chip (which can finish it off — tick before the
    -- win check), freeze/paralysis make it skip its turn below
    local skipAI = false
    if battle.wildHP > 0 and battle.wildStatus then
        local chip, skip, cured, kind = Combat.TickStatus(battle.wildStatus, battle.wildMaxHP)
        if cured then
            battle.wildStatus = nil
        end
        skipAI = skip
        if chip > 0 then
            battle.wildHP = math.max(0, battle.wildHP - chip)
            table.insert(log, battle.wildStud.name .. ' is hurt by its burn! -' .. chip .. ' HP')
        end
        if skip then
            table.insert(log, battle.wildStud.name .. ' ' .. (Combat.STATUS_SKIP_TEXT[kind] or "can't move!"))
        end
    end
    if battle.wildHP <= 0 then
        table.insert(log, battle.wildStud.name .. ' fainted!')
        local activePlayersData = ServerRegistry.Get('ActivePlayers')
        local playerInfo = activePlayersData and activePlayersData[player.UserId]

        -- EXP per KO — in trainer battles every team member pays out
        local expGained, levelsGained, newLevel = 0, 0, battle.playerLevel
        if battle.playerEntry then
            expGained, levelsGained, newLevel = Combat.AwardExp(battle.playerEntry, battle.wildLevel)
            table.insert(log, battle.playerStud.name .. ' gained ' .. expGained .. ' EXP!')
            if levelsGained > 0 then
                table.insert(log, battle.playerStud.name .. ' grew to Lv' .. newLevel .. '!')
            end
        end

        -- Trainer with team members left: the next stud steps in, fresh HP,
        -- and the PLAYER acts first against it
        if battle.trainer and battle.teamIndex < #battle.trainer.team then
            battle.teamIndex += 1
            local nextDef = battle.trainer.team[battle.teamIndex]
            local nextStud = StudData.GetStudById(nextDef.id)
            battle.wildStud = nextStud
            battle.wildLevel = nextDef.level
            battle.wildMaxHP = getMaxHP(nextStud, nextDef.level)
            battle.wildHP = battle.wildMaxHP
            battle.wildStatus = nil
            battle.wildDefending = false
            battle.turn = battle.turn + 1
            table.insert(log, battle.trainer.name .. ' sent out ' .. nextStud.name .. ' (Lv' .. nextDef.level .. ')!')
            StudEvents.BattleState:FireClient(player, {
                action = 'trainer_next',
                wildStud = {
                    id = nextStud.id,
                    name = nextStud.name,
                    studType = nextStud.studType,
                    rarity = nextStud.rarity,
                    description = nextStud.description,
                    level = nextDef.level,
                },
                wildHP = battle.wildHP,
                wildMaxHP = battle.wildMaxHP,
                playerHP = battle.playerHP,
                playerMaxHP = battle.playerMaxHP,
                turn = battle.turn,
                log = log,
                expGained = expGained,
                newLevel = newLevel,
                newExp = battle.playerEntry and battle.playerEntry.exp or nil,
                leveledUp = levelsGained > 0,
            })
            return finish({ success = true, result = 'trainer_next', log = log })
        end

        battle.isOver = true
        battle.result = 'win'
        table.insert(log, 'You won!')
        if playerInfo and playerInfo.data then
            local data = playerInfo.data
            -- Purse: trainers pay a fixed reward (quartered on rematches,
            -- with a one-time badge on the first win); wilds pay the usual
            -- rarity-scaled random purse
            local coinReward
            if battle.trainer then
                data.trainerBadges = data.trainerBadges or {}
                local firstWin = not data.trainerBadges[battle.trainer.id]
                coinReward = firstWin and battle.trainer.reward
                    or math.floor(battle.trainer.reward * 0.25)
                table.insert(log, battle.trainer.name .. ' pays out ' .. coinReward .. ' coins!')
                if firstWin then
                    data.trainerBadges[battle.trainer.id] = true
                    local badgeCount = 0
                    for _ in pairs(data.trainerBadges) do
                        badgeCount += 1
                    end
                    player:SetAttribute('BadgeCount', badgeCount)
                    table.insert(log, 'Earned the ' .. battle.trainer.badge .. '!')
                    local milestoneEvent = StudEvents:FindFirstChild('MilestoneNotify')
                    if milestoneEvent then
                        milestoneEvent:FireClient(player, 'badge_' .. battle.trainer.id,
                            battle.trainer.badge .. '!',
                            'Defeated ' .. battle.trainer.name .. ' (' .. badgeCount .. '/7 badges)', '🎖️')
                    end
                end
            else
                coinReward = math.random(CONFIG.WIN_COINS_MIN, CONFIG.WIN_COINS_MAX)
                if battle.wildStud.rarity == 'Rare' then coinReward = coinReward * 2
                elseif battle.wildStud.rarity == 'Legendary' then coinReward = coinReward * 3 end
            end
            data.coins = (data.coins or 0) + coinReward
            if not data.evoPoints then data.evoPoints = {} end
            local pType = battle.playerStud.studType
            data.evoPoints[pType] = (data.evoPoints[pType] or 0) + CONFIG.WIN_EVO_POINTS
            StudEvents.UpdateCoins:FireClient(player, data.coins)
            player:SetAttribute('Coins', data.coins)
        end
        -- Daily-quest hook (arena/trainer win)
        ServerRegistry.Call('OnBattleWon', player)
        StudEvents.BattleState:FireClient(player, {
            action = 'battle_end',
            result = 'win',
            coins = playerInfo and playerInfo.data and playerInfo.data.coins or 0,
            expGained = expGained,
            newLevel = newLevel,
            newExp = battle.playerEntry and battle.playerEntry.exp or nil,
            leveledUp = levelsGained > 0,
            log = log,
        })
        activeBattles[player.UserId] = nil
        return finish({ success = true, result = 'win', log = log })
    end
    task.wait(CONFIG.AI_DELAY)
    local aiAction = nil
    if not skipAI then
        aiAction = aiChooseAction(battle.wildStud, battle.playerStud, battle)
        if aiAction == 'Attack' then
            local dmg, isCrit, eff, missed, wildMoveName = wildAttack(battle)
            battle.playerHP = math.max(0, battle.playerHP - dmg)
            table.insert(log, wildAttackLog(battle, dmg, isCrit, eff, missed, wildMoveName))
        elseif aiAction == 'Defend' then
            battle.wildDefending = true
            table.insert(log, battle.wildStud.name .. ' braces itself!')
        end
    end
    if battle.playerHP <= 0 then
        if handlePlayerFaint(player, battle, log) then
            return finish({ success = true, result = 'force_switch', log = log })
        end
        battle.isOver = true
        battle.result = 'lose'
        table.insert(log, battle.playerStud.name .. ' fainted! You lost!')
        applyLossPenalty(player, battle, log)
        StudEvents.BattleState:FireClient(player, {
            action = 'battle_end',
            result = 'lose',
            log = log,
        })
        activeBattles[player.UserId] = nil
        return finish({ success = true, result = 'lose', log = log })
    end
    battle.turn = battle.turn + 1
    -- Trainer teams need more room than a single wild
    local maxTurns = battle.trainer and CONFIG.MAX_TURNS * 3 or CONFIG.MAX_TURNS
    if battle.turn > maxTurns then
        battle.isOver = true
        battle.result = 'draw'
        table.insert(log, 'The battle ended in a draw!')
        StudEvents.BattleState:FireClient(player, {
            action = 'battle_end',
            result = 'draw',
            log = log,
        })
        activeBattles[player.UserId] = nil
        return finish({ success = true, result = 'draw', log = log })
    end
    StudEvents.BattleState:FireClient(player, {
        action = 'turn_update',
        playerHP = battle.playerHP,
        playerMaxHP = battle.playerMaxHP,
        wildHP = battle.wildHP,
        wildMaxHP = battle.wildMaxHP,
        turn = battle.turn,
        log = log,
        wildAction = aiAction,
    })
    return finish({ success = true, log = log })
end

-- ─── TRAINER BATTLES ────────────────────────────────────────────────────
-- Started server-side by TrainerSystem's NPC prompts. Same battle loop as
-- the arena — the trainer is a battle with a team queue: KO one stud and
-- the next steps in (see the trainer branches in BattleAction above).
ServerRegistry.Register('StartTrainerBattle', function(player, trainerDef)
    if activeBattles[player.UserId] then
        return false, 'busy'
    end
    local activePlayersData = ServerRegistry.Get('ActivePlayers')
    local playerInfo = activePlayersData and activePlayersData[player.UserId]
    if not playerInfo or not playerInfo.data then
        return false, 'no_data'
    end

    -- Build the player's battle team (fallback: first owned species)
    local team = BattleTeam.Build(playerInfo)
    if #team == 0 then
        return false, 'no_stud'
    end

    local firstDef = trainerDef.team[1]
    local wildStud = StudData.GetStudById(firstDef.id)
    if not wildStud then
        return false, 'bad_team'
    end

    local battleState = {
        team = team,
        activeIndex = 1,
        pendingSwitch = false,
        wildStud = wildStud,
        wildLevel = firstDef.level,
        wildHP = getMaxHP(wildStud, firstDef.level),
        wildMaxHP = getMaxHP(wildStud, firstDef.level),
        turn = 1,
        playerDefending = false,
        wildDefending = false,
        log = {},
        isOver = false,
        result = nil,
        catchAttempts = 0,
        busy = false,
        trainer = trainerDef,
        teamIndex = 1,
    }
    BattleTeam.SetActive(battleState, 1)
    activeBattles[player.UserId] = battleState

    StudEvents.BattleState:FireClient(player, {
        action = 'battle_start',
        isTrainer = true,
        trainerName = trainerDef.name,
        playerStud = BattleTeam.ActivePayload(battleState),
        team = BattleTeam.Snapshot(battleState),
        wildStud = {
            id = wildStud.id,
            name = wildStud.name,
            studType = wildStud.studType,
            rarity = wildStud.rarity,
            description = wildStud.description,
            level = firstDef.level,
        },
        playerHP = battleState.playerHP,
        playerMaxHP = battleState.playerMaxHP,
        wildHP = battleState.wildHP,
        wildMaxHP = battleState.wildMaxHP,
        turn = 1,
        log = {
            trainerDef.name .. ' wants to battle!',
            trainerDef.name .. ' sent out ' .. wildStud.name .. ' (Lv' .. firstDef.level .. ')!',
        },
    })
    return true
end)

-- Get player studs available for battle
StudEvents.RequestBattleStuds.OnServerInvoke = function(player)
    local activePlayersData = ServerRegistry.Get('ActivePlayers')
    local playerInfo = activePlayersData and activePlayersData[player.UserId]
    if not playerInfo or not playerInfo.data then
        return {}
    end
    -- PERF: single pass — track the best (highest-level) copy per species as
    -- we go. The old shape called getOwnedEntry (an O(n) scan) inside the
    -- loop, making this O(n^2) on the collection.
    local bestLevel = {} -- [studId] = highest owned level
    local order = {} -- species in first-seen order
    for _, caught in ipairs(playerInfo.data.caughtStuds) do
        local lvl = caught.level or 1
        if not bestLevel[caught.id] then
            table.insert(order, caught.id)
            bestLevel[caught.id] = lvl
        elseif lvl > bestLevel[caught.id] then
            bestLevel[caught.id] = lvl
        end
    end
    local uniqueStuds = {}
    for _, studId in ipairs(order) do
        local studData = StudData.GetStudById(studId)
        if studData then
            local lvl = bestLevel[studId]
            table.insert(uniqueStuds, {
                id = studData.id,
                name = studData.name,
                studType = studData.studType,
                rarity = studData.rarity,
                level = lvl,
                maxHP = getMaxHP(studData, lvl),
            })
        end
    end
    return uniqueStuds
end

-- Clean up when players leave
Players.PlayerRemoving:Connect(function(player)
    activeBattles[player.UserId] = nil
end)

print('[BattleSystem] Initialized')