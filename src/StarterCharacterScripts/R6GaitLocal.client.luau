-- R6GaitLocal: drives the reworked procedural walk/run/idle/jump gait on the
-- LOCAL player's own R6 character (a LocalScript in StarterCharacterScripts runs
-- only in the character the local player owns).
--
-- It disables the default `Animate` script so no stock locomotion animation
-- plays or replicates, then poses the six Motor6Ds every frame via R6Gait. Other
-- clients reproduce this same pose for us from our replicated velocity/state
-- (see R6GaitRemote), so everyone sees the custom gait.
--
-- No-ops on a non-R6 rig (R6Gait.resolve returns nil) and, crucially, only
-- disables Animate once R6 joints are confirmed — so if the character ever spawns
-- R15 it keeps its default animation instead of freezing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local R6Gait = require(ReplicatedStorage:WaitForChild("R6Gait"))

local character = script.Parent
local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
if not (humanoid and hrp) then
	return
end

local joints = R6Gait.resolve(character)
if not joints then
	return -- not R6: leave the default Animate running
end

-- Confirmed R6 — silence the stock locomotion animator so it doesn't fight us
-- or replicate a competing pose.
local animate = character:FindFirstChild("Animate")
if animate then
	(animate :: LocalScript).Disabled = true
end

local state = R6Gait.newState()

RunService.RenderStepped:Connect(function(dt)
	if not (character.Parent and hrp.Parent and humanoid.Health > 0) then
		return
	end
	local vel = hrp.AssemblyLinearVelocity
	local planarSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
	local hstate = humanoid:GetState()
	local airborne = hstate == Enum.HumanoidStateType.Freefall
		or hstate == Enum.HumanoidStateType.Jumping
	local grounded = not airborne and humanoid.FloorMaterial ~= Enum.Material.Air

	R6Gait.step(joints, state, {
		planarSpeed = planarSpeed,
		grounded = grounded,
		airborne = airborne,
		moving = planarSpeed > 0.5,
		facing = hrp.CFrame.LookVector,
	}, dt)
end)
