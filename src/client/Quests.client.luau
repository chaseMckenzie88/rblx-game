--!strict
-- Three pieces of quest UI:
--   · tracker  — always on, top right, shows the active quest
--   · dialogue — an NPC's one-time greeting, typed out
--   · board    — the mission list, one layout for every giver
--
-- The board is built once and its rows recycled on each open. Its header is
-- driven entirely by the giver payload, so every NPC's board reads identically:
-- name, title, level band, greeting, then quests.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = game.ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local DARK = Color3.fromRGB(18, 20, 26)
local PANEL = Color3.fromRGB(26, 30, 39)
local ROW = Color3.fromRGB(32, 37, 48)
local TEXT = Color3.fromRGB(235, 240, 248)
local MUTED = Color3.fromRGB(140, 152, 175)
local ACCENT = Color3.fromRGB(255, 130, 50)
local GREEN = Color3.fromRGB(120, 225, 150)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, color: Color3, transparency: number)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Transparency = transparency
	s.Thickness = 1
	s.Parent = parent
end

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiQuests"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- ============================================================ tracker

local tracker = Instance.new("Frame")
tracker.Size = UDim2.fromOffset(240, 0)
tracker.AutomaticSize = Enum.AutomaticSize.Y
tracker.AnchorPoint = Vector2.new(1, 0)
tracker.Position = UDim2.new(1, -16, 0, 16)
tracker.BackgroundColor3 = DARK
tracker.BackgroundTransparency = 0.1
tracker.BorderSizePixel = 0
tracker.Visible = false
tracker.Parent = gui
corner(tracker, 8)

local trackerPad = Instance.new("UIPadding")
trackerPad.PaddingTop = UDim.new(0, 10)
trackerPad.PaddingBottom = UDim.new(0, 10)
trackerPad.PaddingLeft = UDim.new(0, 12)
trackerPad.PaddingRight = UDim.new(0, 12)
trackerPad.Parent = tracker

local trackerList = Instance.new("UIListLayout")
trackerList.SortOrder = Enum.SortOrder.LayoutOrder
trackerList.Padding = UDim.new(0, 4)
trackerList.Parent = tracker

local function trackerLabel(text: string, size: number, color: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextTruncate = Enum.TextTruncate.AtEnd
	l.LayoutOrder = order
	l.Parent = tracker
	return l
end

local trackerTitle = trackerLabel("", 14, TEXT, 1)
trackerTitle.Font = Enum.Font.GothamBold
local trackerArea = trackerLabel("", 11, MUTED, 2)
local trackerObjective = trackerLabel("", 13, ACCENT, 3)

local progressTrack = Instance.new("Frame")
progressTrack.Size = UDim2.new(1, 0, 0, 6)
progressTrack.BackgroundColor3 = PANEL
progressTrack.BorderSizePixel = 0
progressTrack.LayoutOrder = 4
progressTrack.Parent = tracker
corner(progressTrack, 3)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = ACCENT
progressFill.BorderSizePixel = 0
progressFill.Parent = progressTrack
corner(progressFill, 3)

Remotes.Events.QuestUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	local active = payload.active
	if type(active) ~= "table" then
		tracker.Visible = false
		return
	end

	tracker.Visible = true
	trackerTitle.Text = tostring(active.name)
	trackerArea.Text = tostring(active.areaName)

	local progress = tonumber(active.progress) or 0
	local total = tonumber(active.killCount) or 1
	trackerObjective.Text = `{active.targetName}  {progress}/{total}`

	TweenService:Create(progressFill, TweenInfo.new(0.25), {
		Size = UDim2.fromScale(math.clamp(progress / total, 0, 1), 1),
	}):Play()
end)

-- ============================================================ board

local board = Instance.new("Frame")
board.Size = UDim2.fromOffset(440, 430)
board.AnchorPoint = Vector2.new(0.5, 0.5)
board.Position = UDim2.fromScale(0.5, 0.5)
board.BackgroundColor3 = DARK
board.BorderSizePixel = 0
board.Visible = false
board.Parent = gui
corner(board, 12)
stroke(board, Color3.fromRGB(70, 80, 100), 0.4)

