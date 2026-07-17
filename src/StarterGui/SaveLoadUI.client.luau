-- SaveLoadUI: Minimal black screen with Load / New buttons
-- Load → scrollable list of saves (date/time)
-- New → create a new save and enter the game

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player     = Players.LocalPlayer
local playerGui   = player:WaitForChild("PlayerGui")
local StudEvents  = ReplicatedStorage:WaitForChild("StudEvents")

-- GUARD: Prevent duplicate UI when ForceR6 reloads the character
local existingUI = playerGui:FindFirstChild("SaveLoadUI")
if existingUI and existingUI:IsA("ScreenGui") then
	return
end

-- Hide the top bar so the UI covers the full screen
task.spawn(function()
	task.wait(0.5)
	pcall(function()
		game:GetService("StarterGui"):SetCore("TopbarEnabled", false)
	end)
end)

-- ─── COLORS ────────────────────────────────────────────────────────────
local C_BLACK    = Color3.new(0, 0, 0)
local C_BTN     = Color3.fromRGB(35, 35, 35)
local C_BTN_HOV = Color3.fromRGB(55, 55, 55)
local C_BORDER  = Color3.fromRGB(80, 80, 80)
local C_BORDER_HOV = Color3.fromRGB(160, 160, 160)
local C_WHITE   = Color3.fromRGB(255, 255, 255)
local C_DIM     = Color3.fromRGB(120, 120, 120)
local C_RED     = Color3.fromRGB(180, 50, 50)
local C_RED_HOV = Color3.fromRGB(220, 70, 70)

-- ─── BUILD UI ──────────────────────────────────────────────────────────

local screenGui = Instance.new("ScreenGui")
screenGui.Name             = "SaveLoadUI"
screenGui.ResetOnSpawn     = false
screenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset   = true
screenGui.Parent           = playerGui

-- Full black background
local bg = Instance.new("Frame")
bg.Name             = "Background"
bg.Size             = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = C_BLACK
bg.BorderSizePixel  = 0
bg.Parent           = screenGui

-- Centered container
local container = Instance.new("Frame")
container.Name             = "Container"
container.Size             = UDim2.new(0, 400, 0, 400)
container.Position         = UDim2.new(0.5, -200, 0.5, -200)
container.BackgroundTransparency = 1
container.ClipsDescendants = true
container.Parent           = bg

-- ─── MAIN VIEW (Load / New) ────────────────────────────────────────────

local mainView = Instance.new("Frame")
mainView.Name             = "MainView"
mainView.Size             = UDim2.new(1, 0, 1, 0)
mainView.BackgroundTransparency = 1
mainView.Visible          = true
mainView.Parent           = container

local mainLayout = Instance.new("UIListLayout")
mainLayout.Padding              = UDim.new(0, 20)
mainLayout.HorizontalAlignment   = Enum.HorizontalAlignment.Center
mainLayout.VerticalAlignment     = Enum.VerticalAlignment.Center
mainLayout.FillDirection    = Enum.FillDirection.Horizontal
mainLayout.SortOrder            = Enum.SortOrder.LayoutOrder
mainLayout.Parent               = mainView

-- Load button
local loadBtn = Instance.new("TextButton")
loadBtn.Name             = "LoadBtn"
loadBtn.Size             = UDim2.new(0.5, -10, 0, 54)
loadBtn.BackgroundColor3 = C_BTN
loadBtn.BorderSizePixel  = 1
loadBtn.BorderColor3     = C_BORDER
loadBtn.Text             = "LOAD"
loadBtn.TextColor3       = C_WHITE
loadBtn.Font             = Enum.Font.RobotoMono
loadBtn.TextSize         = 26
loadBtn.LayoutOrder      = 2
loadBtn.AutoButtonColor  = false
loadBtn.Parent           = mainView

