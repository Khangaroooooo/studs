--!strict
--[[
	R6Gait.luau — procedural R6 locomotion (idle / walk / run / jump / fall).

	Why procedural: custom keyframe animations need to be uploaded to Roblox to
	get an asset id an Animator can play. This drives the six R6 Motor6Ds by hand
	each frame instead, so the reworked walk/run needs no upload and is fully
	tunable in code.

	How it's driven (see R6GaitLocal / R6GaitRemote): the character's OWNER
	disables its default `Animate` script (so no default Transform replicates),
	then animates itself locally; every other client re-derives the same pose for
	that character from its replicated velocity + Humanoid state. Nothing writes
	C0 on the server and nothing relies on C0 replicating — each client poses
	everyone locally, so all viewers see the same gait with no server cost.

	Technique: with Animate disabled there is no animator writing Motor6D.Transform,
	so we own the pose outright via each joint's C0 = base * offset. Offsets are
	measured, not guessed (calibrated live on an R6 rig):
	  • Limb forward/back swing = rotation about the joint's local Z. Right limb
	    +Z swings forward, left limb +Z swings backward — so the SAME +Z on both
	    hips gives a natural contralateral stride (right fwd / left back).
	  • Torso (RootJoint) +X = lean forward, +Y = roll left, +Z = yaw left,
	    +Y translate (in HRP space) = hips rise.

	Stateless-per-call: caller owns the Joints handle (resolve) and a State table
	(newState) and feeds inputs to step.
]]

local R6Gait = {}

local rad = math.rad

-- ─── Tunables ────────────────────────────────────────────────────────────
local REF_SPEED = 16 -- default walk speed
local STRIDE = 0.55 -- gait phase (radians) advanced per stud travelled

local LEG_AMP_WALK, LEG_AMP_RUN = rad(26), rad(48) -- hip swing amplitude
local ARM_AMP_WALK, ARM_AMP_RUN = rad(18), rad(50) -- shoulder swing amplitude
local BOB_WALK, BOB_RUN = 0.12, 0.26 -- studs of hip rise per step
local LAT_SWAY = 0.05 -- studs of side-to-side hip sway
local LEAN_MAX = rad(15) -- forward lean at top speed
local BANK_GAIN, BANK_MAX = 0.28, rad(14) -- roll into turns
local SWAY_YAW = rad(2.5) -- torso counter-yaw against the stride
local BREATH = rad(2) -- idle arm sway

local LEG_AIR = rad(18) -- legs tuck forward in the air
local ARM_AIR = rad(135) -- arms swing up in the air

-- Smoothing time-constants (s). Smaller = snappier.
local TAU_AMP, TAU_AIR, TAU_LEAN, TAU_BANK = 0.11, 0.10, 0.15, 0.12

export type Joints = {
	root: Motor6D, rootBase: CFrame,
	neck: Motor6D, neckBase: CFrame,
	rShoulder: Motor6D, rShoulderBase: CFrame,
	lShoulder: Motor6D, lShoulderBase: CFrame,
	rHip: Motor6D, rHipBase: CFrame,
	lHip: Motor6D, lHipBase: CFrame,
}

export type State = {
	t: number, phase: number,
	ampWalk: number, airBlend: number, lean: number, bank: number,
	lastFacingYaw: number?,
}

export type Input = {
	planarSpeed: number, -- horizontal speed, studs/s
	grounded: boolean, -- standing on ground (not airborne)
	airborne: boolean, -- jumping or freefalling
	moving: boolean, -- has meaningful horizontal input/velocity
	facing: Vector3, -- root part forward (world)
}

local function damp(cur: number, tgt: number, tau: number, dt: number): number
	return cur + (tgt - cur) * (1 - math.exp(-dt / math.max(tau, 1e-4)))
end
local function mix(a: number, b: number, t: number): number
	return a + (b - a) * t
end
local function wrapPi(a: number): number
	return (a + math.pi) % (2 * math.pi) - math.pi
end

-- Resolve the six R6 joints. Returns nil for non-R6 rigs (R15/constraint) or a
-- half-assembled character, so callers no-op cleanly.
function R6Gait.resolve(character: Instance): Joints?
	local torso = character:FindFirstChild("Torso")
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not (torso and hrp) then
		return nil -- R15 has "UpperTorso"/"LowerTorso", not "Torso"
	end
	local root = hrp:FindFirstChild("RootJoint")
	local neck = torso:FindFirstChild("Neck")
	local rs = torso:FindFirstChild("Right Shoulder")
	local ls = torso:FindFirstChild("Left Shoulder")
	local rh = torso:FindFirstChild("Right Hip")
	local lh = torso:FindFirstChild("Left Hip")
	if not (root and neck and rs and ls and rh and lh) then
		return nil
	end
	local function ism(x: Instance): boolean return x:IsA("Motor6D") end
	if not (ism(root) and ism(neck) and ism(rs) and ism(ls) and ism(rh) and ism(lh)) then
		return nil
	end
	return {
		root = root :: Motor6D, rootBase = (root :: Motor6D).C0,
		neck = neck :: Motor6D, neckBase = (neck :: Motor6D).C0,
		rShoulder = rs :: Motor6D, rShoulderBase = (rs :: Motor6D).C0,
		lShoulder = ls :: Motor6D, lShoulderBase = (ls :: Motor6D).C0,
		rHip = rh :: Motor6D, rHipBase = (rh :: Motor6D).C0,
		lHip = lh :: Motor6D, lHipBase = (lh :: Motor6D).C0,
	}
