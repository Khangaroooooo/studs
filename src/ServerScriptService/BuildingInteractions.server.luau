-- BuildingInteractions: Handles ProximityPrompt interactions for town buildings
-- StudCenter: Shows stats and heals (resets encounter cooldown)
-- Shop: Opens shop UI
-- PlayerHouse: Rest at home

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")

local studville = workspace:FindFirstChild("Studville")
if not studville then return end

-- Healing cooldown tracker
local healCooldown = {}

-- SECURITY: ProximityPrompt.Triggered is client-driven. MaxActivationDistance,
-- RequiresLineOfSight and HoldDuration are all enforced on the CLIENT, so an
-- exploiter fires Triggered from anywhere on the map, at any rate, without ever
-- walking to the building. Every handler below must re-check proximity on the
-- server, exactly like a RemoteEvent — two of them hand out coins, and the
-- StudCenter/house heals otherwise let a player skip the trip back to town.
local PROMPT_DISTANCE_SLACK = 8 -- studs of tolerance for lag/character offset

-- World position of whatever the prompt is attached to (BasePart, Attachment,
-- or a Model via its pivot). Returns nil if it has no position.
local function promptPosition(prompt)
	local parent = prompt.Parent
	if not parent then return nil end
	if parent:IsA("BasePart") then
		return parent.Position
	elseif parent:IsA("Attachment") then
		return parent.WorldPosition
	elseif parent:IsA("Model") then
		local ok, pivot = pcall(function() return parent:GetPivot().Position end)
		if ok then return pivot end
	end
	return nil
end

-- True only if the player has a live character standing within the prompt's own
-- activation range (plus slack). Anything else is a forged or stale trigger.
local function canUsePrompt(player, prompt)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then return false end

	local target = promptPosition(prompt)
	if not target then
		-- The town geometry is live-edited in Studio and is not in the Rojo tree,
		-- so an unexpected parent type can't be caught from source. Deny (the
		-- safe direction) but say so loudly — otherwise this reads as a building
		-- that mysteriously stopped working.
		warn("[BuildingInteractions] Cannot resolve a world position for prompt '"
			.. prompt.Name .. "' (parent: " .. (prompt.Parent and prompt.Parent.ClassName or "nil")
			.. ") — denying the interaction. Give it a BasePart/Attachment/Model parent.")
		return false
	end

	local maxDistance = prompt.MaxActivationDistance
	if maxDistance <= 0 then maxDistance = 10 end
	return (hrp.Position - target).Magnitude <= maxDistance + PROMPT_DISTANCE_SLACK
end

-- Setup StudCenter interaction
local function setupStudCenter()
	local studCenter = studville:FindFirstChild("StudCenter")
	if not studCenter then return end

	local door = studCenter:FindFirstChild("Door")
	if not door then return end

	local prompt = door:FindFirstChild("StudCenterPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		-- Heal the player (reset encounter cooldown)
		local now = os.time()
		if healCooldown[player.UserId] and now - healCooldown[player.UserId] < 5 then
			return -- 5 second cooldown on healing
		end
		healCooldown[player.UserId] = now

		player:SetAttribute("LastHealTime", now)

		-- Notify client to show stats UI
		StudEvents.HealPlayer:FireClient(player)
	end)
end

-- Setup Shop interaction
local function setupShop()
	local shop = studville:FindFirstChild("Shop")
	if not shop then return end

	local door = shop:FindFirstChild("Door")
	if not door then return end

	local prompt = door:FindFirstChild("ShopPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		-- Tell client to open shop UI
		player:SetAttribute("OpenShop", true)
		task.delay(0.1, function()
			player:SetAttribute("OpenShop", nil)
		end)
	end)
end

-- Setup PlayerHouse interaction
local function setupPlayerHouse()
	local house = studville:FindFirstChild("PlayerHouse")
	if not house then return end

	local door = house:FindFirstChild("Door")
	if not door then return end

	local prompt = door:FindFirstChild("HousePrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		-- Rest at home - full heal and small coin bonus
		local now = os.time()
		if healCooldown[player.UserId] and now - healCooldown[player.UserId] < 10 then
			return
		end
		healCooldown[player.UserId] = now

		player:SetAttribute("LastHealTime", now)
		-- Small coin bonus for resting (5 coins)
		player:SetAttribute("HouseRestBonus", true)
		task.delay(0.1, function()
			player:SetAttribute("HouseRestBonus", nil)
		end)
	end)