-- New button
local newBtn = Instance.new("TextButton")
newBtn.Name             = "NewBtn"
newBtn.Size             = UDim2.new(0.5, -10, 0, 54)
newBtn.BackgroundColor3 = C_BTN
newBtn.BorderSizePixel  = 1
newBtn.BorderColor3     = C_BORDER
newBtn.Text             = "NEW"
newBtn.TextColor3       = C_WHITE
newBtn.Font             = Enum.Font.RobotoMono
newBtn.TextSize         = 26
newBtn.LayoutOrder      = 1
newBtn.AutoButtonColor  = false
newBtn.Parent           = mainView

-- ─── SAVE LIST VIEW ────────────────────────────────────────────────────

local saveListView = Instance.new("Frame")
saveListView.Name             = "SaveListView"
saveListView.Size             = UDim2.new(1, 0, 1, 0)
saveListView.BackgroundTransparency = 1
saveListView.Visible          = false
saveListView.ClipsDescendants = true
saveListView.Parent           = container

-- Back button
local backBtn = Instance.new("TextButton")
backBtn.Name             = "BackBtn"
backBtn.Size             = UDim2.new(1, 0, 0, 40)
backBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
backBtn.BorderSizePixel  = 0
backBtn.Text             = "< BACK"
backBtn.TextColor3       = C_DIM
backBtn.Font             = Enum.Font.RobotoMono
backBtn.TextSize         = 18
backBtn.AutoButtonColor  = false
backBtn.Parent           = saveListView

-- Separator
local sep = Instance.new("Frame")
sep.Name             = "Separator"
sep.Size             = UDim2.new(1, 0, 0, 1)
sep.Position         = UDim2.new(0, 0, 0, 40)
sep.BackgroundColor3 = C_BORDER
sep.BorderSizePixel  = 0
sep.Parent           = saveListView

-- Scrolling frame for save entries
local saveScroll = Instance.new("ScrollingFrame")
saveScroll.Name                = "SaveScroll"
saveScroll.Size                = UDim2.new(1, 0, 1, -41)
saveScroll.Position            = UDim2.new(0, 0, 0, 41)
saveScroll.BackgroundTransparency = 1
saveScroll.BorderSizePixel     = 0
saveScroll.ScrollBarThickness  = 4
saveScroll.ScrollBarImageColor3  = C_BORDER
saveScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
saveScroll.CanvasSize         = UDim2.new(0, 0, 0, 0)
saveScroll.Parent              = saveListView

local saveListLayout = Instance.new("UIListLayout")
saveListLayout.Padding     = UDim.new(0, 6)
saveListLayout.SortOrder  = Enum.SortOrder.LayoutOrder
saveListLayout.Parent     = saveScroll

-- No saves label
local noSavesLabel = Instance.new("TextLabel")
noSavesLabel.Name               = "NoSaves"
noSavesLabel.Size               = UDim2.new(1, 0, 0, 60)
noSavesLabel.BackgroundTransparency = 1
noSavesLabel.Text               = "No saves found"
noSavesLabel.TextColor3         = C_DIM
noSavesLabel.Font               = Enum.Font.RobotoMono
noSavesLabel.TextSize           = 16
noSavesLabel.Visible            = false
noSavesLabel.Parent             = saveListView

-- ─── MODE SELECT (New Game → Story / Casual) ───────────────────────────
-- Pressing NEW morphs the two buttons into STORY / CASUAL. Story surfaces
-- the ambient narration ("Seven Ways Home"); Casual is the pure collector
-- loop. Same game either way, switchable later in Settings.

local modeCaption = Instance.new("TextLabel")
modeCaption.Name             = "ModeCaption"
modeCaption.Size             = UDim2.new(1, 0, 0, 30)
modeCaption.Position         = UDim2.new(0, 0, 0.5, -85)
modeCaption.BackgroundTransparency = 1
modeCaption.Text             = "HOW WILL YOU PLAY?"
modeCaption.TextColor3       = C_WHITE
modeCaption.Font             = Enum.Font.RobotoMono
modeCaption.TextSize         = 20
modeCaption.Visible          = false
modeCaption.Parent           = container

