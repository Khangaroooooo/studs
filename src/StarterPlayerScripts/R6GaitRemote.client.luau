-- R6GaitRemote: reproduces the procedural walk/run gait for OTHER players'
-- R6 characters on this client, driven from their replicated velocity and
-- Humanoid state. Their owner disabled its default Animate (see R6GaitLocal), so
-- no stock pose replicates and there's nothing to double up with — we simply
-- pose their Motor6Ds locally each frame, exactly as we do for ourselves.
--
-- The local player's own character is handled by R6GaitLocal, so it's skipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local R6Gait = require(ReplicatedStorage:WaitForChild("R6Gait"))

local localPlayer = Players.LocalPlayer

type Rig = {
	character: Model,
	humanoid: Humanoid,
	hrp: BasePart,
	joints: R6Gait.Joints,
	state: R6Gait.State,
}

local rigs: { [Player]: Rig } = {}

local function track(plr: Player, character: Model)
	rigs[plr] = nil
	local humanoid = character:WaitForChild("Humanoid", 10)
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not (humanoid and humanoid:IsA("Humanoid") and hrp and hrp:IsA("BasePart")) then
		return
	end
	if character.Parent == nil then
		return
	end
	local joints = R6Gait.resolve(character)
	if not joints then
		return -- not R6
	end
	rigs[plr] = {
		character = character,
		humanoid = humanoid,
		hrp = hrp,
		joints = joints,
		state = R6Gait.newState(),
	}
end

local function watch(plr: Player)
	if plr == localPlayer then
		return
	end
	plr.CharacterAdded:Connect(function(c) task.spawn(track, plr, c) end)
	plr.CharacterRemoving:Connect(function() rigs[plr] = nil end)
	if plr.Character then
		task.spawn(track, plr, plr.Character)
	end
end

Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(plr) rigs[plr] = nil end)
for _, plr in Players:GetPlayers() do
	watch(plr)
end

RunService.RenderStepped:Connect(function(dt)
	for plr, rig in rigs do
		if not (rig.character.Parent and rig.hrp.Parent) then
			rigs[plr] = nil
			continue
		end
		local vel = rig.hrp.AssemblyLinearVelocity
		local planarSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local hstate = rig.humanoid:GetState()
		local airborne = hstate == Enum.HumanoidStateType.Freefall
			or hstate == Enum.HumanoidStateType.Jumping
		local grounded = not airborne and rig.humanoid.FloorMaterial ~= Enum.Material.Air

		R6Gait.step(rig.joints, rig.state, {
			planarSpeed = planarSpeed,
			grounded = grounded,
			airborne = airborne,
			moving = planarSpeed > 0.5,
			facing = rig.hrp.CFrame.LookVector,
		}, dt)
	end
end)
