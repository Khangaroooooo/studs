-- PvPUI: challenge popup + duel window for PvPSystem.
-- Two stud cards with HP bars, a turn banner with countdown, move buttons
-- (your stud's 3 moves + Defend + Forfeit), and a battle log.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local pvpAction = StudEvents:WaitForChild("PvPAction", 30)
local pvpState = StudEvents:WaitForChild("PvPState", 30)
if not pvpAction or not pvpState then return end

local BG = Color3.fromRGB(25, 25, 35)
local HEADER = Color3.fromRGB(40, 40, 55)
local GOLD = Color3.fromRGB(255, 200, 50)
local TEXT = Color3.fromRGB(230, 230, 230)
local MUTED = Color3.fromRGB(150, 150, 170)
local GREEN = Color3.fromRGB(60, 160, 90)
local RED = Color3.fromRGB(190, 70, 60)
local HP_HI = Color3.fromRGB(72, 210, 110)
local HP_MID = Color3.fromRGB(255, 199, 68)
local HP_LO = Color3.fromRGB(235, 78, 64)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PvPUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ─── CHALLENGE POPUP ─────────────────────────────────────────────────────
local challengeFrame = Instance.new("Frame")
challengeFrame.Size = UDim2.new(0, 300, 0, 110)
challengeFrame.Position = UDim2.new(0.5, -150, 0, 90)
challengeFrame.BackgroundColor3 = BG
challengeFrame.BorderSizePixel = 0
challengeFrame.Visible = false
challengeFrame.Parent = screenGui

local chStroke = Instance.new("UIStroke")
chStroke.Color = RED
chStroke.Thickness = 2
chStroke.Parent = challengeFrame

local chLabel = Instance.new("TextLabel")
chLabel.Size = UDim2.new(1, -16, 0, 44)
chLabel.Position = UDim2.new(0, 8, 0, 8)
chLabel.BackgroundTransparency = 1
chLabel.TextColor3 = TEXT
chLabel.TextSize = 14
chLabel.Font = Enum.Font.GothamBold
chLabel.TextWrapped = true
chLabel.Parent = challengeFrame

local chAccept = Instance.new("TextButton")
chAccept.Size = UDim2.new(0.46, 0, 0, 36)
chAccept.Position = UDim2.new(0.03, 0, 1, -46)
chAccept.BackgroundColor3 = GREEN
chAccept.Text = "ACCEPT"
chAccept.TextColor3 = Color3.new(1, 1, 1)
chAccept.TextSize = 14
chAccept.Font = Enum.Font.GothamBold
chAccept.BorderSizePixel = 0
chAccept.Parent = challengeFrame

local chDecline = Instance.new("TextButton")
chDecline.Size = UDim2.new(0.46, 0, 0, 36)
chDecline.Position = UDim2.new(0.51, 0, 1, -46)
chDecline.BackgroundColor3 = RED
chDecline.Text = "DECLINE"
chDecline.TextColor3 = Color3.new(1, 1, 1)
chDecline.TextSize = 14
chDecline.Font = Enum.Font.GothamBold
chDecline.BorderSizePixel = 0
chDecline.Parent = challengeFrame

-- ─── DUEL WINDOW ─────────────────────────────────────────────────────────
local win = Instance.new("Frame")
win.Size = UDim2.new(0, 560, 0, 420)
win.Position = UDim2.new(0.5, -280, 0.5, -210)
win.BackgroundColor3 = BG
win.BorderSizePixel = 0
win.Visible = false
win.Parent = screenGui

local winStroke = Instance.new("UIStroke")
winStroke.Color = Color3.fromRGB(80, 80, 100)
winStroke.Thickness = 2
winStroke.Parent = win

local turnBanner = Instance.new("TextLabel")
turnBanner.Size = UDim2.new(1, 0, 0, 40)
turnBanner.BackgroundColor3 = HEADER
turnBanner.BorderSizePixel = 0
turnBanner.TextColor3 = GOLD
turnBanner.TextSize = 16
turnBanner.Font = Enum.Font.GothamBold
turnBanner.Text = "⚔️ DUEL"
turnBanner.Parent = win

-- Stud card factory (mine left, theirs right)
local function makeCard(x)
	local card = Instance.new("Frame")
	card.Size = UDim2.new(0.46, 0, 0, 120)
	card.Position = UDim2.new(x, 12, 0, 52)
	card.BackgroundColor3 = Color3.fromRGB(35, 35, 48)
	card.BorderSizePixel = 0
	card.Parent = win

	local owner = Instance.new("TextLabel")
	owner.Size = UDim2.new(1, -16, 0, 18)
	owner.Position = UDim2.new(0, 8, 0, 4)
	owner.BackgroundTransparency = 1
	owner.TextColor3 = MUTED
	owner.TextSize = 11
	owner.Font = Enum.Font.Gotham
	owner.TextXAlignment = Enum.TextXAlignment.Left
	owner.Parent = card

	local swatch = Instance.new("Frame")
	swatch.Size = UDim2.new(0, 42, 0, 42)
	swatch.Position = UDim2.new(0, 8, 0, 26)
	swatch.BorderSizePixel = 0
	swatch.Parent = card

	local sStroke = Instance.new("UIStroke")
	sStroke.Color = Color3.fromRGB(10, 8, 14)
	sStroke.Thickness = 2
	sStroke.Parent = swatch

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -66, 0, 20)
	name.Position = UDim2.new(0, 58, 0, 26)
	name.BackgroundTransparency = 1
	name.TextColor3 = TEXT
	name.TextSize = 14
	name.Font = Enum.Font.GothamBold
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Parent = card

	local meta = Instance.new("TextLabel")
	meta.Size = UDim2.new(1, -66, 0, 16)
	meta.Position = UDim2.new(0, 58, 0, 46)
	meta.BackgroundTransparency = 1
	meta.TextColor3 = MUTED
	meta.TextSize = 11
	meta.Font = Enum.Font.Gotham
	meta.TextXAlignment = Enum.TextXAlignment.Left
	meta.Parent = card

	local hpBg = Instance.new("Frame")
	hpBg.Size = UDim2.new(1, -16, 0, 16)
	hpBg.Position = UDim2.new(0, 8, 0, 78)
	hpBg.BackgroundColor3 = Color3.fromRGB(15, 17, 25)
	hpBg.BorderSizePixel = 0
	hpBg.Parent = card

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.new(1, 0, 1, 0)
	hpFill.BackgroundColor3 = HP_HI
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBg

	local hpText = Instance.new("TextLabel")
	hpText.Size = UDim2.new(1, 0, 0, 14)
	hpText.Position = UDim2.new(0, 0, 0, 98)
	hpText.BackgroundTransparency = 1
	hpText.TextColor3 = MUTED
	hpText.TextSize = 11
	hpText.Font = Enum.Font.RobotoMono
	hpText.Parent = card

	return { card = card, owner = owner, swatch = swatch, name = name, meta = meta, hpFill = hpFill, hpText = hpText }