local boardPad = Instance.new("UIPadding")
boardPad.PaddingTop = UDim.new(0, 16)
boardPad.PaddingBottom = UDim.new(0, 14)
boardPad.PaddingLeft = UDim.new(0, 16)
boardPad.PaddingRight = UDim.new(0, 16)
boardPad.Parent = board

-- Header. Identical structure for every giver.
local giverName = Instance.new("TextLabel")
giverName.Size = UDim2.new(1, -34, 0, 22)
giverName.BackgroundTransparency = 1
giverName.Font = Enum.Font.GothamBold
giverName.Text = ""
giverName.TextSize = 19
giverName.TextColor3 = TEXT
giverName.TextXAlignment = Enum.TextXAlignment.Left
giverName.Parent = board

local giverBand = Instance.new("TextLabel")
giverBand.Size = UDim2.new(1, -34, 0, 16)
giverBand.Position = UDim2.new(0, 0, 0, 23)
giverBand.BackgroundTransparency = 1
giverBand.Font = Enum.Font.GothamMedium
giverBand.Text = ""
giverBand.TextSize = 12
giverBand.TextColor3 = ACCENT
giverBand.TextXAlignment = Enum.TextXAlignment.Left
giverBand.Parent = board

local giverGreeting = Instance.new("TextLabel")
giverGreeting.Size = UDim2.new(1, 0, 0, 34)
giverGreeting.Position = UDim2.new(0, 0, 0, 44)
giverGreeting.BackgroundTransparency = 1
giverGreeting.Font = Enum.Font.Gotham
giverGreeting.Text = ""
giverGreeting.TextSize = 12
giverGreeting.TextColor3 = MUTED
giverGreeting.TextXAlignment = Enum.TextXAlignment.Left
giverGreeting.TextYAlignment = Enum.TextYAlignment.Top
giverGreeting.TextWrapped = true
giverGreeting.Parent = board

local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.new(0, 0, 0, 84)
divider.BackgroundColor3 = Color3.fromRGB(60, 68, 84)
divider.BorderSizePixel = 0
divider.Parent = board

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.fromOffset(26, 26)
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, 0, 0, 0)
closeButton.BackgroundColor3 = PANEL
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamBold
closeButton.Text = "×"
closeButton.TextSize = 18
closeButton.TextColor3 = MUTED
closeButton.Parent = board
corner(closeButton, 6)

closeButton.Activated:Connect(function()
	board.Visible = false
end)

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, 0, 1, -96)
scroll.Position = UDim2.new(0, 0, 0, 94)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 4
scroll.CanvasSize = UDim2.new()
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = board

local scrollList = Instance.new("UIListLayout")
scrollList.SortOrder = Enum.SortOrder.LayoutOrder
scrollList.Padding = UDim.new(0, 8)
scrollList.Parent = scroll

