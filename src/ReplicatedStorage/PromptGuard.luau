--!strict
-- PromptGuard: server-side proximity validation for ProximityPrompt handlers.
--
-- SECURITY: ProximityPrompt.Triggered is client-driven. MaxActivationDistance,
-- RequiresLineOfSight and HoldDuration are enforced on the CLIENT, so an
-- exploiter fires Triggered from anywhere on the map, at any rate, without ever
-- walking to the prompt. Treat every Triggered handler exactly like a
-- RemoteEvent and re-check proximity on the server:
--
--   prompt.Triggered:Connect(function(player)
--       if not PromptGuard.CanUse(player, prompt) then return end
--       ...
--   end)
--
-- Put the check ahead of any cooldown bookkeeping, so a forged trigger can't
-- consume the player's cooldown either.
--
-- Lives here (rather than ServerScriptService) to match RateLimiter, the other
-- server-only helper shared across systems. Nothing here is secret.
--
-- Params are annotated `any` on purpose: luau-analyze runs in this repo without
-- Roblox type definitions, so naming ProximityPrompt/Player/Vector3 resolves to
-- Unknown type and then cascades into bogus errors on every member access under
-- --!strict. Real annotations can go back once luau-lsp is set up with an API
-- dump; until then they'd only produce noise that hides real findings.

local PromptGuard = {}

-- Studs of tolerance on top of the prompt's own range, covering lag and the
-- offset between HumanoidRootPart and where the player visually stands.
PromptGuard.DISTANCE_SLACK = 8

-- Fallback when a prompt reports a non-positive MaxActivationDistance.
local DEFAULT_DISTANCE = 10

-- World position of whatever the prompt is attached to. Returns nil when the
-- parent has no position (e.g. a Folder), which callers must treat as "deny".
function PromptGuard.PromptPosition(prompt: any): any
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("Model") then
		local ok, pivot = pcall(function()
			return parent:GetPivot().Position
		end)
		if ok then return pivot end
	end
	return nil
end

-- True only if the player has a living character standing within the prompt's
-- own activation range (plus slack). Warns and denies when the prompt's parent
-- has no resolvable world position: the town/world geometry is live-edited in
-- Studio and is not in the Rojo tree, so an unexpected parent type can't be
-- caught from source, and a silent denial would read as a building that
-- mysteriously stopped working.
function PromptGuard.CanUse(player: any, prompt: any): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not hrp:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local target = PromptGuard.PromptPosition(prompt)
	if not target then
		warn("[PromptGuard] Cannot resolve a world position for prompt '"
			.. prompt.Name .. "' (parent: "
			.. (prompt.Parent and prompt.Parent.ClassName or "nil")
			.. ") — denying. Give it a BasePart/Attachment/Model parent.")
		return false
	end

	local maxDistance = prompt.MaxActivationDistance
	if maxDistance <= 0 then
		maxDistance = DEFAULT_DISTANCE
	end
	return (hrp.Position - target).Magnitude <= maxDistance + PromptGuard.DISTANCE_SLACK
end

return PromptGuard
