-- StoryUI: client surface for the "Seven Ways Home" story mode.
-- Renders StorySystem's beats as quiet margin-note cards (bottom-left,
-- typewriter, click to skip/dismiss, queued so beats never overlap) and
-- the one modal moment of the whole story: The Last Page ending choice.
--
-- Everything here is skippable and unobtrusive by design — the story is
-- ambient, the catch loop is king. Casual mode (StoryMode attribute off)
-- renders nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local StudEvents = ReplicatedStorage:WaitForChild("StudEvents")
local StoryData = require(ReplicatedStorage:WaitForChild("StoryData"))
local StudData = require(ReplicatedStorage:WaitForChild("StudData"))
local UITheme = require(ReplicatedStorage:WaitForChild("UITheme"))

local storyBeatEvent = StudEvents:WaitForChild("StoryBeat")
local storyChoiceEvent = StudEvents:WaitForChild("StoryChoice")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StoryUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 40
screenGui.Parent = playerGui

-- ─── PAYLOAD → CARD CONTENT ────────────────────────────────────────────
-- Server sends { kind, ... }; all text lives in StoryData.

local function resolvePayload(payload)
	if type(payload) ~= "table" then return nil end

	if payload.kind == "beat" then
		local beat = StoryData.Beats[payload.id]
		if not beat then return nil end
		return { header = beat.speaker, lines = beat.lines }
	elseif payload.kind == "chapter" then
		local chapter = StoryData.Chapters[payload.world]
		if not chapter then return nil end
		return {
			header = "Ch. " .. chapter.chapter .. " — " .. chapter.title,
			lines = chapter.intro,
			isChapter = true,
		}
	elseif payload.kind == "legend" then
		local aside = StoryData.DexAsides[payload.studId]
		if not aside then return nil end
		local stud = StudData.GetStudById(payload.studId)
		local name = stud and stud.name or payload.studId
		return { header = name .. " — remembered", lines = { aside } }
	elseif payload.kind == "way" then
		local lines = StoryData.WayBeats[payload.index]
		if not lines then return nil end
		local header = StoryData.SPEAKER_REGISTRY
		if payload.caught and payload.caught >= 2 then
			header = "One of Bryan's ways (" .. payload.caught .. " of " .. #StoryData.BryanWays .. ")"
		end
		return { header = header, lines = lines, slow = payload.index == 6 }
	elseif payload.kind == "ending_epilogue" then
		local ending = StoryData.Ending.choices[payload.choice]
		if not ending then return nil end
		local lines = table.clone(ending.epilogue)
		table.insert(lines, StoryData.Ending.closingLine)
		return { header = "The Last Page", lines = lines, slow = true, isChapter = true }
	end
	return nil -- ending_offer handled separately
end

-- ─── MARGIN-NOTE CARD (queued, typewriter) ─────────────────────────────

local noteQueue = {}
local showingNote = false

