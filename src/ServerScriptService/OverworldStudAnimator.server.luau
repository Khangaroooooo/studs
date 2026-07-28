local OverworldStudAnimator = {}

-- Animates overworld Stud tiles: floating, bobbing, wandering within their zones
-- Also handles respawning when they drift too far

local RunService = game:GetService("RunService")

local overworldFolder = game.Workspace.Studville:FindFirstChild("OverworldStuds")
if not overworldFolder then return end

-- Track each stud's animation state
local studStates = {}

local WANDER_RADIUS = 12 -- Max distance from home position
local WANDER_SPEED = 1.5
local BOB_SPEED = 2
local BOB_HEIGHT = 0.3
local FLOAT_HEIGHT = 1.5
local RESPAWN_DELAY = 30 -- Seconds before a hidden stud reappears

local function initStud(stud)
    if studStates[stud] then return end
    
    local homePos = stud.Position
    local targetPos = homePos
    local wanderTimer = 0
    local phase = math.random() * math.pi * 2 -- Random phase offset for bobbing
    
    studStates[stud] = {
        homePos = homePos,
        targetPos = targetPos,
        wanderTimer = wanderTimer,
        phase = phase,
        visible = true,
        respawnTimer = 0
    }
    
    -- Make stud face camera (billboard style)
    stud.Anchored = true
end

local function pickNewTarget(stud, state)
    local home = state.homePos
    local angle = math.random() * math.pi * 2
    local dist = math.random() * WANDER_RADIUS
    state.targetPos = Vector3.new(
        home.X + math.cos(angle) * dist,
        home.Y,
        home.Z + math.sin(angle) * dist
    )
    state.wanderTimer = math.random(3, 8) -- Time before next direction change
end

local function updateStud(stud, state, dt)
    -- Handle visibility
    if not state.visible then
        state.respawnTimer = state.respawnTimer - dt
        if state.respawnTimer <= 0 then
            state.visible = true
            stud.Transparency = 0
            -- Reset to home position
            stud.CFrame = CFrame.new(state.homePos + Vector3.new(0, FLOAT_HEIGHT, 0))
            pickNewTarget(stud, state)
        end
        return
    end
    
    -- Wander towards target
    state.wanderTimer = state.wanderTimer - dt
    if state.wanderTimer <= 0 then
        pickNewTarget(stud, state)
    end
    
    -- Move towards target position (XZ only)
    local currentPos = stud.Position
    local targetXZ = Vector3.new(state.targetPos.X, currentPos.Y, state.targetPos.Z)
    local direction = (targetXZ - currentPos)
    local dist = direction.Magnitude
    
    if dist > 0.5 then
        local moveDir = direction.Unit * WANDER_SPEED * dt
        local newPos = currentPos + moveDir
        
        -- Bob up and down
        state.phase = state.phase + BOB_SPEED * dt
        local bobOffset = math.sin(state.phase) * BOB_HEIGHT
        
        -- Face movement direction
        local lookDir = CFrame.lookAt(currentPos, targetXZ)
        
        stud.CFrame = CFrame.new(
            Vector3.new(newPos.X, state.homePos.Y + FLOAT_HEIGHT + bobOffset, newPos.Z),
            Vector3.new(newPos.X + lookDir.LookVector.X, state.homePos.Y + FLOAT_HEIGHT + bobOffset, newPos.Z + lookDir.LookVector.Z)
        )
    else
        -- Just bob in place
        state.phase = state.phase + BOB_SPEED * dt
        local bobOffset = math.sin(state.phase) * BOB_HEIGHT
        stud.CFrame = CFrame.new(
            Vector3.new(currentPos.X, state.homePos.Y + FLOAT_HEIGHT + bobOffset, currentPos.Z),
            Vector3.new(currentPos.X, state.homePos.Y + FLOAT_HEIGHT + bobOffset, currentPos.Z + 1)
        )
    end
    
    -- Check if too far from home, pull back
    local distFromHome = Vector3.new(currentPos.X - state.homePos.X, 0, currentPos.Z - state.homePos.Z).Magnitude
    if distFromHome > WANDER_RADIUS * 1.5 then
        pickNewTarget(stud, state)
    end
end

-- Initialize all existing overworld studs
for _, stud in ipairs(overworldFolder:GetChildren()) do
    if stud:IsA("BasePart") then
        initStud(stud)
    elseif stud:IsA("Model") then
        local body = stud:FindFirstChild("Body")
        if body and body:IsA("BasePart") then
            initStud(body)
        end
    end
end

-- Handle studs added later
overworldFolder.ChildAdded:Connect(function(child)
    if child:IsA("BasePart") then
        task.wait(0.1)
        initStud(child)
    elseif child:IsA("Model") then
        local body = child:FindFirstChild("Body")
        if body and body:IsA("BasePart") then
            task.wait(0.1)
            initStud(body)
        end
    end
end)

-- When a player catches a stud, hide the corresponding overworld stud briefly
-- (This is handled by the encounter system - we just provide the function)
local function hideStud(stud)
    local state = studStates[stud]
    if state then
        state.visible = false
        state.respawnTimer = RESPAWN_DELAY
        stud.Transparency = 1
        -- Hide particles too
        for _, child in ipairs(stud:GetChildren()) do
            if child:IsA("ParticleEmitter") then
                child.Enabled = false
            end
        end
    end
end

-- Main update loop.
-- These CFrame writes happen on the SERVER, so every single update replicates
-- to every client. At 60Hz with N studs that's 60*N property replications/sec.
-- Throttling to 10Hz cuts network + server CPU by ~83% with no visible
-- difference (clients interpolate anchored part movement smoothly anyway).
local UPDATE_RATE = 1 / 10
local accum = 0

RunService.Heartbeat:Connect(function(dt)
    accum += dt
    if accum < UPDATE_RATE then return end
    local step = accum
    accum = 0
    for stud, state in pairs(studStates) do
        if stud.Parent then
            updateStud(stud, state, step)
        else
            studStates[stud] = nil
        end
    end
end)

-- Expose hideStud for other scripts
_G.HideOverworldStud = hideStud

print("[OverworldStudAnimator] Initialized with " .. #overworldFolder:GetChildren() .. " studs")