end

local myCard = makeCard(0)
local theirCard = makeCard(0.51)

local function updateCard(card, side)
	card.owner.Text = side.playerName or "?"
	local stud = StudData.GetStudById(side.id)
	local color = stud and StudData.GetStudColor(stud) or MUTED
	if side.isShiny then color = StudData.GetShinyColor(color) end
	card.swatch.BackgroundColor3 = color
	card.name.Text = (side.isShiny and "✨" or "") .. (side.name or "?") .. " Lv" .. (side.level or 1)
	local natureName = side.nature and StudData.GetNature(side.nature).name or ""
	card.meta.Text = (side.studType or "?") .. " · " .. (side.rarity or "?") .. (natureName ~= "" and (" · " .. natureName) or "")
	local ratio = math.clamp((side.hp or 0) / math.max(side.maxHP or 1, 1), 0, 1)
	card.hpFill.Size = UDim2.new(ratio, 0, 1, 0)
	card.hpFill.BackgroundColor3 = ratio > 0.5 and HP_HI or (ratio > 0.25 and HP_MID or HP_LO)
	card.hpText.Text = (side.hp or 0) .. " / " .. (side.maxHP or 0) .. " HP"
end

-- Battle log
local logFrame = Instance.new("Frame")
logFrame.Size = UDim2.new(1, -24, 0, 96)
logFrame.Position = UDim2.new(0, 12, 0, 184)
logFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
logFrame.BorderSizePixel = 0
logFrame.Parent = win