end

function R6Gait.newState(): State
	return { t = 0, phase = 0, ampWalk = 0, airBlend = 0, lean = 0, bank = 0, lastFacingYaw = nil }
end

function R6Gait.step(j: Joints, s: State, input: Input, dt: number)
	dt = math.clamp(dt, 1 / 240, 1 / 15)
	s.t += dt

	local speed = input.planarSpeed
	local runBlend = math.clamp((speed - REF_SPEED) / 8, 0, 1)
	local legAmp = mix(LEG_AMP_WALK, LEG_AMP_RUN, runBlend)
	local armAmp = mix(ARM_AMP_WALK, ARM_AMP_RUN, runBlend)
	local bobAmp = mix(BOB_WALK, BOB_RUN, runBlend)

	-- Smoothed gates/scalars.
	local ampTgt = (input.grounded and input.moving) and math.clamp(speed / 6, 0, 1) or 0
	s.ampWalk = damp(s.ampWalk, ampTgt, TAU_AMP, dt)
	s.airBlend = damp(s.airBlend, input.airborne and 1 or 0, TAU_AIR, dt)
	local leanTgt = math.clamp(speed / 24, 0, 1) * LEAN_MAX
	s.lean = damp(s.lean, leanTgt, TAU_LEAN, dt)

	-- Advance the stride only while actually walking on the ground.
	if s.ampWalk > 0.02 and input.grounded then
		s.phase = (s.phase + speed * dt * STRIDE) % (2 * math.pi)
	end
	local ph = s.phase

	-- Turn rate → banking into turns.
	local facingYaw = math.atan2(input.facing.X, input.facing.Z)
	local turnRate = s.lastFacingYaw and wrapPi(facingYaw - s.lastFacingYaw) / dt or 0
	s.lastFacingYaw = facingYaw
	s.bank = damp(s.bank, math.clamp(turnRate * BANK_GAIN, -BANK_MAX, BANK_MAX), TAU_BANK, dt)

	local sinp = math.sin(ph)
	local swing = sinp * legAmp * s.ampWalk -- shared hip Z (right fwd / left back)
	local armSwing = -sinp * armAmp * s.ampWalk -- shared shoulder Z (counter to legs)
	local idle = (1 - s.ampWalk) * (1 - s.airBlend)
	local breath = math.sin(s.t * 1.5) * BREATH * idle

	-- Legs: blend stride → tuck. Right/left air poses mirror by sign so both
	-- knees come up forward.
	j.rHip.C0 = j.rHipBase * CFrame.Angles(0, 0, mix(swing, LEG_AIR, s.airBlend))
	j.lHip.C0 = j.lHipBase * CFrame.Angles(0, 0, mix(swing, -LEG_AIR, s.airBlend))

	-- Arms: counter-swing + idle breath, blend → raised in the air.
	j.rShoulder.C0 = j.rShoulderBase * CFrame.Angles(0, 0, mix(armSwing + breath, ARM_AIR, s.airBlend))
	j.lShoulder.C0 = j.lShoulderBase * CFrame.Angles(0, 0, mix(armSwing - breath, -ARM_AIR, s.airBlend))

	-- Torso: hip bob + lateral sway (translation, HRP space) and
	-- lean / bank / counter-yaw (rotation, post-multiplied on the base).
	local effLean = s.lean * (1 - s.airBlend) + (-rad(6)) * s.airBlend
	local bob = math.sin(ph * 2) * bobAmp * s.ampWalk
	local lat = sinp * LAT_SWAY * s.ampWalk
	local yaw = -sinp * SWAY_YAW * s.ampWalk
	j.root.C0 = CFrame.new(lat, bob, 0) * j.rootBase * CFrame.Angles(effLean, s.bank, yaw)

	j.neck.C0 = j.neckBase -- head held steady
end

-- Restore rest pose (call if the driver stops while the character lives).
function R6Gait.reset(j: Joints)
	j.root.C0 = j.rootBase
	j.neck.C0 = j.neckBase
	j.rShoulder.C0 = j.rShoulderBase
	j.lShoulder.C0 = j.lShoulderBase
	j.rHip.C0 = j.rHipBase
	j.lHip.C0 = j.lHipBase
end

return R6Gait
