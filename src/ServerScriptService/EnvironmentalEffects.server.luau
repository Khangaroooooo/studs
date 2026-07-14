local EnvironmentalEffects = {}

-- Creates atmospheric particle effects: fireflies at night, leaves, dust motes
-- Also adds zone-specific particles (mist in water zones, embers in fire zones)

local RunService = game:GetService("RunService")

local studville = game.Workspace.Studville
local encounterZones = studville:FindFirstChild("EncounterZones")
local decorations = studville:FindFirstChild("Decorations")

-- ===== FIREFLY PARTICLES (appear at night) =====
local function createFireflies()
    -- Create firefly emitters around the town
    local fireflyPositions = {
        Vector3.new(0, 8, 0), -- Center plaza
        Vector3.new(-20, 6, 0),
        Vector3.new(20, 6, 0),
        Vector3.new(0, 6, -20),
        Vector3.new(0, 6, 20),
        Vector3.new(-15, 5, -15),
        Vector3.new(15, 5, 15),
        Vector3.new(-15, 5, 15),
        Vector3.new(15, 5, -15),
    }
    
    local fireflyFolder = Instance.new("Folder")
    fireflyFolder.Name = "Fireflies"
    fireflyFolder.Parent = studville
    
    for i, pos in ipairs(fireflyPositions) do
        local emitter = Instance.new("Part")
        emitter.Name = "FireflyEmitter_" .. i
        emitter.Size = Vector3.new(0.1, 0.1, 0.1)
        emitter.Position = pos
        emitter.Anchored = true
        emitter.CanCollide = false
        emitter.Transparency = 1
        emitter.Parent = fireflyFolder
        
        local firefly = Instance.new("ParticleEmitter")
        firefly.Name = "Fireflies"
        firefly.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 255, 100)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 150)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 255, 100))
        })
        firefly.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.3, 0.12),
            NumberSequenceKeypoint.new(0.7, 0.12),
            NumberSequenceKeypoint.new(1, 0)
        })
        firefly.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0),
            NumberSequenceKeypoint.new(0.8, 0),
            NumberSequenceKeypoint.new(1, 1)
        })
        firefly.Lifetime = NumberRange.new(3, 6)
        firefly.Rate = 4
        firefly.Speed = NumberRange.new(0.5, 2)
        firefly.SpreadAngle = Vector2.new(180, 180)
        firefly.LightEmission = 1
        firefly.LightInfluence = 1
        firefly.RotSpeed = NumberRange.new(-180, 180)
        firefly.Enabled = false -- Start disabled, enabled at night
        firefly.Parent = emitter
    end
    
    return fireflyFolder
end

-- ===== LEAF PARTICLES (gentle falling leaves) =====
local function createLeaves()
    local leafFolder = Instance.new("Folder")
    leafFolder.Name = "Leaves"
    leafFolder.Parent = studville
    
    -- Place leaf emitters near trees
    local treePositions = {}
    if decorations then
        for _, child in ipairs(decorations:GetChildren()) do
            if child.Name:find("Tree") and child:IsA("Model") then
                table.insert(treePositions, child:GetPivot().Position + Vector3.new(0, 12, 0))
            end
        end
    end
    
    -- Also add some around the town
    for i = 1, 4 do
        table.insert(treePositions, Vector3.new(math.random(-30, 30), 15, math.random(-30, 30)))
    end
    
    for i, pos in ipairs(treePositions) do
        local emitter = Instance.new("Part")
        emitter.Name = "LeafEmitter_" .. i
        emitter.Size = Vector3.new(0.1, 0.1, 0.1)
        emitter.Position = pos
        emitter.Anchored = true
        emitter.CanCollide = false
        emitter.Transparency = 1
        emitter.Parent = leafFolder
        
        local leaf = Instance.new("ParticleEmitter")
        leaf.Name = "Leaves"
        leaf.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 140, 50)),
            ColorSequenceKeypoint.new(0.5, Color3.fromRGB(100, 160, 60)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 120, 40))
        })
        leaf.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(0.5, 0.3),
            NumberSequenceKeypoint.new(1, 0.15)
        })
        leaf.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(0.8, 0.3),
            NumberSequenceKeypoint.new(1, 1)
        })
        leaf.Lifetime = NumberRange.new(4, 8)
        leaf.Rate = 1
        leaf.Speed = NumberRange.new(1, 3)
        leaf.SpreadAngle = Vector2.new(30, 30)
        leaf.EmissionDirection = Enum.NormalId.Bottom
        leaf.RotSpeed = NumberRange.new(-90, 90)
        leaf.Acceleration = Vector3.new(0.5, -0.5, 0.3) -- Gentle wind
        leaf.LightInfluence = 0.5
        leaf.Parent = emitter
    end
    
    return leafFolder
end

