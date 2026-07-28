-- NPCDialogue: Client-side dialogue UI when talking to NPCs
-- Triggered by ProximityPrompt on NPC models

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Create the dialogue ScreenGui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "NPCDialogue"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Enabled = false
screenGui.Parent = playerGui

-- Dialogue box at bottom of screen
local dialogueBox = Instance.new("Frame")
dialogueBox.Name = "DialogueBox"
dialogueBox.Size = UDim2.new(0.7, 0, 0.2, 0)
dialogueBox.Position = UDim2.new(0.15, 0, 0.75, 0)
dialogueBox.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
dialogueBox.BackgroundTransparency = 0.1
dialogueBox.BorderSizePixel = 0
dialogueBox.Parent = screenGui



local boxStroke = Instance.new("UIStroke")
boxStroke.Color = Color3.fromRGB(255, 220, 100)
boxStroke.Thickness = 2
boxStroke.Transparency = 0.5
boxStroke.Parent = dialogueBox

-- NPC name label
local nameLabel = Instance.new("TextLabel")
nameLabel.Name = "NPCName"
nameLabel.Size = UDim2.new(0.98, 0, 0.25, 0)
nameLabel.Position = UDim2.new(0.01, 0, 0.02, 0)
nameLabel.BackgroundTransparency = 1
nameLabel.Text = ""
nameLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
nameLabel.Font = Enum.Font.Arcade
nameLabel.TextSize = 20
nameLabel.TextXAlignment = Enum.TextXAlignment.Left
nameLabel.Parent = dialogueBox

-- Dialogue text
local dialogueLabel = Instance.new("TextLabel")
dialogueLabel.Name = "DialogueText"
dialogueLabel.Size = UDim2.new(0.98, 0, 0.55, 0)
dialogueLabel.Position = UDim2.new(0.01, 0, 0.28, 0)
dialogueLabel.BackgroundTransparency = 1
dialogueLabel.Text = ""
dialogueLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
dialogueLabel.Font = Enum.Font.Arcade
dialogueLabel.TextSize = 16
dialogueLabel.TextXAlignment = Enum.TextXAlignment.Left
dialogueLabel.TextYAlignment = Enum.TextYAlignment.Top
dialogueLabel.TextWrapped = true
dialogueLabel.Parent = dialogueBox

-- Continue prompt
local continueLabel = Instance.new("TextLabel")
continueLabel.Name = "ContinueHint"
continueLabel.Size = UDim2.new(0.4, 0, 0.15, 0)
continueLabel.Position = UDim2.new(0.58, 0, 0.82, 0)
continueLabel.BackgroundTransparency = 1
continueLabel.Text = "Press E to continue"
continueLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
continueLabel.Font = Enum.Font.Arcade
continueLabel.TextSize = 12
continueLabel.Parent = dialogueBox

-- State
local isDialogueActive = false
local currentNPC = nil
local currentLineIndex = 0
local dialogueLines = {}
local waitingForContinue = false

local function showDialogue(npcName, line)
	nameLabel.Text = npcName
	dialogueLabel.Text = line
	screenGui.Enabled = true
	isDialogueActive = true
end

local function closeDialogue()
	screenGui.Enabled = false
	isDialogueActive = false
	currentNPC = nil
	currentLineIndex = 0
	dialogueLines = {}
	waitingForContinue = false
end

local function advanceDialogue()
	if not isDialogueActive then return end

	currentLineIndex = currentLineIndex + 1

	if currentLineIndex > #dialogueLines then
		closeDialogue()
		return
	end

	showDialogue(currentNPC, dialogueLines[currentLineIndex])
end

-- Listen for ProximityPrompt activations on NPCs
local function setupNPCPrompt(npcModel)
	if not npcModel:GetAttribute("IsNPC") then return end

	-- Find the ProximityPrompt in the NPC
	for _, part in npcModel:GetDescendants() do
		if part:IsA("ProximityPrompt") then
			part.Triggered:Connect(function(triggeringPlayer)
				if triggeringPlayer ~= player then return end
				if isDialogueActive then
					-- If already in dialogue, advance
					advanceDialogue()
					return
				end

				-- Start new dialogue
				currentNPC = npcModel.Name
				currentLineIndex = 0
				dialogueLines = {}

				local count = npcModel:GetAttribute("DialogueCount") or 0
				for i = 1, count do
					local line = npcModel:GetAttribute("Dialogue_" .. i)
					if line then
						table.insert(dialogueLines, line)
					end
				end

				if #dialogueLines > 0 then
					advanceDialogue()
				end
			end)
			break
		end
	end
end

-- Setup existing NPCs
local studville = game.Workspace:FindFirstChild("Studville")
if studville then
	local npcFolder = studville:FindFirstChild("NPCs")
	if npcFolder then
		for _, npc in npcFolder:GetChildren() do
			if npc:IsA("Model") then
				setupNPCPrompt(npc)
			end
		end

		-- Handle NPCs added later
		npcFolder.DescendantAdded:Connect(function(desc)
			if desc:IsA("ProximityPrompt") then
				task.wait(0.1)
				local npcModel = desc.Parent and desc.Parent.Parent
				if npcModel and npcModel:IsA("Model") then
					setupNPCPrompt(npcModel)
				end
			end
		end)
	end
end

-- E key to advance dialogue
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.E and isDialogueActive then
		advanceDialogue()
	end
end)

print("[NPCDialogue] Initialized - talk to NPCs with ProximityPrompt")