local modeHint = Instance.new("TextLabel")
modeHint.Name             = "ModeHint"
modeHint.Size             = UDim2.new(1, 0, 0, 36)
modeHint.Position         = UDim2.new(0, 0, 0.5, 45)
modeHint.BackgroundTransparency = 1
modeHint.Text             = "STORY — the town remembers you\nCASUAL — pure collecting, no narration"
modeHint.TextColor3       = C_DIM
modeHint.Font             = Enum.Font.RobotoMono
modeHint.TextSize         = 13
modeHint.Visible          = false
modeHint.Parent           = container

local modeBackBtn = Instance.new("TextButton")
modeBackBtn.Name             = "ModeBackBtn"
modeBackBtn.Size             = UDim2.new(0, 120, 0, 28)
modeBackBtn.Position         = UDim2.new(0.5, -60, 0.5, 95)
modeBackBtn.BackgroundTransparency = 1
modeBackBtn.Text             = "< BACK"
modeBackBtn.TextColor3       = C_DIM
modeBackBtn.Font             = Enum.Font.RobotoMono
modeBackBtn.TextSize         = 16
modeBackBtn.Visible          = false
modeBackBtn.Parent           = container

-- ─── ERROR LABEL (max slots, etc.) ─────────────────────────────────────

local errorLabel = Instance.new("TextLabel")
errorLabel.Name               = "ErrorLabel"
errorLabel.Size               = UDim2.new(1, 0, 0, 30)
errorLabel.BackgroundTransparency = 1
errorLabel.Text               = ""
errorLabel.TextColor3         = C_RED
errorLabel.Font               = Enum.Font.RobotoMono
errorLabel.TextSize           = 14
errorLabel.Visible            = false
errorLabel.LayoutOrder        = 3
errorLabel.Parent             = mainView

-- ─── HELPERS ────────────────────────────────────────────────────────────

