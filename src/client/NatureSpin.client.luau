--!strict
-- Chakra nature reveal: a vertical case-opening reel.
--
-- How it works, and why: the server rolls first and tells us the answer, then the
-- reel is *built around* that answer — a long strip of random filler with the real
-- result planted at a known index. The strip tweens so that index lands under the
-- centre marker. Nothing is decided on the client; the spin is pure presentation.
--
-- The strip decelerates on Quint/Out, which is what gives the case-opening feel,
-- and lands slightly off-centre so it doesn't look mechanically perfect every time.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local Natures = require(Shared.Config.Natures)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local VIEW_W = 300
local VIEW_H = 372
local CELL_H = 116
local CELL_COUNT = 44
-- Winner sits near the end, with a few cells after it so the strip never runs out
-- of content while decelerating.
local WINNER_INDEX = 38
local SPIN_TIME = 4.4

local DARK = Color3.fromRGB(16, 18, 24)
local PANEL = Color3.fromRGB(26, 30, 39)
local TEXT = Color3.fromRGB(235, 240, 248)
local MUTED = Color3.fromRGB(140, 152, 175)
local ACCENT = Color3.fromRGB(255, 130, 50)

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(168, 176, 190),
	Uncommon = Color3.fromRGB(120, 205, 140),
	Rare = Color3.fromRGB(110, 170, 255),
	Legendary = Color3.fromRGB(255, 172, 62),
	Mythic = Color3.fromRGB(232, 112, 240),
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local spinning = false

-- === layout ===

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiNature"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 8
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local shade = Instance.new("Frame")
shade.Size = UDim2.fromScale(1, 1)
shade.BackgroundColor3 = Color3.fromRGB(6, 7, 10)
shade.BackgroundTransparency = 0.42
shade.BorderSizePixel = 0
shade.Parent = gui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(392, 604)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = DARK
panel.BorderSizePixel = 0
panel.Parent = gui
corner(panel, 14)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(74, 84, 104)
panelStroke.Thickness = 1
panelStroke.Transparency = 0.35
panelStroke.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 26)
title.Position = UDim2.new(0, 0, 0, 18)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "Chakra Nature"
title.TextSize = 20
title.TextColor3 = TEXT
title.Parent = panel

local subtitle = Instance.new("TextLabel")
subtitle.Size = UDim2.new(1, -40, 0, 32)
subtitle.Position = UDim2.new(0, 20, 0, 44)
subtitle.BackgroundTransparency = 1
subtitle.Font = Enum.Font.Gotham
subtitle.Text = "The paper never lies."
subtitle.TextSize = 12
subtitle.TextColor3 = MUTED
subtitle.TextWrapped = true
subtitle.Parent = panel

-- === reel ===

local viewport = Instance.new("Frame")
viewport.Size = UDim2.fromOffset(VIEW_W, VIEW_H)
viewport.AnchorPoint = Vector2.new(0.5, 0)
viewport.Position = UDim2.new(0.5, 0, 0, 84)
viewport.BackgroundColor3 = PANEL
viewport.BorderSizePixel = 0
viewport.ClipsDescendants = true
viewport.Parent = panel
corner(viewport, 10)

local strip = Instance.new("Frame")
strip.Size = UDim2.fromOffset(VIEW_W, CELL_H * CELL_COUNT)
strip.Position = UDim2.fromOffset(0, 0)
strip.BackgroundTransparency = 1
strip.Parent = viewport

-- Top and bottom fades, so cells enter and leave rather than popping.
for _, edge in { { 0, 0 }, { 1, 1 } } do
	local fade = Instance.new("Frame")
	fade.Size = UDim2.new(1, 0, 0, 58)
	fade.AnchorPoint = Vector2.new(0, edge[2])
	fade.Position = UDim2.new(0, 0, edge[1], 0)
	fade.BackgroundColor3 = PANEL
	fade.BorderSizePixel = 0
	fade.ZIndex = 3
	fade.Parent = viewport

	local gradient = Instance.new("UIGradient")
	gradient.Rotation = if edge[1] == 0 then 90 else 270
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = fade
end

-- Centre marker: a bright line with a caret each side.
local marker = Instance.new("Frame")
marker.Size = UDim2.new(1, 0, 0, 2)
marker.AnchorPoint = Vector2.new(0, 0.5)
marker.Position = UDim2.fromScale(0, 0.5)
marker.BackgroundColor3 = ACCENT
marker.BorderSizePixel = 0
marker.ZIndex = 5
marker.Parent = viewport

