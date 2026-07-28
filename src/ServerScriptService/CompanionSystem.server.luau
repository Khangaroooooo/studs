-- CompanionSystem: the player's equipped Stud follows them around the
-- overworld as a floating, bobbing block with a name tag. Server-side so
-- every player sees everyone's companion (shinies included — that's the
-- point: shiny hunting becomes visible and social).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local ServerRegistry = require(ReplicatedStorage:WaitForChild("ServerRegistry"))

local companions = {} -- [userId] = { part, label, userId }

local companionFolder = Instance.new("Folder")
companionFolder.Name = "Companions"
companionFolder.Parent = workspace

-- Best copy of the equipped species: prefer shiny, then highest level
local function getEquippedEntry(player)
	local activePlayers = ServerRegistry.Get("ActivePlayers")
	local playerInfo = activePlayers and activePlayers[player.UserId]
	if not playerInfo or not playerInfo.data then return nil end
	local equippedId = playerInfo.data.equippedStudId
	if not equippedId then return nil end

	local best = nil
	for _, entry in ipairs(playerInfo.data.caughtStuds) do
		if entry.id == equippedId then
			if not best
				or (entry.isShiny and not best.isShiny)
				or (entry.isShiny == best.isShiny and (entry.level or 1) > (best.level or 1))
			then
				best = entry
			end
		end
	end
	return best
end

local function destroyCompanion(userId)
	local comp = companions[userId]
	if comp then
		companions[userId] = nil
		if comp.part then
			comp.part:Destroy()
		end
	end
end

local function refreshCompanion(player)
	local entry = getEquippedEntry(player)
	if not entry then
		destroyCompanion(player.UserId)
		return
	end
	local stud = StudData.GetStudById(entry.id)
	if not stud then
		destroyCompanion(player.UserId)
		return
	end

	local comp = companions[player.UserId]
	if not comp then
		local part = Instance.new("Part")
		part.Name = "Companion_" .. player.UserId
		part.Size = Vector3.new(1.6, 1.6, 1.6)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth

		local billboard = Instance.new("BillboardGui")
		billboard.Name = "NameTag"
		billboard.Size = UDim2.new(0, 120, 0, 22)
		billboard.StudsOffset = Vector3.new(0, 1.6, 0)
		billboard.AlwaysOnTop = false
		billboard.MaxDistance = 60
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Arcade
		label.TextSize = 12
		label.TextStrokeTransparency = 0.4
		label.Parent = billboard

		part.Parent = companionFolder
		comp = { part = part, label = label, userId = player.UserId, bobPhase = math.random() * math.pi * 2 }
		companions[player.UserId] = comp
	end

	local baseColor = StudData.GetStudColor(stud)
	if entry.isShiny then
		comp.part.Color = StudData.GetShinyColor(baseColor)
		comp.part.Material = Enum.Material.Neon
		comp.label.TextColor3 = StudData.ShinyColor
		comp.label.Text = "✨ " .. stud.name .. " Lv" .. (entry.level or 1)
	else
		comp.part.Color = baseColor
		comp.part.Material = stud.rarity == "Legendary" and Enum.Material.Neon or Enum.Material.SmoothPlastic
		comp.label.TextColor3 = Color3.fromRGB(255, 250, 235)
		comp.label.Text = stud.name .. " Lv" .. (entry.level or 1)
	end
end

-- Follow loop: hover behind-right of the owner with a gentle bob.
-- Anchored CFrame updates replicate smoothly enough at this cadence and
-- avoid all physics/network-ownership headaches.
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for userId, comp in pairs(companions) do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp then
			local bob = math.sin(now * 2 + comp.bobPhase) * 0.35
			local target = hrp.CFrame * CFrame.new(2.2, 1.5 + bob, 2.2)
			-- Lerp for smooth trailing motion
			comp.part.CFrame = comp.part.CFrame:Lerp(
				CFrame.new(target.Position, target.Position + hrp.CFrame.LookVector),
				0.15
			)
		end
	end
end)

local function watchPlayer(player)
	-- EquippedStud attribute changes whenever SaveManager syncs (equip, load,
	-- new game, sell, evolve, trade), so it's the perfect refresh signal
	player:GetAttributeChangedSignal("EquippedStud"):Connect(function()
		refreshCompanion(player)
	end)
	-- StudCount changes catch evolve/trade level changes on the same species
	player:GetAttributeChangedSignal("StudCount"):Connect(function()
		refreshCompanion(player)
	end)
	player.CharacterAdded:Connect(function(character)
		-- Snap the companion to the fresh spawn so it doesn't fly across the map
		task.wait(0.5)
		local comp = companions[player.UserId]
		local hrp = character:FindFirstChild("HumanoidRootPart")
		if comp and hrp then
			comp.part.CFrame = hrp.CFrame * CFrame.new(2.2, 1.5, 2.2)
		end
	end)
	refreshCompanion(player)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
	watchPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	destroyCompanion(player.UserId)
end)

print("[CompanionSystem] Initialized")