-- ===== ZONE-SPECIFIC PARTICLES =====
local function createZoneParticles()
    if not encounterZones then return end
    
    -- Mist particles for water/ice zones
    for _, zoneName in ipairs({"GrassSouth", "GrassEast"}) do
        local zone = encounterZones:FindFirstChild(zoneName)
        if zone then
            local grassBase = zone:FindFirstChild("GrassBase")
            if grassBase then
                local mist = Instance.new("ParticleEmitter")
                mist.Name = "Mist"
                mist.Color = ColorSequence.new(Color3.fromRGB(200, 220, 255))
                mist.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 2),
                    NumberSequenceKeypoint.new(0.5, 4),
                    NumberSequenceKeypoint.new(1, 2)
                })
                mist.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.3, 0.6),
                    NumberSequenceKeypoint.new(0.7, 0.6),
                    NumberSequenceKeypoint.new(1, 1)
                })
                mist.Lifetime = NumberRange.new(4, 8)
                mist.Rate = 2
                mist.Speed = NumberRange.new(0.3, 1)
                mist.SpreadAngle = Vector2.new(180, 180)
                mist.EmissionDirection = Enum.NormalId.Top
                mist.LightEmission = 0.3
                mist.RotSpeed = NumberRange.new(-20, 20)
                mist.Parent = grassBase
            end
        end
    end
    
    -- Ember particles for fire/rock zones
    for _, zoneName in ipairs({"GrassWest"}) do
        local zone = encounterZones:FindFirstChild(zoneName)
        if zone then
            local grassBase = zone:FindFirstChild("GrassBase")
            if grassBase then
                local ember = Instance.new("ParticleEmitter")
                ember.Name = "Embers"
                ember.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 100, 0)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 200, 50)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 50, 0))
                })
                ember.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.3, 0.1),
                    NumberSequenceKeypoint.new(0.7, 0.08),
                    NumberSequenceKeypoint.new(1, 0)
                })
                ember.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.2, 0),
                    NumberSequenceKeypoint.new(0.8, 0.3),
                    NumberSequenceKeypoint.new(1, 1)
                })
                ember.Lifetime = NumberRange.new(2, 4)
                ember.Rate = 3
                ember.Speed = NumberRange.new(1, 3)
                ember.SpreadAngle = Vector2.new(30, 30)
                ember.EmissionDirection = Enum.NormalId.Top
                ember.LightEmission = 1
                ember.Acceleration = Vector3.new(0, 1, 0) -- Rise upward
                ember.Parent = grassBase
            end
        end
    end
    
    -- Sparkle particles for electric zones
    for _, zoneName in ipairs({"GrassNorth"}) do
        local zone = encounterZones:FindFirstChild(zoneName)
        if zone then
            local grassBase = zone:FindFirstChild("GrassBase")
            if grassBase then
                local spark = Instance.new("ParticleEmitter")
                spark.Name = "Sparks"
                spark.Color = ColorSequence.new(Color3.fromRGB(255, 255, 100))
                spark.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0),
                    NumberSequenceKeypoint.new(0.5, 0.08),
                    NumberSequenceKeypoint.new(1, 0)
                })
                spark.Transparency = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 1),
                    NumberSequenceKeypoint.new(0.3, 0),
                    NumberSequenceKeypoint.new(0.7, 0),
                    NumberSequenceKeypoint.new(1, 1)
                })
                spark.Lifetime = NumberRange.new(0.3, 0.8)
                spark.Rate = 5
                spark.Speed = NumberRange.new(2, 5)
                spark.SpreadAngle = Vector2.new(180, 180)
                spark.LightEmission = 1
                spark.Parent = grassBase
            end
        end
    end
end

-- ===== DUST MOTES (ambient, always present) =====
local function createDustMotes()
    local dustFolder = Instance.new("Folder")
    dustFolder.Name = "DustMotes"
    dustFolder.Parent = studville
    
    for i = 1, 6 do
        local emitter = Instance.new("Part")
        emitter.Name = "DustEmitter_" .. i
        emitter.Size = Vector3.new(0.1, 0.1, 0.1)
        emitter.Position = Vector3.new(math.random(-25, 25), math.random(3, 8), math.random(-25, 25))
        emitter.Anchored = true
        emitter.CanCollide = false
        emitter.Transparency = 1
        emitter.Parent = dustFolder
        
        local dust = Instance.new("ParticleEmitter")
        dust.Name = "Dust"
        dust.Color = ColorSequence.new(Color3.fromRGB(255, 250, 220))
        dust.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.5, 0.06),
            NumberSequenceKeypoint.new(1, 0)
        })
        dust.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.3, 0.5),
            NumberSequenceKeypoint.new(0.7, 0.5),
            NumberSequenceKeypoint.new(1, 1)
        })
        dust.Lifetime = NumberRange.new(5, 10)
        dust.Rate = 2
        dust.Speed = NumberRange.new(0.2, 0.5)
        dust.SpreadAngle = Vector2.new(180, 180)
        dust.LightEmission = 0.5
        dust.LightInfluence = 1
        dust.RotSpeed = NumberRange.new(-45, 45)
        dust.Parent = emitter
    end
    
    return dustFolder
end

-- ===== FIREFLY NIGHT CONTROL =====
local fireflyFolder

local function updateFireflies()
    -- Check time of day to toggle fireflies
    local clockTime = game.Lighting.ClockTime
    local isNight = clockTime >= 18 or clockTime <= 6
    
    if fireflyFolder then
        for _, emitter in ipairs(fireflyFolder:GetChildren()) do
            for _, particle in ipairs(emitter:GetChildren()) do
                if particle:IsA("ParticleEmitter") and particle.Name == "Fireflies" then
                    particle.Enabled = isNight
                end
            end
        end
    end
end

-- ===== INITIALIZE ALL EFFECTS =====
fireflyFolder = createFireflies()
createLeaves()
createZoneParticles()
createDustMotes()

-- Update fireflies based on day/night cycle.
-- isNight only actually flips twice a day, so recalculating it 60x/second
-- (via an unthrottled Heartbeat) was pure wasted server CPU that scales with
-- however many firefly emitters are placed in the world. A ~1s throttle is
-- imperceptible for a lighting-driven toggle but cuts that cost by ~98%.
local FIREFLY_CHECK_INTERVAL = 1
local fireflyCheckElapsed = 0

updateFireflies() -- run once immediately so fireflies aren't wrong on load

RunService.Heartbeat:Connect(function(dt)
    fireflyCheckElapsed += dt
    if fireflyCheckElapsed >= FIREFLY_CHECK_INTERVAL then
        fireflyCheckElapsed = 0
        updateFireflies()
    end
end)

print("[EnvironmentalEffects] Fireflies, leaves, zone particles, and dust motes initialized")