for _, sx in { 0, 1 } do
	local caret = Instance.new("Frame")
	caret.Size = UDim2.fromOffset(12, 12)
	caret.Rotation = 45
	caret.AnchorPoint = Vector2.new(0.5, 0.5)
	caret.Position = UDim2.new(sx, 0, 0.5, 0)
	caret.BackgroundColor3 = ACCENT
	caret.BorderSizePixel = 0
	caret.ZIndex = 6
	caret.Parent = viewport
end

-- One reel cell. Returns it so the winner can be highlighted later.
local function buildCell(index: number, natureId: string): Frame
	local nature = Natures.get(natureId)
	local color = if nature then nature.Color else MUTED
	local rarity = if nature then nature.Rarity else "Common"

	local cell = Instance.new("Frame")
	cell.Name = `Cell{index}`
	cell.Size = UDim2.fromOffset(VIEW_W - 20, CELL_H - 10)
	cell.Position = UDim2.fromOffset(10, (index - 1) * CELL_H + 5)
	cell.BackgroundColor3 = Color3.new(color.R * 0.22, color.G * 0.22, color.B * 0.26)
	cell.BorderSizePixel = 0
	cell.Parent = strip
	corner(cell, 8)

	-- Colour bar down the left, so rarity reads at speed.
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 5, 1, -16)
	bar.Position = UDim2.fromOffset(8, 8)
	bar.BackgroundColor3 = RARITY_COLORS[rarity] or MUTED
	bar.BorderSizePixel = 0
	bar.Parent = cell
	corner(bar, 3)

	local kanji = Instance.new("TextLabel")
	kanji.Size = UDim2.fromOffset(72, 72)
	kanji.Position = UDim2.fromOffset(22, 17)
	kanji.BackgroundTransparency = 1
	kanji.Font = Enum.Font.GothamBold
	kanji.Text = if nature then nature.Kanji else "?"
	kanji.TextSize = 44
	kanji.TextColor3 = color
	kanji.Parent = cell

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -110, 0, 26)
	name.Position = UDim2.fromOffset(100, 28)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = if nature then nature.Name else natureId
	name.TextSize = 20
	name.TextColor3 = TEXT
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = cell

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.Size = UDim2.new(1, -110, 0, 18)
	rarityLabel.Position = UDim2.fromOffset(100, 54)
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Font = Enum.Font.GothamMedium
	rarityLabel.Text = rarity
	rarityLabel.TextSize = 12
	rarityLabel.TextColor3 = RARITY_COLORS[rarity] or MUTED
	rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
	rarityLabel.Parent = cell

	return cell
end

-- === controls ===

local resultLabel = Instance.new("TextLabel")
resultLabel.Size = UDim2.new(1, -40, 0, 26)
resultLabel.Position = UDim2.new(0, 20, 0, 470)
resultLabel.BackgroundTransparency = 1
resultLabel.Font = Enum.Font.GothamBold
resultLabel.Text = ""
resultLabel.TextSize = 17
resultLabel.TextColor3 = TEXT
resultLabel.Parent = panel

local spinButton = Instance.new("TextButton")
spinButton.Size = UDim2.new(1, -40, 0, 42)
spinButton.Position = UDim2.new(0, 20, 0, 506)
spinButton.BackgroundColor3 = ACCENT
spinButton.BorderSizePixel = 0
spinButton.Font = Enum.Font.GothamBold
spinButton.Text = "Spin"
spinButton.TextSize = 15
spinButton.TextColor3 = Color3.fromRGB(20, 16, 12)
spinButton.Parent = panel
corner(spinButton, 8)

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(1, -40, 0, 30)
closeButton.Position = UDim2.new(0, 20, 0, 556)
closeButton.BackgroundColor3 = PANEL
closeButton.BorderSizePixel = 0
closeButton.Font = Enum.Font.GothamMedium
closeButton.Text = "Close"
closeButton.TextSize = 13
closeButton.TextColor3 = MUTED
closeButton.Parent = panel
corner(closeButton, 7)

-- === behaviour ===

local function clearStrip()
	for _, child in strip:GetChildren() do
		child:Destroy()
	end
end

