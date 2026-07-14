-- TradeUI: invite popup + trade window for TradeSystem.
-- Two columns (your offer / their offer), a picker to add studs from your
-- collection, READY (lock) then CONFIRM once both sides are locked.
-- Any offer change on either side resets both locks (server-enforced).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UIManager = require(ReplicatedStorage:WaitForChild("UIManager"))

local tradeAction = StudEvents:WaitForChild("TradeAction", 30)
local tradeState = StudEvents:WaitForChild("TradeState", 30)
if not tradeAction or not tradeState then return end

local BG = Color3.fromRGB(25, 25, 35)
local HEADER = Color3.fromRGB(40, 40, 55)
local GOLD = Color3.fromRGB(255, 200, 50)
local TEXT = Color3.fromRGB(230, 230, 230)
local MUTED = Color3.fromRGB(150, 150, 170)
local GREEN = Color3.fromRGB(60, 160, 90)
local RED = Color3.fromRGB(190, 70, 60)
local SLOT_BG = Color3.fromRGB(35, 35, 48)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TradeUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- ─── INVITE POPUP ────────────────────────────────────────────────────────
local inviteFrame = Instance.new("Frame")
inviteFrame.Size = UDim2.new(0, 300, 0, 110)
inviteFrame.Position = UDim2.new(0.5, -150, 0, 90)
inviteFrame.BackgroundColor3 = BG
inviteFrame.BorderSizePixel = 0
inviteFrame.Visible = false
inviteFrame.Parent = screenGui

local invStroke = Instance.new("UIStroke")
invStroke.Color = GOLD
invStroke.Thickness = 2
invStroke.Parent = inviteFrame

local invLabel = Instance.new("TextLabel")
invLabel.Size = UDim2.new(1, -16, 0, 44)
invLabel.Position = UDim2.new(0, 8, 0, 8)
invLabel.BackgroundTransparency = 1
invLabel.TextColor3 = TEXT
invLabel.TextSize = 14
invLabel.Font = Enum.Font.GothamBold
invLabel.TextWrapped = true
invLabel.Parent = inviteFrame

local invAccept = Instance.new("TextButton")
invAccept.Size = UDim2.new(0.46, 0, 0, 36)
invAccept.Position = UDim2.new(0.03, 0, 1, -46)
invAccept.BackgroundColor3 = GREEN
invAccept.Text = "ACCEPT"
invAccept.TextColor3 = Color3.new(1, 1, 1)
invAccept.TextSize = 14
invAccept.Font = Enum.Font.GothamBold
invAccept.BorderSizePixel = 0
invAccept.Parent = inviteFrame

local invDecline = Instance.new("TextButton")
invDecline.Size = UDim2.new(0.46, 0, 0, 36)
invDecline.Position = UDim2.new(0.51, 0, 1, -46)
invDecline.BackgroundColor3 = RED
invDecline.Text = "DECLINE"
invDecline.TextColor3 = Color3.new(1, 1, 1)
invDecline.TextSize = 14
invDecline.Font = Enum.Font.GothamBold
invDecline.BorderSizePixel = 0
invDecline.Parent = inviteFrame

-- ─── TRADE WINDOW ────────────────────────────────────────────────────────
local win = Instance.new("Frame")
win.Size = UDim2.new(0, 520, 0, 400)
win.Position = UDim2.new(0.5, -260, 0.5, -200)
win.BackgroundColor3 = BG
win.BorderSizePixel = 0
win.Visible = false
win.Parent = screenGui

local winStroke = Instance.new("UIStroke")
winStroke.Color = Color3.fromRGB(80, 80, 100)
winStroke.Thickness = 2
winStroke.Parent = win

local winHeader = Instance.new("Frame")
winHeader.Size = UDim2.new(1, 0, 0, 42)
winHeader.BackgroundColor3 = HEADER
winHeader.BorderSizePixel = 0
winHeader.Parent = win

local winTitle = Instance.new("TextLabel")
winTitle.Size = UDim2.new(1, -20, 1, 0)
winTitle.Position = UDim2.new(0, 12, 0, 0)
winTitle.BackgroundTransparency = 1
winTitle.TextColor3 = GOLD
winTitle.TextSize = 16
winTitle.Font = Enum.Font.GothamBold
winTitle.TextXAlignment = Enum.TextXAlignment.Left
winTitle.Parent = winHeader

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -24, 0, 20)
statusLbl.Position = UDim2.new(0, 12, 0, 46)
statusLbl.BackgroundTransparency = 1
statusLbl.TextColor3 = MUTED
statusLbl.TextSize = 12
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.Parent = win

