-- FerrySystem: rowboat ferries between the main island and the outer islands
-- Boats live in workspace.TidepoolCove.Ferries. Each boat Model has:
--   HomePos (Vector3 attribute) - dock position at the main island
--   AwayPos (Vector3 attribute) - shore position at the destination island
-- Sitting on the boat's Seat starts the crossing; an empty boat left at the
-- far shore drifts back home after AUTO_RETURN seconds.

local TweenService = game:GetService("TweenService")

local SPEED = 45 -- studs per second
local DEPART_DELAY = 1.5 -- seconds after sitting before the boat departs
local AUTO_RETURN = 45 -- seconds an empty boat waits at the far shore

local cove = workspace:WaitForChild("TidepoolCove")
local ferries = cove:WaitForChild("Ferries")

local function setupFerry(boat)
	local hull = boat.PrimaryPart
	local seat = boat:FindFirstChildWhichIsA("Seat", true)
	local homePos = boat:GetAttribute("HomePos")
	local awayPos = boat:GetAttribute("AwayPos")
	if not (hull and seat and homePos and awayPos) then
		warn("FerrySystem: skipping misconfigured boat " .. boat.Name)
		return
	end

	local traveling = false
	local atHome = true
	local returnToken = 0

	local function sail(target)
		traveling = true
		local from = hull.Position
		local flat = Vector3.new(target.X, from.Y, target.Z)
		-- swing the bow toward the destination first
		local turn = TweenService:Create(hull, TweenInfo.new(0.6, Enum.EasingStyle.Sine), {
			CFrame = CFrame.lookAt(from, flat),
		})
		turn:Play()
		turn.Completed:Wait()
		local dist = (flat - from).Magnitude
		local cruise = TweenService:Create(hull, TweenInfo.new(dist / SPEED, Enum.EasingStyle.Sine), {
			CFrame = CFrame.lookAt(flat, flat + (flat - from)),
		})
		cruise:Play()
		cruise.Completed:Wait()
		traveling = false
	end

	local function scheduleReturn()
		returnToken += 1
		local token = returnToken
		task.delay(AUTO_RETURN, function()
			if token == returnToken and not seat.Occupant and not traveling and not atHome then
				sail(homePos)
				atHome = true
			end
		end)
	end

	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if not seat.Occupant or traveling then
			return
		end
		returnToken += 1
		task.delay(DEPART_DELAY, function()
			if not seat.Occupant or traveling then
				return
			end
			sail(atHome and awayPos or homePos)
			atHome = not atHome
			if not atHome then
				scheduleReturn()
			end
		end)
	end)
end

for _, boat in ferries:GetChildren() do
	if boat:IsA("Model") and boat.Name:match("^Ferry_") then
		setupFerry(boat)
	end
end
ferries.ChildAdded:Connect(function(child)
	if child:IsA("Model") and child.Name:match("^Ferry_") then
		setupFerry(child)
	end
end)
