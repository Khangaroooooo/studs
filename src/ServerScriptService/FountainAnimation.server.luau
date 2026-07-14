-- FountainAnimation: Gently rotates the golden Stud tile above the fountain
-- and animates the water glow

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local studville = Workspace:FindFirstChild("Studville")
if not studville then return end

local fountain = studville:FindFirstChild("Fountain")
if not fountain then return end

local studTile = fountain:FindFirstChild("FountainStud")
local spout = fountain:FindFirstChild("Spout")
local water = fountain:FindFirstChild("Water")

-- Rotate the golden Stud tile
if studTile then
	local baseY = studTile.Position.Y
	RunService.Heartbeat:Connect(function(dt)
		if not studTile or not studTile:IsDescendantOf(game) then return end
		local time = os.clock()
		-- Gentle rotation
		studTile.CFrame = CFrame.new(studTile.Position) * CFrame.Angles(0, time * 0.5, 0)
		-- Gentle bobbing
		local bob = math.sin(time * 1.5) * 0.3
		studTile.Position = Vector3.new(studTile.Position.X, baseY + bob, studTile.Position.Z)
	end)
end

-- Pulse the spout light
if spout then
	local spoutLight = spout:FindFirstChildOfClass("PointLight")
	if spoutLight then
		task.spawn(function()
			while spout:IsDescendantOf(game) do
				local pulse = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				local tween1 = TweenService:Create(spoutLight, pulse, {Brightness = 2.0})
				tween1:Play()
				tween1.Completed:Wait()
				local tween2 = TweenService:Create(spoutLight, pulse, {Brightness = 1.0})
				tween2:Play()
				tween2.Completed:Wait()
			end
		end)
	end
end

-- Pulse the water light
if water then
	local waterLight = water:FindFirstChildOfClass("PointLight")
	if waterLight then
		task.spawn(function()
			while water:IsDescendantOf(game) do
				local pulse = TweenInfo.new(3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				local tween1 = TweenService:Create(waterLight, pulse, {Brightness = 1.2})
				tween1:Play()
				tween1.Completed:Wait()
				local tween2 = TweenService:Create(waterLight, pulse, {Brightness = 0.5})
				tween2:Play()
				tween2.Completed:Wait()
			end
		end)
	end
end

print("[FountainAnimation] Initialized")