-- Offer columns
local function makeColumn(x, title)
	local colTitle = Instance.new("TextLabel")
	colTitle.Size = UDim2.new(0.46, 0, 0, 20)
	colTitle.Position = UDim2.new(x, 12, 0, 70)
	colTitle.BackgroundTransparency = 1
	colTitle.TextColor3 = TEXT
	colTitle.TextSize = 13
	colTitle.Font = Enum.Font.GothamBold
	colTitle.TextXAlignment = Enum.TextXAlignment.Left
	colTitle.Text = title
	colTitle.Parent = win

	local col = Instance.new("Frame")
	col.Size = UDim2.new(0.46, 0, 0, 176)
	col.Position = UDim2.new(x, 12, 0, 92)
	col.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	col.BorderSizePixel = 0
	col.Parent = win

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = col

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingLeft = UDim.new(0, 4)
	pad.PaddingRight = UDim.new(0, 4)
	pad.Parent = col

	return col, colTitle
end

local myCol, myColTitle = makeColumn(0, "YOUR OFFER")
local theirCol, theirColTitle = makeColumn(0.51, "THEIR OFFER")

local function fillColumn(col, offer, removable)
	for _, child in ipairs(col:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	for i, entry in ipairs(offer or {}) do
		local slot = Instance.new("Frame")
		slot.Size = UDim2.new(1, -8, 0, 38)
		slot.BackgroundColor3 = SLOT_BG
		slot.BorderSizePixel = 0
		slot.LayoutOrder = i
		slot.Parent = col

		local colorBar = Instance.new("Frame")
		colorBar.Size = UDim2.new(0, 5, 1, -6)
		colorBar.Position = UDim2.new(0, 3, 0, 3)
		local stud = StudData.GetStudById(entry.id)
		local color = stud and StudData.GetStudColor(stud) or MUTED
		if entry.isShiny then color = StudData.GetShinyColor(color) end
		colorBar.BackgroundColor3 = color
		colorBar.BorderSizePixel = 0
		colorBar.Parent = slot

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, removable and -46 or -16, 1, 0)
		lbl.Position = UDim2.new(0, 14, 0, 0)
		lbl.BackgroundTransparency = 1
		lbl.TextColor3 = TEXT
		lbl.TextSize = 12
		lbl.Font = Enum.Font.Gotham
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.TextTruncate = Enum.TextTruncate.AtEnd
		local natureName = entry.nature and StudData.GetNature(entry.nature).name or ""
		lbl.Text = (entry.isShiny and "✨" or "") .. (entry.name or entry.id)
			.. " Lv" .. (entry.level or 1) .. "  " .. (entry.rarity or "") .. " " .. natureName
		lbl.Parent = slot

		if removable then
			local removeBtn = Instance.new("TextButton")
			removeBtn.Size = UDim2.new(0, 28, 0, 28)
			removeBtn.Position = UDim2.new(1, -32, 0, 5)
			removeBtn.BackgroundColor3 = RED
			removeBtn.Text = "-"
			removeBtn.TextColor3 = Color3.new(1, 1, 1)
			removeBtn.TextSize = 16
			removeBtn.Font = Enum.Font.GothamBold
			removeBtn.BorderSizePixel = 0
			removeBtn.Parent = slot
			removeBtn.MouseButton1Click:Connect(function()
				tradeAction:FireServer("remove", i)
			end)
		end
	end
end

-- Bottom buttons
local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0, 110, 0, 36)
addBtn.Position = UDim2.new(0, 12, 1, -84)
addBtn.BackgroundColor3 = Color3.fromRGB(50, 80, 140)
addBtn.Text = "+ ADD STUD"
addBtn.TextColor3 = Color3.new(1, 1, 1)
addBtn.TextSize = 13
addBtn.Font = Enum.Font.GothamBold
addBtn.BorderSizePixel = 0
addBtn.Parent = win

local readyBtn = Instance.new("TextButton")
readyBtn.Size = UDim2.new(0, 110, 0, 36)
readyBtn.Position = UDim2.new(0, 130, 1, -84)
readyBtn.BackgroundColor3 = GOLD
readyBtn.Text = "READY"
readyBtn.TextColor3 = Color3.fromRGB(30, 30, 40)
readyBtn.TextSize = 13
readyBtn.Font = Enum.Font.GothamBold
readyBtn.BorderSizePixel = 0
readyBtn.Parent = win