local logLabels = {}
for i = 1, 4 do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -12, 0, 20)
	lbl.Position = UDim2.new(0, 6, 0, (i - 1) * 22 + 4)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = i == 4 and TEXT or MUTED
	lbl.TextSize = 12
	lbl.Font = Enum.Font.RobotoMono
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextTruncate = Enum.TextTruncate.AtEnd
	lbl.Text = ""
	lbl.Parent = logFrame
	logLabels[i] = lbl
end

local logLines = {}
local function addLog(msg)
	table.insert(logLines, msg)
	while #logLines > 4 do
		table.remove(logLines, 1)
	end
	for i = 1, 4 do
		logLabels[i].Text = logLines[i] or ""
	end
end

-- Action buttons: 3 moves + defend + forfeit
local actionFrame = Instance.new("Frame")
actionFrame.Size = UDim2.new(1, -24, 0, 116)
actionFrame.Position = UDim2.new(0, 12, 1, -128)
actionFrame.BackgroundTransparency = 1
actionFrame.Parent = win

local moveButtons = {}
local moveLocked = { false, false, false, false } -- per-slot: locked by level
for i = 1, 4 do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.235, 0, 0, 50)
	btn.Position = UDim2.new((i - 1) * 0.255, 0, 0, 0)
	btn.BackgroundColor3 = Color3.fromRGB(50, 80, 140)
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextSize = 12
	btn.Font = Enum.Font.GothamBold
	btn.TextWrapped = true
	btn.BorderSizePixel = 0
	btn.Text = "Move " .. i
	btn.Parent = actionFrame
	btn.MouseButton1Click:Connect(function()
		if moveLocked[i] then return end
		pvpAction:FireServer("move", "Attack", i)
	end)
	moveButtons[i] = btn
end

local defendBtn = Instance.new("TextButton")
defendBtn.Size = UDim2.new(0.49, 0, 0, 44)
defendBtn.Position = UDim2.new(0, 0, 0, 58)
defendBtn.BackgroundColor3 = Color3.fromRGB(70, 110, 90)
defendBtn.Text = "🛡️ DEFEND"
defendBtn.TextColor3 = Color3.new(1, 1, 1)
defendBtn.TextSize = 14
defendBtn.Font = Enum.Font.GothamBold
defendBtn.BorderSizePixel = 0
defendBtn.Parent = actionFrame
defendBtn.MouseButton1Click:Connect(function()
	pvpAction:FireServer("move", "Defend")
end)

local forfeitBtn = Instance.new("TextButton")
forfeitBtn.Size = UDim2.new(0.49, 0, 0, 44)
forfeitBtn.Position = UDim2.new(0.51, 0, 0, 58)
forfeitBtn.BackgroundColor3 = RED
forfeitBtn.Text = "🏳️ FORFEIT"
forfeitBtn.TextColor3 = Color3.new(1, 1, 1)
forfeitBtn.TextSize = 14
forfeitBtn.Font = Enum.Font.GothamBold
forfeitBtn.BorderSizePixel = 0
forfeitBtn.Parent = actionFrame
forfeitBtn.MouseButton1Click:Connect(function()
	pvpAction:FireServer("forfeit")
end)

local function setActionsEnabled(enabled)
	for i, btn in ipairs(moveButtons) do
		local usable = enabled and not moveLocked[i]
		btn.AutoButtonColor = usable
		btn.BackgroundColor3 = usable and Color3.fromRGB(50, 80, 140) or Color3.fromRGB(35, 40, 55)
	end
	defendBtn.AutoButtonColor = enabled
	defendBtn.BackgroundColor3 = enabled and Color3.fromRGB(70, 110, 90) or Color3.fromRGB(35, 45, 42)