-- Park a single cell in the middle: used when you already have a nature, so the
-- panel shows what you rolled rather than an empty reel.
local function showStatic(natureId: string)
	clearStrip()
	strip.Position = UDim2.fromOffset(0, -((WINNER_INDEX - 1) * CELL_H) + (VIEW_H - CELL_H) / 2)
	buildCell(WINNER_INDEX, natureId)

	local nature = Natures.get(natureId)
	resultLabel.Text = if nature
		then `{nature.Kanji}  {nature.Name}  ·  {nature.Rarity}`
		else natureId
	resultLabel.TextColor3 = if nature then nature.Color else TEXT
	spinButton.Visible = false
	subtitle.Text = "Your chakra nature is already set. It cannot be changed."
end

local function reveal(natureId: string, cell: Frame)
	local nature = Natures.get(natureId)

	resultLabel.Text = if nature
		then `{nature.Kanji}  {nature.Name}  ·  {nature.Rarity}`
		else natureId
	resultLabel.TextColor3 = if nature then nature.Color else TEXT

	-- Ring the winning cell and give it a small pop.
	local stroke = Instance.new("UIStroke")
	stroke.Color = if nature then nature.Color else ACCENT
	stroke.Thickness = 3
	stroke.Parent = cell

	local grow = TweenService:Create(cell, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromOffset(VIEW_W - 8, CELL_H - 2),
	})
	grow:Play()

	spinning = false
	-- Lets the HUD render its nature row now that the reveal has happened.
	player:SetAttribute("NatureSpinning", false)
	closeButton.Visible = true
end

local function runSpin(natureId: string)
	clearStrip()
	spinButton.Visible = false
	closeButton.Visible = false
	resultLabel.Text = ""
	subtitle.Text = "Reading your chakra..."

	-- Filler is genuinely weighted, so the reel flying past feels like the real
	-- odds rather than a uniform shuffle.
	local winnerCell: Frame? = nil
	for i = 1, CELL_COUNT do
		local id = if i == WINNER_INDEX then natureId else Natures.roll()
		local cell = buildCell(i, id)
		if i == WINNER_INDEX then
			winnerCell = cell
		end
	end

	-- Land slightly off-centre so it never looks mechanically perfect.
	local jitter = (math.random() - 0.5) * CELL_H * 0.5
	local targetY = -((WINNER_INDEX - 1) * CELL_H) + (VIEW_H - CELL_H) / 2 + jitter

	strip.Position = UDim2.fromOffset(0, 0)
	local tween = TweenService:Create(
		strip,
		TweenInfo.new(SPIN_TIME, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, targetY) }
	)

	tween.Completed:Connect(function()
		subtitle.Text = "The paper never lies."
		if winnerCell then
			reveal(natureId, winnerCell)
		end
	end)

	tween:Play()
end

local function openPanel(payload: any)
	if type(payload) ~= "table" then
		return
	end

	gui.Enabled = true
	closeButton.Visible = true

	if payload.hasNature and type(payload.natureId) == "string" then
		showStatic(payload.natureId)
	else
		clearStrip()
		strip.Position = UDim2.fromOffset(0, 0)
		-- A few idle cells so the reel isn't blank before the first spin.
		for i = 1, CELL_COUNT do
			buildCell(i, Natures.roll())
		end
		resultLabel.Text = ""
		subtitle.Text = "The paper never lies."
		spinButton.Visible = true
	end
end

spinButton.Activated:Connect(function()
	if spinning then
		return
	end
	spinning = true
	-- Tell the HUD to hold its nature row until the reveal, or it spoils the spin.
	player:SetAttribute("NatureSpinning", true)
	Remotes.Events.RequestNatureRoll:FireServer()
end)

closeButton.Activated:Connect(function()
	if spinning then
		return
	end
	gui.Enabled = false
end)

Remotes.Events.OpenNaturePanel.OnClientEvent:Connect(openPanel)

Remotes.Events.NatureRollResult.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		return
	end
	runSpin(payload.id)
end)

-- The dialogue box lives in Quests.client, which forwards here after the elder's
-- line is dismissed. A BindableEvent keeps the two client scripts decoupled —
-- neither has to know the other's internals, only this name.
local bridge = Instance.new("BindableEvent")
bridge.Name = "OpenNaturePanelBridge"
bridge.Parent = player:WaitForChild("PlayerGui")
bridge.Event:Connect(openPanel)