local function formatTimestamp(ts)
	if not ts or ts == 0 then return "Unknown" end
	local d = os.date("!*t", ts)
	return string.format("%04d/%02d/%02d  %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
end

local function clearSaveEntries()
	for _, child in ipairs(saveScroll:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
end

local closeDropdown  -- forward declaration (used by showMainView, defined below)

local function showMainView()
	saveListView.Visible = false
	mainView.Visible = true
	errorLabel.Visible = false
	closeDropdown()
end

-- ─── DROPDOWN & RENAME HELPERS ──────────────────────────────────────────

local openDropdown = nil
local openDropdownEntry = nil

closeDropdown = function()
	if openDropdown then
		openDropdown:Destroy()
		openDropdown = nil
		openDropdownEntry = nil
	end
end

-- Close dropdown when scrolling
saveScroll:GetPropertyChangedSignal("CanvasPosition"):Connect(closeDropdown)

local startInlineRename  -- forward declaration (defined below)
local currentSlots = {}  -- tracks the currently displayed save slots

local function refreshDisplayNames()
	local untitledCount = 0
	for _, slot in ipairs(currentSlots) do
		if not slot.name or slot.name == "" then
			untitledCount = untitledCount + 1
			slot._displayName = "Untitled " .. untitledCount
		else
			slot._displayName = slot.name
		end
	end

	for _, child in ipairs(saveScroll:GetChildren()) do
		if child:IsA("Frame") then
			local loadArea = child:FindFirstChild("LoadArea")
			if loadArea then
				local info = loadArea:FindFirstChild("Info")
				if info then
					local slotId = tonumber(string.match(child.Name, "SaveEntry_(%d+)"))
					if slotId then
						for _, slot in ipairs(currentSlots) do
							if slot.slotId == slotId then
								info.Text = (slot._displayName or "Untitled") .. "\nLast Saved: " .. formatTimestamp(slot.lastSaved)
								break
							end
						end
					end
				end
			end
		end
	end
end

local function toggleDropdown(entry, slot, dotsBtn)
	if openDropdownEntry == entry then
		closeDropdown()
		return
	end
	closeDropdown()

	local btnPos = dotsBtn.AbsolutePosition
	local btnSize = dotsBtn.AbsoluteSize

	-- Semi-transparent background to catch outside clicks
	local bgBtn = Instance.new("TextButton")
	bgBtn.Name = "DropdownBg"
	bgBtn.Size = UDim2.new(1, 0, 1, 0)
	bgBtn.BackgroundColor3 = C_BLACK
	bgBtn.BackgroundTransparency = 0.6
	bgBtn.BorderSizePixel = 0
	bgBtn.Text = ""
	bgBtn.ZIndex = 10
	bgBtn.AutoButtonColor = false
	bgBtn.Parent = screenGui

	-- Dropdown frame
	local dropdown = Instance.new("Frame")
	dropdown.Name = "Dropdown"
	dropdown.Size = UDim2.new(0, 120, 0, 72)
	dropdown.Position = UDim2.new(0, btnPos.X - 120 + btnSize.X, 0, btnPos.Y + btnSize.Y + 4)
	dropdown.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	dropdown.BorderSizePixel = 1
	dropdown.BorderColor3 = Color3.fromRGB(60, 60, 60)
	dropdown.ZIndex = 11
	dropdown.Parent = bgBtn

	local dropLayout = Instance.new("UIListLayout")
	dropLayout.SortOrder = Enum.SortOrder.LayoutOrder
	dropLayout.Parent = dropdown

	-- Rename option
	local renameOpt = Instance.new("TextButton")
	renameOpt.Name = "RenameOpt"
	renameOpt.Size = UDim2.new(1, 0, 0, 36)
	renameOpt.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	renameOpt.BorderSizePixel = 0
	renameOpt.Text = "Rename"
	renameOpt.TextColor3 = C_WHITE
	renameOpt.Font = Enum.Font.RobotoMono
	renameOpt.TextSize = 14
	renameOpt.AutoButtonColor = false
	renameOpt.LayoutOrder = 1
	renameOpt.ZIndex = 12
	renameOpt.Parent = dropdown

	-- Delete option
	local deleteOpt = Instance.new("TextButton")
	deleteOpt.Name = "DeleteOpt"
	deleteOpt.Size = UDim2.new(1, 0, 0, 36)
	deleteOpt.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
	deleteOpt.BorderSizePixel = 0
	deleteOpt.Text = "Delete"
	deleteOpt.TextColor3 = C_RED
	deleteOpt.Font = Enum.Font.RobotoMono
	deleteOpt.TextSize = 14
	deleteOpt.AutoButtonColor = false
	deleteOpt.LayoutOrder = 2
	deleteOpt.ZIndex = 12
	deleteOpt.Parent = dropdown

	-- Hover effects for options
	for _, opt in { renameOpt, deleteOpt } do
		opt.MouseEnter:Connect(function()
			TweenService:Create(opt, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(55, 55, 55),
			}):Play()
		end)
		opt.MouseLeave:Connect(function()
			TweenService:Create(opt, TweenInfo.new(0.1), {
				BackgroundColor3 = Color3.fromRGB(40, 40, 40),
			}):Play()
		end)
	end

	-- Delete hover (red tint)
	deleteOpt.MouseEnter:Connect(function()
		TweenService:Create(deleteOpt, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(80, 25, 25),
		}):Play()
	end)
	deleteOpt.MouseLeave:Connect(function()
		TweenService:Create(deleteOpt, TweenInfo.new(0.1), {
			BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		}):Play()
	end)

	-- Click handlers
	renameOpt.MouseButton1Click:Connect(function()
		closeDropdown()
		startInlineRename(slot, entry)
	end)

	deleteOpt.MouseButton1Click:Connect(function()
		closeDropdown()
		StudEvents.DeleteSaveSlot:FireServer(slot.slotId)
		local tween = TweenService:Create(entry, TweenInfo.new(0.2), {
			Size = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 1,
		})
		tween:Play()
		tween.Completed:Connect(function()
			entry:Destroy()
			local hasEntries = false
			for _, child in ipairs(saveScroll:GetChildren()) do
				if child:IsA("Frame") then
					hasEntries = true
					break
				end
			end
			if not hasEntries then
				noSavesLabel.Visible = true
				saveScroll.Visible = false
			end
		end)
	end)

	bgBtn.MouseButton1Click:Connect(function()
		closeDropdown()
	end)

	openDropdown = bgBtn
	openDropdownEntry = entry
