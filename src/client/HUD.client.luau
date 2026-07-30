--!strict
-- Progression HUD: level, rank, XP bar, chakra nature, and stat allocation.
-- Reads only from ProfileUpdated — the client never computes progression
-- itself, it just renders whatever the server last said.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Natures = require(Shared.Config.Natures)
local Ranks = require(Shared.Config.Ranks)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer
local STAT_ORDER: { Types.StatName } = { "Taijutsu", "Defense", "Weapon", "Ninjutsu", "Chakra" }

local DARK = Color3.fromRGB(18, 20, 26)
local PANEL = Color3.fromRGB(26, 30, 39)
local TEXT = Color3.fromRGB(235, 240, 248)
local MUTED = Color3.fromRGB(140, 152, 175)
local ACCENT = Color3.fromRGB(255, 130, 50)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, text: string, size: number, color: Color3): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

-- === Layout ===

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiHUD"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(268, 0)
root.AutomaticSize = Enum.AutomaticSize.Y
root.Position = UDim2.new(0, 16, 0, 16)
root.BackgroundColor3 = DARK
root.BackgroundTransparency = 0.08
root.BorderSizePixel = 0
root.Parent = gui
corner(root, 10)

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 14)
pad.PaddingBottom = UDim.new(0, 14)
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.Parent = root

local list = Instance.new("UIListLayout")
list.SortOrder = Enum.SortOrder.LayoutOrder
list.Padding = UDim.new(0, 8)
list.Parent = root

-- Header: rank + level
local rankLabel = label(root, "Academy Student", 13, MUTED)
rankLabel.Size = UDim2.new(1, 0, 0, 16)
rankLabel.LayoutOrder = 1

local levelLabel = label(root, "Level 1", 26, TEXT)
levelLabel.Font = Enum.Font.GothamBold
levelLabel.Size = UDim2.new(1, 0, 0, 30)
levelLabel.LayoutOrder = 2

-- XP bar
local xpTrack = Instance.new("Frame")
xpTrack.Size = UDim2.new(1, 0, 0, 8)
xpTrack.BackgroundColor3 = PANEL
xpTrack.BorderSizePixel = 0
xpTrack.LayoutOrder = 3
xpTrack.Parent = root
corner(xpTrack, 4)

local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = ACCENT
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack
corner(xpFill, 4)

local xpLabel = label(root, "0 / 50 XP", 11, MUTED)
xpLabel.Size = UDim2.new(1, 0, 0, 14)
xpLabel.LayoutOrder = 4

-- Nature. Display only — rolling happens at the Nature Elder NPC, so there is
-- no client-callable path to a roll at all.
local natureRow = Instance.new("TextButton")
natureRow.Size = UDim2.new(1, 0, 0, 34)
natureRow.BackgroundColor3 = PANEL
natureRow.BorderSizePixel = 0
natureRow.Font = Enum.Font.GothamMedium
natureRow.TextSize = 13
natureRow.TextColor3 = MUTED
natureRow.Text = "Nature unknown"
natureRow.AutoButtonColor = false
natureRow.LayoutOrder = 5
natureRow.Parent = root
corner(natureRow, 6)

-- Stat points header
local pointsLabel = label(root, "Stat points: 0", 12, ACCENT)
pointsLabel.Font = Enum.Font.GothamBold
pointsLabel.Size = UDim2.new(1, 0, 0, 16)
pointsLabel.LayoutOrder = 6

-- Stat rows
local statRows: { [string]: { value: TextLabel, button: TextButton } } = {}

for index, stat in STAT_ORDER do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundTransparency = 1
	row.LayoutOrder = 6 + index
	row.Parent = root

	local name = label(row, stat, 13, TEXT)
	name.Size = UDim2.new(1, -80, 1, 0)

	local value = label(row, "0", 13, MUTED)
	value.Size = UDim2.new(0, 40, 1, 0)
	value.Position = UDim2.new(1, -74, 0, 0)
	value.TextXAlignment = Enum.TextXAlignment.Right

	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(26, 22)
	button.Position = UDim2.new(1, -26, 0, 2)
	button.BackgroundColor3 = PANEL
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = "+"
	button.TextSize = 15
	button.TextColor3 = TEXT
	button.Parent = row
	corner(button, 5)

	button.Activated:Connect(function()
		-- Shift-click spends 10 at once; the server clamps to what's available.
		local bulk = game:GetService("UserInputService"):IsKeyDown(Enum.KeyCode.LeftShift)
		Remotes.Events.SpendStatPoint:FireServer({ stat = stat, amount = if bulk then 10 else 1 })
	end)

	statRows[stat] = { value = value, button = button }
