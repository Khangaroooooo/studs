-- ProfileSystem: every player character carries a ClickDetector, so
-- clicking any player (including yourself) sends the viewer a profile
-- snapshot of the target — name, equipped stud, dex/catch stats — which
-- ProfileUI renders with Trade / Battle buttons.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local profileEvent = StudEvents:FindFirstChild("ProfileData")
if not profileEvent then
	profileEvent = Instance.new("RemoteEvent")
	profileEvent.Name = "ProfileData"
	profileEvent.Parent = StudEvents
end

local function buildProfile(target)
	local profile = {
		userId = target.UserId,
		name = target.Name,
		displayName = target.DisplayName,
		coins = target:GetAttribute("Coins") or 0,
		totalCaught = target:GetAttribute("TotalCaught") or 0,
		uniqueCount = target:GetAttribute("UniqueCount") or 0,
		maxSpecies = #StudData.Studs,
		catchStreak = target:GetAttribute("CatchStreak") or 0,
	}

	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local targetInfo = activePlayers and activePlayers[target.UserId]
	if targetInfo and targetInfo.data then
		local data = targetInfo.data
		profile.shinyCount = data.shinyStuds and #data.shinyStuds or 0

		local equippedId = data.equippedStudId
		if equippedId then
			local stud = StudData.GetStudById(equippedId)
			if stud then
				-- Best copy: prefer shiny, then highest level (mirrors
				-- CompanionSystem so the profile matches the follower)
				local best = nil
				for _, entry in ipairs(data.caughtStuds) do
					if entry.id == equippedId then
						if not best
							or (entry.isShiny and not best.isShiny)
							or (entry.isShiny == best.isShiny and (entry.level or 1) > (best.level or 1))
						then
							best = entry
						end
					end
				end
				profile.equipped = {
					id = stud.id,
					name = stud.name,
					studType = stud.studType,
					rarity = stud.rarity,
					level = best and best.level or 1,
					isShiny = best and best.isShiny or false,
					nature = best and best.nature or nil,
				}
			end
		end
	end

	return profile
end

local function attachClickDetector(player, character)
	if character:FindFirstChild("ProfileClick") then return end

	-- Parented to the Model so clicking any body part opens the profile
	local click = Instance.new("ClickDetector")
	click.Name = "ProfileClick"
	click.MaxActivationDistance = 32
	click.Parent = character

	click.MouseClick:Connect(function(viewer)
		-- Self-clicks allowed: players can view their own profile
		profileEvent:FireClient(viewer, buildProfile(player))
	end)
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function(character)
		attachClickDetector(player, character)
	end)
	if player.Character then
		attachClickDetector(player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

print("[ProfileSystem] Initialized (click a player to view their profile)")
