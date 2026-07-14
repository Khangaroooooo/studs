-- NPCAnimator: Gives NPCs idle animations (bobbing, looking around) to make the town feel alive

local TweenService = game:GetService("TweenService")
local studville = workspace:FindFirstChild("Studville")
if not studville then return end

local npcFolder = studville:FindFirstChild("NPCs")
if not npcFolder then return end

local function animateNPC(npc)
	if npc:IsA("Model") or npc:IsA("Folder") then
		local head = npc:FindFirstChild("Head")
		local torso = npc:FindFirstChild("Torso")

		if head and head:IsA("BasePart") then
			-- Gentle bobbing animation for the head
			task.spawn(function()
				local originalCFrame = head.CFrame
				while head and head.Parent do
					local bobUp = TweenService:Create(head, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						CFrame = originalCFrame * CFrame.new(0, 0.15, 0)
					})
					local bobDown = TweenService:Create(head, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						CFrame = originalCFrame
					})
					bobUp:Play()
					bobUp.Completed:Wait()
					bobDown:Play()
					bobDown.Completed:Wait()
				end
			end)

			-- Occasional look-around (rotate head slightly)
			task.spawn(function()
				local originalCFrame = head.CFrame
				while head and head.Parent do
					task.wait(math.random(4, 8))
					if not head or not head.Parent then break end
					local angle = math.random() > 0.5 and 0.15 or -0.15
					local lookAround = TweenService:Create(head, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = originalCFrame * CFrame.Angles(0, angle, 0)
					})
					lookAround:Play()
					lookAround.Completed:Wait()
					task.wait(math.random(2, 4))
					if not head or not head.Parent then break end
					local lookBack = TweenService:Create(head, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = originalCFrame
					})
					lookBack:Play()
					lookBack.Completed:Wait()
				end
			end)
		end

		-- Subtle torso sway for the body
		if torso and torso:IsA("BasePart") then
			task.spawn(function()
				local originalCFrame = torso.CFrame
				while torso and torso.Parent do
					task.wait(math.random(3, 7))
					if not torso or not torso.Parent then break end
					local swayAngle = (math.random() > 0.5 and 1 or -1) * 0.03
					local sway = TweenService:Create(torso, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						CFrame = originalCFrame * CFrame.Angles(0, swayAngle, 0)
					})
					sway:Play()
					sway.Completed:Wait()
					if not torso or not torso.Parent then break end
					local swayBack = TweenService:Create(torso, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
						CFrame = originalCFrame
					})
					swayBack:Play()
					swayBack.Completed:Wait()
				end
			end)
		end
	end
end

for _, npc in npcFolder:GetChildren() do
	animateNPC(npc)
end

-- Runtime-spawned NPCs (e.g. ShopNPC) animate too, regardless of which
-- server script happened to run first
npcFolder.ChildAdded:Connect(animateNPC)

print("[NPCAnimator] Initialized")