end

startInlineRename = function(slot, entry)
	local loadArea = entry:FindFirstChild("LoadArea")
	if not loadArea then return end
	local infoLabel = loadArea:FindFirstChild("Info")
	if not infoLabel then return end

	-- Mark this entry as being renamed so loadArea clicks are suppressed
	entry:SetAttribute("IsRenaming", true)
	infoLabel.Visible = false
	-- Hide the loadArea button entirely so it can't intercept clicks meant for the TextBox
	loadArea.Visible = false

	-- Inline TextBox replacing the name portion of the Info label
	-- Parent to entry (not loadArea) so the TextBox can properly receive focus and input
	local nameBox = Instance.new("TextBox")
	nameBox.Name = "InlineRenameBox"
	nameBox.Size = UDim2.new(1, -48, 0, 56)
	nameBox.Position = UDim2.new(0, 12, 0, 4)
	nameBox.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	nameBox.BorderSizePixel = 1
	nameBox.BorderColor3 = C_BORDER_HOV
	nameBox.Text = slot.name or ""
	nameBox.PlaceholderText = "Enter name..."
	nameBox.PlaceholderColor3 = C_DIM
	nameBox.TextColor3 = C_WHITE
	nameBox.Font = Enum.Font.RobotoMono
	nameBox.TextSize = 13
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ClearTextOnFocus = false
	nameBox.TextTruncate = Enum.TextTruncate.AtEnd
	nameBox.ZIndex = 5
	nameBox.Parent = entry

	local finished = false
	local function finishRename()
		if finished then return end
		finished = true
		local newName = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
		if #newName > 20 then
			newName = string.sub(newName, 1, 20)
		end
		StudEvents.RenameSaveSlot:FireServer(slot.slotId, #newName > 0 and newName or nil)
		slot.name = #newName > 0 and newName or nil
		refreshDisplayNames()
		nameBox:Destroy()
		infoLabel.Visible = true
		loadArea.Visible = true
		-- Delay clearing the flag so any click that triggered FocusLost is suppressed
		task.delay(0.2, function()
			entry:SetAttribute("IsRenaming", false)
		end)
	end

	nameBox.FocusLost:Connect(function(enterPressed)
		finishRename()
	end)

	-- Auto-focus the TextBox and place cursor at end
	-- Use task.spawn + task.wait to give the UI time to settle after dropdown close
	task.spawn(function()
		task.wait(0.15)
		if not nameBox.Parent then return end
		nameBox:CaptureFocus()
		if slot.name then
			nameBox.CursorPosition = #slot.name + 1
		end
	end)
end

-- Warns when the server is running on in-memory saves (Studio without API
-- access): everything works in-session, but nothing survives a restart.
local persistNotice = Instance.new("TextLabel")
persistNotice.Name = "PersistNotice"
persistNotice.Size = UDim2.new(1, 0, 0, 30)
persistNotice.Position = UDim2.new(0, 0, 1, -30)
persistNotice.BackgroundColor3 = Color3.fromRGB(90, 60, 20)
persistNotice.BorderSizePixel = 0
persistNotice.TextColor3 = Color3.fromRGB(255, 210, 130)
persistNotice.Font = Enum.Font.Gotham
persistNotice.TextSize = 11
persistNotice.TextWrapped = true
persistNotice.Text = "Studio memory mode: saves won't survive restarting playtest. Enable Game Settings > Security > Studio API Services."
persistNotice.Visible = false
persistNotice.Parent = saveListView

local function showSaveListView()
	mainView.Visible = false
	saveListView.Visible = true
	persistNotice.Visible = ReplicatedStorage:GetAttribute("SavesPersist") == false

	clearSaveEntries()

	-- Request save slots from server
	local slots = StudEvents.RequestSaveSlots:InvokeServer()

	if not slots or #slots == 0 then
		currentSlots = {}
		noSavesLabel.Visible = true
		saveScroll.Visible = false
	else
		currentSlots = slots
		-- Compute display names: unnamed saves get "Untitled 1", "Untitled 2", etc.
		local untitledCount = 0
		for _, slot in ipairs(slots) do
			if not slot.name or slot.name == "" then
				untitledCount = untitledCount + 1
				slot._displayName = "Untitled " .. untitledCount
			else
				slot._displayName = slot.name
			end
		end

		noSavesLabel.Visible = false
		saveScroll.Visible = true

		for i, slot in ipairs(slots) do
			local entry = Instance.new("Frame")
			entry.Name             = "SaveEntry_" .. slot.slotId
			entry.Size             = UDim2.new(1, 0, 0, 64)
			entry.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			entry.BorderSizePixel  = 1
			entry.BorderColor3     = Color3.fromRGB(50, 50, 50)
			entry.LayoutOrder      = i
			entry.Parent           = saveScroll

			-- Clickable area to load this save
			local loadArea = Instance.new("TextButton")
			loadArea.Name             = "LoadArea"
			loadArea.Size             = UDim2.new(1, -36, 1, 0)
			loadArea.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			loadArea.BorderSizePixel  = 0
			loadArea.Text             = ""
			loadArea.AutoButtonColor  = false
			loadArea.Parent           = entry

			-- Save info (two lines)
			local infoLabel = Instance.new("TextLabel")
			infoLabel.Name               = "Info"
			infoLabel.Size               = UDim2.new(1, -16, 1, 0)
			infoLabel.Position           = UDim2.new(0, 12, 0, 0)
			infoLabel.BackgroundTransparency = 1
			infoLabel.Text           = (slot._displayName or "Untitled") .. "\nLast Saved: " .. formatTimestamp(slot.lastSaved)
			infoLabel.TextColor3         = C_WHITE
			infoLabel.Font               = Enum.Font.RobotoMono
			infoLabel.TextSize           = 13
			infoLabel.TextXAlignment     = Enum.TextXAlignment.Left
			infoLabel.Parent             = loadArea

			-- Three-dot menu button (top right)
			local dotsBtn = Instance.new("TextButton")
			dotsBtn.Name             = "DotsBtn"
			dotsBtn.Size             = UDim2.new(0, 28, 0, 28)
			dotsBtn.Position         = UDim2.new(1, -32, 0, 4)
			dotsBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
			dotsBtn.BorderSizePixel  = 0
			dotsBtn.Text             = "..."
			dotsBtn.TextColor3       = C_WHITE
			dotsBtn.Font             = Enum.Font.RobotoMono
			dotsBtn.TextSize         = 20
			dotsBtn.AutoButtonColor  = false
			dotsBtn.Parent           = entry

			-- Hover effects for load area
			loadArea.MouseEnter:Connect(function()
				TweenService:Create(loadArea, TweenInfo.new(0.12), {
					BackgroundColor3 = Color3.fromRGB(45, 45, 45),
				}):Play()
				TweenService:Create(entry, TweenInfo.new(0.12), {
					BorderColor3 = C_BORDER_HOV,
				}):Play()
			end)
			loadArea.MouseLeave:Connect(function()
				TweenService:Create(loadArea, TweenInfo.new(0.12), {
					BackgroundColor3 = Color3.fromRGB(28, 28, 28),
				}):Play()
				TweenService:Create(entry, TweenInfo.new(0.12), {
					BorderColor3 = Color3.fromRGB(50, 50, 50),
				}):Play()
			end)

			-- Hover effects for dots button
			dotsBtn.MouseEnter:Connect(function()
				TweenService:Create(dotsBtn, TweenInfo.new(0.12), {
					BackgroundColor3 = Color3.fromRGB(50, 50, 50),
					TextColor3 = C_WHITE,
				}):Play()
			end)
			dotsBtn.MouseLeave:Connect(function()
				TweenService:Create(dotsBtn, TweenInfo.new(0.12), {
					BackgroundColor3 = Color3.fromRGB(28, 28, 28),
					TextColor3 = C_WHITE,
				}):Play()
			end)

			-- Click load area → load this save (guarded during inline rename)
			loadArea.MouseButton1Click:Connect(function()
				if entry:GetAttribute("IsRenaming") then return end
				StudEvents.LoadGame:FireServer(slot.slotId)
				transitionOut()
			end)

			-- Click dots → open dropdown menu
			dotsBtn.MouseButton1Click:Connect(function()
				toggleDropdown(entry, slot, dotsBtn)
			end)
		end
	end
end

-- ─── TRANSITION OUT ───────────────────────────────────────────────────

function transitionOut()
	-- Fade to solid black, then destroy UI and enable topbar
	local fade = Instance.new("Frame")
	fade.Name             = "Fade"
	fade.Size             = UDim2.new(1, 0, 1, 0)
	fade.BackgroundColor3 = C_BLACK
	fade.BackgroundTransparency = 1
	fade.ZIndex           = 100
	fade.Parent           = screenGui

	local tween = TweenService:Create(fade, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		BackgroundTransparency = 0,
	})
	tween:Play()
	tween.Completed:Wait()

	task.wait(0.1)

	pcall(function()
		game:GetService("StarterGui"):SetCore("TopbarEnabled", true)
	end)
	screenGui:Destroy()