local confirmBtn = Instance.new("TextButton")
confirmBtn.Size = UDim2.new(0, 130, 0, 36)
confirmBtn.Position = UDim2.new(0, 248, 1, -84)
confirmBtn.BackgroundColor3 = GREEN
confirmBtn.Text = "CONFIRM TRADE"
confirmBtn.TextColor3 = Color3.new(1, 1, 1)
confirmBtn.TextSize = 13
confirmBtn.Font = Enum.Font.GothamBold
confirmBtn.BorderSizePixel = 0
confirmBtn.Visible = false
confirmBtn.Parent = win

local cancelBtn = Instance.new("TextButton")
cancelBtn.Size = UDim2.new(0, 100, 0, 36)
cancelBtn.Position = UDim2.new(1, -112, 1, -84)
cancelBtn.BackgroundColor3 = RED
cancelBtn.Text = "CANCEL"
cancelBtn.TextColor3 = Color3.new(1, 1, 1)
cancelBtn.TextSize = 13
cancelBtn.Font = Enum.Font.GothamBold
cancelBtn.BorderSizePixel = 0
cancelBtn.Parent = win

local hintLbl = Instance.new("TextLabel")
hintLbl.Size = UDim2.new(1, -24, 0, 32)
hintLbl.Position = UDim2.new(0, 12, 1, -42)
hintLbl.BackgroundTransparency = 1
hintLbl.TextColor3 = MUTED
hintLbl.TextSize = 11
hintLbl.Font = Enum.Font.Gotham
hintLbl.TextWrapped = true
hintLbl.TextXAlignment = Enum.TextXAlignment.Left
hintLbl.Text = "Both players press READY, then CONFIRM. Changing an offer resets READY for both."
hintLbl.Parent = win

-- ─── STUD PICKER ─────────────────────────────────────────────────────────
local picker = Instance.new("Frame")
picker.Size = UDim2.new(0, 260, 0, 300)
picker.Position = UDim2.new(0.5, -130, 0.5, -150)
picker.BackgroundColor3 = BG
picker.BorderSizePixel = 0
picker.Visible = false
picker.ZIndex = 5
picker.Parent = screenGui

local pickerStroke = Instance.new("UIStroke")
pickerStroke.Color = GOLD
pickerStroke.Thickness = 2
pickerStroke.Parent = picker

local pickerTitle = Instance.new("TextLabel")
pickerTitle.Size = UDim2.new(1, -44, 0, 34)
pickerTitle.Position = UDim2.new(0, 10, 0, 0)
pickerTitle.BackgroundTransparency = 1
pickerTitle.TextColor3 = GOLD
pickerTitle.TextSize = 14
pickerTitle.Font = Enum.Font.GothamBold
pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
pickerTitle.Text = "Pick a stud to offer"
pickerTitle.ZIndex = 5
pickerTitle.Parent = picker

local pickerClose = Instance.new("TextButton")
pickerClose.Size = UDim2.new(0, 26, 0, 26)
pickerClose.Position = UDim2.new(1, -32, 0, 4)
pickerClose.BackgroundColor3 = RED
pickerClose.Text = "X"
pickerClose.TextColor3 = Color3.new(1, 1, 1)
pickerClose.TextSize = 13
pickerClose.Font = Enum.Font.GothamBold
pickerClose.BorderSizePixel = 0
pickerClose.ZIndex = 5
pickerClose.Parent = picker

local pickerScroll = Instance.new("ScrollingFrame")
pickerScroll.Size = UDim2.new(1, -12, 1, -42)
pickerScroll.Position = UDim2.new(0, 6, 0, 36)
pickerScroll.BackgroundTransparency = 1
pickerScroll.BorderSizePixel = 0
pickerScroll.ScrollBarThickness = 4
pickerScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
pickerScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
pickerScroll.ZIndex = 5
pickerScroll.Parent = picker

local pickerLayout = Instance.new("UIListLayout")
pickerLayout.Padding = UDim.new(0, 3)
pickerLayout.SortOrder = Enum.SortOrder.LayoutOrder
pickerLayout.Parent = pickerScroll