end

-- Studio-only XP button, so progression is testable without any enemies yet.
if RunService:IsStudio() then
	local debugButton = Instance.new("TextButton")
	debugButton.Size = UDim2.new(1, 0, 0, 28)
	debugButton.BackgroundColor3 = Color3.fromRGB(60, 45, 30)
	debugButton.BorderSizePixel = 0
	debugButton.Font = Enum.Font.GothamMedium
	debugButton.Text = "+500 XP  (Studio only)"
	debugButton.TextSize = 12
	debugButton.TextColor3 = ACCENT
	debugButton.LayoutOrder = 100
	debugButton.Parent = root
	corner(debugButton, 6)

	debugButton.Activated:Connect(function()
		Remotes.Events.DebugAwardXP:FireServer(500)
	end)
end

-- === Notifications ===

local toast = label(gui, "", 22, TEXT)
toast.Font = Enum.Font.GothamBold
toast.Size = UDim2.new(1, 0, 0, 30)
toast.Position = UDim2.new(0, 0, 0.24, 0)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextTransparency = 1
toast.TextStrokeTransparency = 0.6

local function showToast(text: string)
	toast.Text = text
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.6
	TweenService:Create(toast, TweenInfo.new(2.2, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

-- === Rendering ===

-- Kept so the nature row can be re-rendered once a spin finishes.
local lastProfile: Types.Profile? = nil

local function render(profile: Types.Profile)
	lastProfile = profile
	local rank = Ranks.forLevel(profile.Level)
	rankLabel.Text = rank.Name
	rankLabel.TextColor3 = rank.Color
	levelLabel.Text = `Level {profile.Level}`

	local needed = Formulas.xpForNextLevel(profile.Level)
	if needed == math.huge then
		xpLabel.Text = "MAX LEVEL"
		xpFill.Size = UDim2.new(1, 0, 1, 0)
	else
		local ratio = math.clamp(profile.XP / needed, 0, 1)
		xpLabel.Text = `{profile.XP} / {needed} XP`
		TweenService:Create(xpFill, TweenInfo.new(0.3), { Size = UDim2.new(ratio, 0, 1, 0) }):Play()
	end

	-- Hold this row while the reveal reel is spinning. The server pushes the profile
	-- the instant it rolls — correct for data, but it would print the answer here
	-- seconds before the reel lands on it.
	if player:GetAttribute("NatureSpinning") ~= true then
		local nature = Natures.get(profile.Nature)
		if nature then
			natureRow.Text = `{nature.Kanji}  {nature.Name}  ·  {nature.Rarity}`
			natureRow.TextColor3 = nature.Color
			natureRow.AutoButtonColor = false
		else
			natureRow.Text = "Nature unknown  ·  find the Elder"
			natureRow.TextColor3 = MUTED
			natureRow.AutoButtonColor = false
		end
	end

	pointsLabel.Text = `Stat points: {profile.StatPoints}`

	for stat, row in statRows do
		row.value.Text = tostring(profile.Stats[stat :: any])
		row.button.Visible = profile.StatPoints > 0
			and profile.Stats[stat :: any] < GameConfig.MaxPointsPerStat
	end
end

natureRow.Activated:Connect(function()
	-- Deliberately does not roll. Points the player at the NPC instead.
	if not natureRow.Text:find("·") and natureRow.Text ~= "Nature unknown" then
		return
	end
	showToast("Seek the Nature Elder to have your chakra read")
end)

-- Catch up the nature row the moment the spin finishes.
player:GetAttributeChangedSignal("NatureSpinning"):Connect(function()
	if player:GetAttribute("NatureSpinning") ~= true and lastProfile then
		render(lastProfile)
	end
end)

Remotes.Events.ProfileUpdated.OnClientEvent:Connect(render)
Remotes.Events.Notify.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.text then
		showToast(payload.text)
	end
end)

-- Ask once on join, in case ProfileUpdated fired before this script was ready.
local initial = Remotes.Functions.GetProfile:InvokeServer()
if initial then
	render(initial)
end