local function showNote(content)
	local card = Instance.new("TextButton") -- clickable: skip typing, then dismiss
	card.Name = "MarginNote"
	card.AutoButtonColor = false
	card.Text = ""
	card.Size = UDim2.new(0, 420, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 24, 1, -36)
	card.BackgroundColor3 = UITheme.C_PANEL
	card.BackgroundTransparency = 0.08
	card.BorderSizePixel = 0
	card.Parent = screenGui
	UITheme.ApplyStroke(card, content.isChapter and UITheme.C_ACCENT or UITheme.C_BORDER, 2)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent = card

	-- Stack children with a layout: absolutely-positioned children under an
	-- AutomaticSize parent can feedback-loop the parent's height
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = card

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 0)
	header.AutomaticSize = Enum.AutomaticSize.Y
	header.BackgroundTransparency = 1
	header.Text = content.header or ""
	header.TextColor3 = UITheme.C_ACCENT
	header.Font = UITheme.F_PIXEL
	header.TextSize = content.isChapter and 18 or 14
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextWrapped = true
	header.LayoutOrder = 1
	header.Parent = card

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Text = table.concat(content.lines, "\n\n")
	body.TextColor3 = UITheme.C_WHITE
	body.Font = UITheme.F_BODY
	body.TextSize = 15
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.MaxVisibleGraphemes = 0
	body.LayoutOrder = 2
	body.Parent = card

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, 0, 0, 12)
	hint.BackgroundTransparency = 1
	hint.Text = "click to continue"
	hint.TextColor3 = UITheme.C_SEC
	hint.TextTransparency = 0.4
	hint.Font = UITheme.F_BODY
	hint.TextSize = 11
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.LayoutOrder = 3
	hint.Parent = card

	-- Typewriter reveal; a click reveals everything, a second click closes
	local graphemes = utf8.len(body.Text) or #body.Text
	local perChar = content.slow and 0.035 or 0.022
	local revealed = false
	local dismissed = false

	card.MouseButton1Click:Connect(function()
		if not revealed then
			revealed = true
		else
			dismissed = true
		end
	end)

	for i = 1, graphemes do
		if revealed or dismissed then break end
		body.MaxVisibleGraphemes = i
		task.wait(perChar)
	end
	body.MaxVisibleGraphemes = -1
	revealed = true

	-- Hold long enough to read (or until clicked)
	local holdTime = math.clamp(2 + graphemes * 0.045, 4, 14)
	local elapsed = 0
	while elapsed < holdTime and not dismissed do
		elapsed += task.wait(0.1)
	end

	local fade = TweenService:Create(card, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
	TweenService:Create(body, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(header, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(hint, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	fade:Play()
	fade.Completed:Wait()
	card:Destroy()
end

local function pumpQueue()
	if showingNote then return end
	showingNote = true
	task.spawn(function()
		while #noteQueue > 0 do
			local content = table.remove(noteQueue, 1)
			showNote(content)
			task.wait(0.6) -- breathing room between stacked beats
		end
		showingNote = false
	end)
end

-- ─── THE LAST PAGE (ending choice — the story's one modal moment) ──────

local endingOpen = false

local function showEndingOffer()
	if endingOpen then return end
	endingOpen = true

	local dim = Instance.new("Frame")
	dim.Name = "EndingDim"
	dim.Size = UDim2.new(1, 0, 1, 0)
	dim.BackgroundColor3 = Color3.new(0, 0, 0)
	dim.BackgroundTransparency = 0.35
	dim.BorderSizePixel = 0
	dim.ZIndex = 50
	dim.Parent = screenGui

	local panel = Instance.new("Frame")
	panel.Name = "EndingPanel"
	panel.Size = UDim2.new(0, 520, 0, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.new(0.5, 0, 0.5, 0)
	panel.BackgroundColor3 = UITheme.C_PANEL
	panel.BorderSizePixel = 0
	panel.ZIndex = 51
	panel.Parent = dim
	UITheme.ApplyStroke(panel, UITheme.C_ACCENT, 3)

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 18)
	pad.PaddingBottom = UDim.new(0, 18)
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 26)
	title.BackgroundTransparency = 1
	title.Text = StoryData.Ending.offerTitle:upper()
	title.TextColor3 = UITheme.C_ACCENT
	title.Font = UITheme.F_PIXEL
	title.TextSize = 24
	title.LayoutOrder = 1
	title.ZIndex = 52
	title.Parent = panel

	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.BackgroundTransparency = 1
	body.Text = table.concat(StoryData.Ending.offerLines, "\n\n")
	body.TextColor3 = UITheme.C_WHITE
	body.Font = UITheme.F_BODY
	body.TextSize = 15
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.LayoutOrder = 2
	body.ZIndex = 52
	body.Parent = panel

	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, 0, 0, 76)
	buttonRow.BackgroundTransparency = 1
	buttonRow.LayoutOrder = 3
	buttonRow.ZIndex = 52
	buttonRow.Parent = panel

	local function makeChoice(choiceId, side)
		local choice = StoryData.Ending.choices[choiceId]
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(0.5, -6, 1, 0)
		btn.Position = side == "left" and UDim2.new(0, 0, 0, 0) or UDim2.new(0.5, 6, 0, 0)
		btn.BackgroundColor3 = UITheme.C_BG
		btn.BorderSizePixel = 0
		btn.Text = ""
		btn.AutoButtonColor = false
		btn.ZIndex = 53
		btn.Parent = buttonRow
		local stroke = UITheme.ApplyStroke(btn, UITheme.C_BORDER, 2)

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -12, 0, 24)
		label.Position = UDim2.new(0, 6, 0, 8)
		label.BackgroundTransparency = 1
		label.Text = choice.label
		label.TextColor3 = UITheme.C_ACCENT
		label.Font = UITheme.F_PIXEL
		label.TextSize = 16
		label.ZIndex = 54
		label.Parent = btn

		local blurb = Instance.new("TextLabel")
		blurb.Size = UDim2.new(1, -12, 0, 36)
		blurb.Position = UDim2.new(0, 6, 0, 34)
		blurb.BackgroundTransparency = 1
		blurb.Text = choice.blurb
		blurb.TextColor3 = UITheme.C_SEC
		blurb.Font = UITheme.F_BODY
		blurb.TextSize = 12
		blurb.TextWrapped = true
		blurb.TextYAlignment = Enum.TextYAlignment.Top
		blurb.ZIndex = 54
		blurb.Parent = btn

		btn.MouseEnter:Connect(function()
			stroke.Color = UITheme.C_ACCENT
		end)
		btn.MouseLeave:Connect(function()
			stroke.Color = UITheme.C_BORDER
		end)
		btn.MouseButton1Click:Connect(function()
			storyChoiceEvent:FireServer(choiceId)
			endingOpen = false
			dim:Destroy()
		end)
	end

	makeChoice("rest", "left")
	makeChoice("alive", "right")

	-- Never forced: the server re-offers on Duskwood entry / next session
	local later = Instance.new("TextButton")
	later.Size = UDim2.new(1, 0, 0, 22)
	later.BackgroundTransparency = 1
	later.Text = "not yet — the page can wait"
	later.TextColor3 = UITheme.C_SEC
	later.Font = UITheme.F_BODY
	later.TextSize = 13
	later.LayoutOrder = 4
	later.ZIndex = 52
	later.Parent = panel
	later.MouseButton1Click:Connect(function()
		endingOpen = false
		dim:Destroy()
	end)
end

-- ─── WIRING ────────────────────────────────────────────────────────────

storyBeatEvent.OnClientEvent:Connect(function(payload)
	if player:GetAttribute("StoryMode") == false then return end

	if type(payload) == "table" and payload.kind == "ending_offer" then
		showEndingOffer()
		return
	end

	local content = resolvePayload(payload)
	if content then
		table.insert(noteQueue, content)
		pumpQueue()
	end
end)

-- Switching to Casual mid-note: clear anything queued (the visible card
-- finishes on its own; it's already skippable)
player:GetAttributeChangedSignal("StoryMode"):Connect(function()
	if player:GetAttribute("StoryMode") == false then
		table.clear(noteQueue)
	end
end)

print("[StoryUI] Initialized")