local function openPicker()
	for _, child in ipairs(pickerScroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local ok, collection = pcall(function()
		return StudEvents.RequestCollection:InvokeServer()
	end)
	if not ok or type(collection) ~= "table" then return end

	for i, entry in ipairs(collection) do
		local stud = StudData.GetStudById(entry.id)
		if stud then
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(1, -8, 0, 32)
			btn.BackgroundColor3 = SLOT_BG
			btn.TextColor3 = TEXT
			btn.TextSize = 12
			btn.Font = Enum.Font.Gotham
			btn.TextXAlignment = Enum.TextXAlignment.Left
			btn.BorderSizePixel = 0
			btn.LayoutOrder = i
			btn.ZIndex = 5
			local natureName = entry.nature and StudData.GetNature(entry.nature).name or ""
			btn.Text = "  " .. (entry.isShiny and "✨" or "") .. stud.name
				.. " Lv" .. (entry.level or 1) .. "  " .. stud.rarity .. " " .. natureName
			btn.Parent = pickerScroll

			btn.MouseButton1Click:Connect(function()
				tradeAction:FireServer("add", {
					id = entry.id,
					caughtAt = entry.caughtAt,
					level = entry.level or 1,
					isShiny = entry.isShiny or false,
					nature = entry.nature or "hardy",
				})
				picker.Visible = false
			end)
		end
	end
	picker.Visible = true
end

pickerClose.MouseButton1Click:Connect(function()
	picker.Visible = false
end)

-- ─── STATE HANDLING ──────────────────────────────────────────────────────
local inviteFromUserId = nil
local myLocked = false

local function closeAll()
	win.Visible = false
	picker.Visible = false
	inviteFrame.Visible = false
end

invAccept.MouseButton1Click:Connect(function()
	inviteFrame.Visible = false
	tradeAction:FireServer("accept")
end)
invDecline.MouseButton1Click:Connect(function()
	inviteFrame.Visible = false
	tradeAction:FireServer("decline")
end)

addBtn.MouseButton1Click:Connect(openPicker)
readyBtn.MouseButton1Click:Connect(function()
	tradeAction:FireServer(myLocked and "unlock" or "lock")
end)
confirmBtn.MouseButton1Click:Connect(function()
	tradeAction:FireServer("confirm")
end)
cancelBtn.MouseButton1Click:Connect(function()
	tradeAction:FireServer("cancel")
	closeAll()
end)

tradeState.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end

	if data.action == "invite" then
		inviteFromUserId = data.fromUserId
		invLabel.Text = "🔄 " .. (data.fromName or "Someone") .. " wants to trade with you!"
		inviteFrame.Visible = true
		task.delay(40, function()
			if inviteFromUserId == data.fromUserId then
				inviteFrame.Visible = false
			end
		end)

	elseif data.action == "invite_sent" then
		UIManager.Call("Notify", "info", "Trade request sent", "Waiting for " .. (data.toName or "them") .. "...")

	elseif data.action == "declined" then
		UIManager.Call("Notify", "fail", "Trade declined", (data.byName or "They") .. " declined your request.")

	elseif data.action == "started" then
		winTitle.Text = "🔄 Trading with " .. (data.partnerName or "?")
		myColTitle.Text = "YOUR OFFER"
		theirColTitle.Text = (data.partnerName or "THEIR"):upper() .. "'S OFFER"
		statusLbl.Text = "Add studs to your offer."
		fillColumn(myCol, {}, true)
		fillColumn(theirCol, {}, false)
		myLocked = false
		readyBtn.Text = "READY"
		confirmBtn.Visible = false
		win.Visible = true

	elseif data.action == "state" then
		myLocked = data.myLocked
		fillColumn(myCol, data.myOffer, not myLocked)
		fillColumn(theirCol, data.theirOffer, false)
		readyBtn.Text = myLocked and "UNREADY" or "READY"
		addBtn.Visible = not myLocked
		confirmBtn.Visible = data.myLocked and data.theirLocked and not data.myConfirmed
		if data.myConfirmed and not data.theirConfirmed then
			statusLbl.Text = "Waiting for partner to confirm..."
		elseif data.myLocked and data.theirLocked then
			statusLbl.Text = "Both ready! Press CONFIRM to complete the trade."
		elseif data.myLocked then
			statusLbl.Text = "Waiting for partner to be ready..."
		elseif data.theirLocked then
			statusLbl.Text = "Partner is ready. Press READY when your offer is final."
		else
			statusLbl.Text = "Add studs to your offer."
		end

	elseif data.action == "ended" then
		closeAll()
		if data.reason == "completed" then
			UIManager.Call("Notify", "success", "Trade complete!", "Check your inventory.")
		elseif data.reason == "cancelled" then
			UIManager.Call("Notify", "info", "Trade cancelled", "")
		elseif data.reason == "partner_left" then
			UIManager.Call("Notify", "fail", "Trade ended", "Your partner left the game.")
		end

	elseif data.action == "error" then
		UIManager.Call("Notify", "warning", "Trade", data.message or "Something went wrong.")
	end
end)

print("[TradeUI] Initialized")