end

-- ─── BUTTON HANDLERS ──────────────────────────────────────────────────

-- Mode-select state: after NEW is pressed, the same two buttons become
-- STORY (left, was NEW) and CASUAL (right, was LOAD)
local chooseMode = false

local function setModeSelect(active)
	chooseMode = active
	newBtn.Text = active and "STORY" or "NEW"
	loadBtn.Text = active and "CASUAL" or "LOAD"
	modeCaption.Visible = active
	modeHint.Visible = active
	modeBackBtn.Visible = active
end

local function startNewGame(mode)
	StudEvents.NewGame:FireServer(mode)
	transitionOut()
end

loadBtn.MouseButton1Click:Connect(function()
	if chooseMode then
		startNewGame("casual")
		return
	end
	showSaveListView()
end)

newBtn.MouseButton1Click:Connect(function()
	if chooseMode then
		startNewGame("story")
		return
	end

	-- Check slot count first
	local slots = StudEvents.RequestSaveSlots:InvokeServer()
	if slots and #slots >= 10 then
		errorLabel.Text = "Max saves reached (10). Delete one first."
		errorLabel.Visible = true
		task.wait(3)
		if errorLabel.Visible then
			errorLabel.Visible = false
		end
		return
	end

	setModeSelect(true)
end)

modeBackBtn.MouseButton1Click:Connect(function()
	setModeSelect(false)
end)

modeBackBtn.MouseEnter:Connect(function()
	modeBackBtn.TextColor3 = C_WHITE
end)
modeBackBtn.MouseLeave:Connect(function()
	modeBackBtn.TextColor3 = C_DIM
end)

backBtn.MouseButton1Click:Connect(function()
	showMainView()
end)

-- ─── HOVER EFFECTS ────────────────────────────────────────────────────

for _, btn in { loadBtn, newBtn } do
	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = C_BTN_HOV,
			BorderColor3 = C_BORDER_HOV,
		}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {
			BackgroundColor3 = C_BTN,
			BorderColor3 = C_BORDER,
		}):Play()
	end)
end

backBtn.MouseEnter:Connect(function()
	TweenService:Create(backBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(40, 40, 40),
		TextColor3 = C_WHITE,
	}):Play()
end)
backBtn.MouseLeave:Connect(function()
	TweenService:Create(backBtn, TweenInfo.new(0.12), {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		TextColor3 = C_DIM,
	}):Play()
end)

print("[SaveLoadUI] Initialized with minimal multi-slot design")