local function buildRow(quest: any, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -6, 0, 80)
	row.BackgroundColor3 = ROW
	row.BorderSizePixel = 0
	row.LayoutOrder = order
	row.Parent = scroll
	corner(row, 8)

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingTop = UDim.new(0, 9)
	rowPad.PaddingLeft = UDim.new(0, 11)
	rowPad.PaddingRight = UDim.new(0, 11)
	rowPad.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -104, 0, 18)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = tostring(quest.name)
	name.TextSize = 14
	name.TextColor3 = if quest.locked then MUTED else TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	local objective = Instance.new("TextLabel")
	objective.Size = UDim2.new(1, -104, 0, 16)
	objective.Position = UDim2.new(0, 0, 0, 20)
	objective.BackgroundTransparency = 1
	objective.Font = Enum.Font.GothamMedium
	objective.Text = `Defeat {quest.killCount} {quest.targetName}  ·  Lv {quest.targetLevel}`
	objective.TextSize = 12
	objective.TextColor3 = MUTED
	objective.TextXAlignment = Enum.TextXAlignment.Left
	objective.Parent = row

	local reward = Instance.new("TextLabel")
	reward.Size = UDim2.new(1, -104, 0, 16)
	reward.Position = UDim2.new(0, 0, 0, 39)
	reward.BackgroundTransparency = 1
	reward.Font = Enum.Font.GothamMedium
	reward.Text = `+{quest.xpReward} XP  ·  +{quest.ryoReward} Ryo`
	reward.TextSize = 12
	reward.TextColor3 = GREEN
	reward.TextXAlignment = Enum.TextXAlignment.Left
	reward.Parent = row

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(88, 30)
	button.AnchorPoint = Vector2.new(1, 0)
	button.Position = UDim2.new(1, 0, 0, 13)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.Parent = row
	corner(button, 6)

	local interactive = false

	if quest.locked then
		button.Text = `Lv {quest.requiredLevel}`
		button.BackgroundColor3 = PANEL
		button.TextColor3 = MUTED
	elseif quest.completedOnce then
		button.Text = "Done"
		button.BackgroundColor3 = PANEL
		button.TextColor3 = MUTED
	elseif quest.active then
		button.Text = "Active"
		button.BackgroundColor3 = PANEL
		button.TextColor3 = GREEN
	else
		button.Text = "Accept"
		button.BackgroundColor3 = ACCENT
		button.TextColor3 = Color3.fromRGB(20, 16, 12)
		interactive = true
	end

	button.AutoButtonColor = interactive

	if interactive then
		button.Activated:Connect(function()
			Remotes.Events.AcceptQuest:FireServer({ id = quest.id })
			board.Visible = false
		end)
	end

	if quest.timesCompleted > 0 then
		local count = Instance.new("TextLabel")
		count.Size = UDim2.fromOffset(88, 14)
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, 0, 0, 46)
		count.BackgroundTransparency = 1
		count.Font = Enum.Font.GothamMedium
		count.Text = `completed ×{quest.timesCompleted}`
		count.TextSize = 10
		count.TextColor3 = MUTED
		count.TextXAlignment = Enum.TextXAlignment.Right
		count.Parent = row
	end
end

local function openBoard(payload: any)
	if type(payload) ~= "table" or type(payload.quests) ~= "table" then
		return
	end

	local giver = payload.giver
	if type(giver) == "table" then
		giverName.Text = tostring(giver.name)
		giverBand.Text =
			`Quests for Level {giver.levelMin}-{giver.levelMax}  ·  {giver.title}`
		giverGreeting.Text = tostring(giver.greeting)
	end

	for _, child in scroll:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if #payload.quests == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, -6, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Parent = scroll

		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamMedium
		text.Text = "Nothing available right now."
		text.TextSize = 13
		text.TextColor3 = MUTED
		text.Parent = empty
	else
		for index, quest in payload.quests do
			buildRow(quest, index)
		end
	end

	board.Visible = true
end

Remotes.Events.OpenQuestBoard.OnClientEvent:Connect(openBoard)

-- ============================================================ dialogue

local dialogue = Instance.new("Frame")
dialogue.Size = UDim2.fromOffset(640, 132)
dialogue.AnchorPoint = Vector2.new(0.5, 1)
dialogue.Position = UDim2.new(0.5, 0, 1, -104)
dialogue.BackgroundColor3 = DARK
dialogue.BackgroundTransparency = 0.05
dialogue.BorderSizePixel = 0
dialogue.Visible = false
dialogue.Parent = gui
corner(dialogue, 12)
stroke(dialogue, ACCENT, 0.55)

local dialoguePad = Instance.new("UIPadding")
dialoguePad.PaddingTop = UDim.new(0, 14)
dialoguePad.PaddingBottom = UDim.new(0, 12)
dialoguePad.PaddingLeft = UDim.new(0, 18)
dialoguePad.PaddingRight = UDim.new(0, 18)
dialoguePad.Parent = dialogue

local speakerName = Instance.new("TextLabel")
speakerName.Size = UDim2.new(1, 0, 0, 20)
speakerName.BackgroundTransparency = 1
speakerName.Font = Enum.Font.GothamBold
speakerName.Text = ""
speakerName.TextSize = 17
speakerName.TextColor3 = ACCENT
speakerName.TextXAlignment = Enum.TextXAlignment.Left
speakerName.Parent = dialogue