end

-- Setup StudLab interaction
local function setupStudLab()
	local lab = studville:FindFirstChild("StudLab")
	if not lab then return end

	local displayCase = lab:FindFirstChild("StudDisplayCase")
	if not displayCase then return end

	local prompt = displayCase:FindFirstChild("LabPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		-- Tell client to show research/stud info
		player:SetAttribute("OpenLab", true)
		task.delay(0.1, function()
			player:SetAttribute("OpenLab", nil)
		end)
	end)
end

-- Setup Evolution Lab interaction
local function setupEvolutionLab()
	local lab = workspace:FindFirstChild("Studville") and workspace.Studville:FindFirstChild("StudLab")
	if not lab then return end

	local evoStation = lab:FindFirstChild("EvoStation") or lab:FindFirstChild("EvolutionStation")
	if not evoStation then
		-- Try to find any part in the Lab that could serve as the evo station
		for _, child in lab:GetChildren() do
			if child:IsA("BasePart") and (child.Name:lower():find("evo") or child.Name:lower():find("evolv")) then
				evoStation = child
				break
			end
		end
	end
	if not evoStation then return end

	local prompt = evoStation:FindFirstChild("EvoPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EvoPrompt"
		prompt.ActionText = "Evolve"
		prompt.ObjectText = "Evolution Lab"
		prompt.MaxActivationDistance = 8
		prompt.Parent = evoStation
	end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		player:SetAttribute("OpenEvolution", true)
	end)
end

setupEvolutionLab()

-- Setup Wishing Well interaction
local wellCooldown = {}

local function setupWishingWell()
	local wellBase = studville:FindFirstChild("WellBase")
	if not wellBase then return end

	local prompt = wellBase:FindFirstChild("WellPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		local now = os.time()
		if wellCooldown[player.UserId] and now - wellCooldown[player.UserId] < 60 then
			return -- 60 second cooldown on wishes
		end
		wellCooldown[player.UserId] = now

		-- Random wish outcome
		local roll = math.random(1, 100)
		if roll <= 3 then
			-- Jackpot! 100 coins
			player:SetAttribute("WishResult", "jackpot")
			task.delay(0.1, function()
				player:SetAttribute("WishResult", nil)
			end)
		elseif roll <= 10 then
			-- Lucky! 50 coins
			player:SetAttribute("WishResult", "lucky")
			task.delay(0.1, function()
				player:SetAttribute("WishResult", nil)
			end)
		elseif roll <= 30 then
			-- Nice! 25 coins
			player:SetAttribute("WishResult", "nice")
			task.delay(0.1, function()
				player:SetAttribute("WishResult", nil)
			end)
		elseif roll <= 60 then
			-- Small wish, 10 coins
			player:SetAttribute("WishResult", "small")
			task.delay(0.1, function()
				player:SetAttribute("WishResult", nil)
			end)
		else
			-- No luck this time
			player:SetAttribute("WishResult", "none")
			task.delay(0.1, function()
				player:SetAttribute("WishResult", nil)
			end)
		end
	end)
end

-- Setup Battle Arena interaction
local function setupBattleArena()
	local arena = studville:FindFirstChild("BattleArena")
	if not arena then return end

	local pad = arena:FindFirstChild("BattlePad")
	if not pad then return end

	local prompt = pad:FindFirstChild("BattlePrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if not canUsePrompt(player, prompt) then return end
		-- Tell client to open battle UI
		player:SetAttribute("OpenBattle", true)
		task.delay(0.1, function()
			player:SetAttribute("OpenBattle", nil)
		end)
	end)
end

-- Initialize all building interactions
setupStudCenter()
setupShop()
setupPlayerHouse()
setupStudLab()
setupWishingWell()
setupBattleArena()

print("[BuildingInteractions] Initialized")