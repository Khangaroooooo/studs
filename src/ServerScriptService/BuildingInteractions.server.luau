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

-- Setup StudCenter interaction
local function setupStudCenter()
	local studCenter = studville:FindFirstChild("StudCenter")
	if not studCenter then return end

	local door = studCenter:FindFirstChild("Door")
	if not door then return end

	local prompt = door:FindFirstChild("StudCenterPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
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