end

local function updateMoveButtons(side, level)
	-- side = the `me` payload table ({id, studType, ...}) → per-species kit
	local moves = StudData.GetMoves(side or "Fire")
	for i = 1, 4 do
		local move = moves[i]
		if move and StudData.IsMoveUnlocked(move, level or 1) then
			moveLocked[i] = false
			-- Accuracy shown so the heavy moves' whiff risk is visible
			local accText = move.accuracy and (" " .. math.floor(move.accuracy * 100 + 0.5) .. "%") or ""
			moveButtons[i].Text = move.name .. "\nx" .. move.power .. accText
		elseif move then
			-- Locked until unlockLevel (server enforces this too)
			moveLocked[i] = true
			moveButtons[i].Text = move.name .. "\n🔒 Lv" .. move.unlockLevel
		else
			moveLocked[i] = true
			moveButtons[i].Text = "-"
		end
	end
end

-- Turn countdown
local turnToken = 0
local function startTurnCountdown(myTurn, seconds)
	turnToken += 1
	local token = turnToken
	task.spawn(function()
		local remaining = seconds
		while remaining > 0 and turnToken == token and win.Visible do
			turnBanner.Text = myTurn
				and ("⚔️ YOUR TURN — " .. remaining .. "s")
				or ("⏳ Opponent's turn — " .. remaining .. "s")
			turnBanner.TextColor3 = myTurn and GOLD or MUTED
			task.wait(1)
			remaining -= 1
		end
	end)
end

pvpState.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end

	if data.action == "challenge" then
		chLabel.Text = "⚔️ " .. (data.fromName or "Someone") .. " challenges you to a duel!"
		challengeFrame.Visible = true
		task.delay(40, function()
			challengeFrame.Visible = false
		end)

	elseif data.action == "challenge_sent" then
		UIManager.Call("Notify", "info", "Challenge sent", "Waiting for " .. (data.toName or "them") .. "...")

	elseif data.action == "declined" then
		UIManager.Call("Notify", "fail", "Challenge declined", (data.byName or "They") .. " declined your duel.")

	elseif data.action == "started" or data.action == "state" then
		if data.action == "started" then
			logLines = {}
			for i = 1, 4 do logLabels[i].Text = "" end
			win.Visible = true
			challengeFrame.Visible = false
		end
		updateCard(myCard, data.me)
		updateCard(theirCard, data.them)
		updateMoveButtons(data.me, data.me.level)
		setActionsEnabled(data.myTurn)
		startTurnCountdown(data.myTurn, data.turnTime or 30)
		if data.log then
			for _, msg in ipairs(data.log) do
				addLog(msg)
			end
		end

	elseif data.action == "ended" then
		if data.me and data.them then
			updateCard(myCard, data.me)
			updateCard(theirCard, data.them)
		end
		if data.log then
			for _, msg in ipairs(data.log) do
				addLog(msg)
			end
		end
		turnToken += 1
		setActionsEnabled(false)
		if data.result == "win" then
			turnBanner.Text = "🏆 VICTORY! +30 coins"
			turnBanner.TextColor3 = GOLD
		elseif data.result == "lose" then
			turnBanner.Text = "💀 DEFEAT"
			turnBanner.TextColor3 = RED
		else
			turnBanner.Text = "🤝 DRAW"
			turnBanner.TextColor3 = MUTED
		end
		task.delay(3.5, function()
			win.Visible = false
		end)

	elseif data.action == "error" then
		UIManager.Call("Notify", "warning", "Duel", data.message or "Something went wrong.")
	end
end)

chAccept.MouseButton1Click:Connect(function()
	challengeFrame.Visible = false
	pvpAction:FireServer("accept")
end)
chDecline.MouseButton1Click:Connect(function()
	challengeFrame.Visible = false
	pvpAction:FireServer("decline")
end)

print("[PvPUI] Initialized")