local speakerTitle = Instance.new("TextLabel")
speakerTitle.Size = UDim2.new(1, 0, 0, 14)
speakerTitle.Position = UDim2.new(0, 0, 0, 20)
speakerTitle.BackgroundTransparency = 1
speakerTitle.Font = Enum.Font.GothamMedium
speakerTitle.Text = ""
speakerTitle.TextSize = 11
speakerTitle.TextColor3 = MUTED
speakerTitle.TextXAlignment = Enum.TextXAlignment.Left
speakerTitle.Parent = dialogue

local speech = Instance.new("TextLabel")
speech.Size = UDim2.new(1, 0, 0, 52)
speech.Position = UDim2.new(0, 0, 0, 40)
speech.BackgroundTransparency = 1
speech.Font = Enum.Font.Gotham
speech.Text = ""
speech.TextSize = 15
speech.TextColor3 = TEXT
speech.TextXAlignment = Enum.TextXAlignment.Left
speech.TextYAlignment = Enum.TextYAlignment.Top
speech.TextWrapped = true
speech.Parent = dialogue

local continueHint = Instance.new("TextLabel")
continueHint.Size = UDim2.new(1, 0, 0, 14)
continueHint.AnchorPoint = Vector2.new(0, 1)
continueHint.Position = UDim2.new(0, 0, 1, 0)
continueHint.BackgroundTransparency = 1
continueHint.Font = Enum.Font.GothamMedium
continueHint.Text = "click to continue"
continueHint.TextSize = 11
continueHint.TextColor3 = MUTED
continueHint.TextXAlignment = Enum.TextXAlignment.Right
continueHint.Parent = dialogue

local dialogueButton = Instance.new("TextButton")
dialogueButton.Size = UDim2.fromScale(1, 1)
dialogueButton.BackgroundTransparency = 1
dialogueButton.Text = ""
dialogueButton.ZIndex = 3
dialogueButton.Parent = dialogue

-- Typewriter state. `token` invalidates an in-flight reveal if a new line starts
-- or the player skips ahead, so two loops can't fight over the same label.
local fullText = ""
local revealing = false
local token = 0
local pendingBoard: any = nil
local pendingNature: any = nil

local function revealText(text: string)
	fullText = text
	token += 1
	local mine = token
	revealing = true
	speech.Text = ""

	task.spawn(function()
		for index = 1, #text do
			if token ~= mine then
				return
			end
			speech.Text = string.sub(text, 1, index)
			task.wait(0.018)
		end
		if token == mine then
			revealing = false
		end
	end)
end

local function advance()
	if not dialogue.Visible then
		return
	end

	-- First click finishes the reveal, second click closes.
	if revealing then
		token += 1
		revealing = false
		speech.Text = fullText
		return
	end

	dialogue.Visible = false

	if pendingBoard then
		local payload = pendingBoard
		pendingBoard = nil
		openBoard(payload)
	end

	-- The Nature Elder's panel lives in NatureSpin.client. Hand off through the
	-- BindableEvent it publishes rather than coupling the two scripts. FindFirstChild
	-- is safe here: dismissing a dialogue happens long after both have initialised.
	if pendingNature then
		local payload = pendingNature
		pendingNature = nil
		local bridge = player.PlayerGui:FindFirstChild("OpenNaturePanelBridge")
		if bridge and bridge:IsA("BindableEvent") then
			bridge:Fire(payload)
		end
	end
end

dialogueButton.Activated:Connect(advance)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not dialogue.Visible then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Space then
		advance()
	end
end)

Remotes.Events.ShowDialogue.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	speakerName.Text = tostring(payload.name)
	speakerTitle.Text = tostring(payload.title)
	pendingBoard = payload.thenOpenBoard
	pendingNature = payload.thenOpenNature

	board.Visible = false
	dialogue.Visible = true
	revealText(tostring(payload.text))
end)
