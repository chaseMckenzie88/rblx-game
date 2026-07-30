--!strict
-- Health and chakra bars, bottom centre.
--
-- Health is read straight off the local Humanoid — it's already the authoritative
-- live value and replicates on its own, so routing it through a remote would only
-- add latency. Chakra has no such built-in, so it arrives via VitalsUpdated.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local WIDTH = 340
local BAR_HEIGHT = 16

local DARK = Color3.fromRGB(18, 20, 26)
local TRACK = Color3.fromRGB(34, 38, 48)
local TEXT = Color3.fromRGB(235, 240, 248)
local HEALTH = Color3.fromRGB(235, 78, 78)
local CHAKRA = Color3.fromRGB(70, 160, 255)

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiVitals"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Size = UDim2.fromOffset(WIDTH, BAR_HEIGHT * 2 + 6)
root.AnchorPoint = Vector2.new(0.5, 1)
root.Position = UDim2.new(0.5, 0, 1, -20)
root.BackgroundColor3 = DARK
root.BackgroundTransparency = 0.25
root.BorderSizePixel = 0
root.Parent = gui

local rootCorner = Instance.new("UICorner")
rootCorner.CornerRadius = UDim.new(0, 8)
rootCorner.Parent = root

local pad = Instance.new("UIPadding")
pad.PaddingTop = UDim.new(0, 5)
pad.PaddingBottom = UDim.new(0, 5)
pad.PaddingLeft = UDim.new(0, 8)
pad.PaddingRight = UDim.new(0, 8)
pad.Parent = root

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 4)
layout.Parent = root

-- One bar: a track, a tweened fill, and a centred readout.
local function makeBar(color: Color3, order: number): (Frame, TextLabel)
	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, 0, 0, BAR_HEIGHT)
	track.BackgroundColor3 = TRACK
	track.BorderSizePixel = 0
	track.LayoutOrder = order
	track.Parent = root

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(0, 4)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill

	local readout = Instance.new("TextLabel")
	readout.Size = UDim2.fromScale(1, 1)
	readout.BackgroundTransparency = 1
	readout.Font = Enum.Font.GothamBold
	readout.TextSize = 11
	readout.TextColor3 = TEXT
	readout.TextStrokeTransparency = 0.55
	readout.Text = ""
	readout.ZIndex = 2
	readout.Parent = track

	return fill, readout
end

local healthFill, healthText = makeBar(HEALTH, 1)
local chakraFill, chakraText = makeBar(CHAKRA, 2)

local TWEEN = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function setBar(fill: Frame, readout: TextLabel, current: number, max: number)
	local ratio = if max > 0 then math.clamp(current / max, 0, 1) else 0
	TweenService:Create(fill, TWEEN, { Size = UDim2.fromScale(ratio, 1) }):Play()
	readout.Text = `{math.floor(current + 0.5)} / {math.floor(max + 0.5)}`
end

-- === Health: local Humanoid ===

local function watchHumanoid(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	local function sync()
		setBar(healthFill, healthText, humanoid.Health, humanoid.MaxHealth)
	end

	humanoid.HealthChanged:Connect(sync)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(sync)
	sync()
end

if player.Character then
	task.spawn(watchHumanoid, player.Character)
end
player.CharacterAdded:Connect(watchHumanoid)

-- === Chakra: pushed by ChakraService ===

Remotes.Events.VitalsUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end
	setBar(chakraFill, chakraText, tonumber(payload.chakra) or 0, tonumber(payload.maxChakra) or 0)
end)
