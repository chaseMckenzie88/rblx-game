--!strict
-- Kunai quest compass, left edge of the screen.
--
--   · click the kunai      → mission panel (name, location, target level, giver)
--   · press Track          → the kunai starts pointing at the objective and a
--                            kunai marker appears over the quest giver
--   · the kunai spins       → camera-relative bearing, so "up" always means
--                            straight ahead rather than north
--
-- Built from Frames rather than an image asset so it needs no uploads and can be
-- recoloured freely. Swap in a decal later if you want a drawn kunai.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local USE_IMAGE = GameConfig.KunaiIconId > 0

local player = Players.LocalPlayer

local DARK = Color3.fromRGB(18, 20, 26)
local PANEL = Color3.fromRGB(28, 32, 41)
local TEXT = Color3.fromRGB(235, 240, 248)
local MUTED = Color3.fromRGB(140, 152, 175)
local ACCENT = Color3.fromRGB(255, 130, 50)
local GREEN = Color3.fromRGB(120, 225, 150)
local STEEL = Color3.fromRGB(196, 204, 214)
local STEEL_DARK = Color3.fromRGB(120, 128, 140)
local GRIP = Color3.fromRGB(52, 46, 44)

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- === state ===

type Active = {
	id: string,
	name: string,
	areaName: string,
	targetName: string,
	targetLevel: number,
	killCount: number,
	progress: number,
	zonePosition: Vector3?,
	giverId: string?,
	giverName: string?,
}

local active: Active? = nil
local tracking = false
local giverMarker: BillboardGui? = nil

-- === kunai drawing ===

-- The uploaded icon. Pre-rotated so the blade points UP at rotation 0 — the
-- source art points down-left, and the compass maths assumes up means ahead.
local function imageKunai(parent: Instance, pixels: number): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = "KunaiIcon"
	image.BackgroundTransparency = 1
	image.Image = `rbxassetid://{GameConfig.KunaiIconId}`
	image.Size = UDim2.fromOffset(pixels, pixels)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Rotation = GameConfig.KunaiIconBaseRotation
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = parent
	return image
end

-- Fallback shape, drawn from Frames. Assembled pointing up, same as the icon.
local function drawKunai(parent: Instance, scale: number): Frame
	local body = Instance.new("Frame")
	body.BackgroundTransparency = 1
	body.Size = UDim2.fromOffset(40 * scale, 96 * scale)
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Parent = parent

	-- Blade tip: a square turned 45° so its corner is the point.
	local tip = Instance.new("Frame")
	tip.Size = UDim2.fromOffset(19 * scale, 19 * scale)
	tip.AnchorPoint = Vector2.new(0.5, 0)
	tip.Position = UDim2.new(0.5, 0, 0, 3 * scale)
	tip.Rotation = 45
	tip.BackgroundColor3 = STEEL
	tip.BorderSizePixel = 0
	tip.Parent = body

	-- Blade body, tapering into the guard.
	local blade = Instance.new("Frame")
	blade.Size = UDim2.fromOffset(15 * scale, 34 * scale)
	blade.AnchorPoint = Vector2.new(0.5, 0)
	blade.Position = UDim2.new(0.5, 0, 0, 14 * scale)
	blade.BackgroundColor3 = STEEL
	blade.BorderSizePixel = 0
	blade.Parent = body

	-- Centre fuller line, so the blade doesn't read as a flat bar.
	local fuller = Instance.new("Frame")
	fuller.Size = UDim2.fromOffset(2 * scale, 30 * scale)
	fuller.AnchorPoint = Vector2.new(0.5, 0)
	fuller.Position = UDim2.new(0.5, 0, 0, 16 * scale)
	fuller.BackgroundColor3 = STEEL_DARK
	fuller.BorderSizePixel = 0
	fuller.ZIndex = 2
	fuller.Parent = body

	local guard = Instance.new("Frame")
	guard.Size = UDim2.fromOffset(25 * scale, 5 * scale)
	guard.AnchorPoint = Vector2.new(0.5, 0)
	guard.Position = UDim2.new(0.5, 0, 0, 47 * scale)
	guard.BackgroundColor3 = STEEL_DARK
	guard.BorderSizePixel = 0
	guard.Parent = body

	local handle = Instance.new("Frame")
	handle.Size = UDim2.fromOffset(10 * scale, 27 * scale)
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.new(0.5, 0, 0, 52 * scale)
	handle.BackgroundColor3 = GRIP
	handle.BorderSizePixel = 0
	handle.Parent = body

	-- Wrapped grip bands.
	for i = 0, 2 do
		local band = Instance.new("Frame")
		band.Size = UDim2.fromOffset(12 * scale, 2 * scale)
		band.AnchorPoint = Vector2.new(0.5, 0)
		band.Position = UDim2.new(0.5, 0, 0, (56 + i * 7) * scale)
		band.BackgroundColor3 = Color3.fromRGB(88, 78, 72)
		band.BorderSizePixel = 0
		band.ZIndex = 2
		band.Parent = body
	end

	-- The ring at the butt of the handle.
	local ring = Instance.new("Frame")
	ring.Size = UDim2.fromOffset(17 * scale, 17 * scale)
	ring.AnchorPoint = Vector2.new(0.5, 0)
	ring.Position = UDim2.new(0.5, 0, 0, 77 * scale)
	ring.BackgroundTransparency = 1
	ring.Parent = body

	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring

	local ringStroke = Instance.new("UIStroke")
	ringStroke.Color = STEEL_DARK
	ringStroke.Thickness = 3 * scale
	ringStroke.Parent = ring

	return body
end

-- === compass ===

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiCompass"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

-- No dial plate and no ring: just the kunai floating on the HUD.
local dial = Instance.new("Frame")
dial.Size = UDim2.fromOffset(92, 92)
dial.AnchorPoint = Vector2.new(0, 0.5)
dial.Position = UDim2.new(0, 20, 0.5, 0)
dial.BackgroundTransparency = 1
dial.BorderSizePixel = 0
dial.Parent = gui

-- Rotating holder. Whatever's inside points up; this is what spins to the bearing.
local needle = Instance.new("Frame")
needle.Size = UDim2.fromScale(1, 1)
needle.BackgroundTransparency = 1
needle.Parent = dial

local kunaiImage: ImageLabel? = nil
local kunaiFrames: { { frame: Frame, base: number } } = {}

-- Snapshot base transparency so dimming can be undone. Reading the current value
-- at dim time would ratchet — once faded it could never come back.
local function collectFrames(drawn: Frame)
	table.clear(kunaiFrames)
	for _, descendant in drawn:GetDescendants() do
		if descendant:IsA("Frame") and descendant.BackgroundTransparency < 1 then
			table.insert(kunaiFrames, { frame = descendant, base = descendant.BackgroundTransparency })
		end
	end
end

if USE_IMAGE then
	kunaiImage = imageKunai(needle, 88)
else
	collectFrames(drawKunai(needle, 0.72))
end

local function setKunaiDim(dim: boolean)
	local image = kunaiImage
	if image then
		image.ImageTransparency = if dim then 0.6 else 0
		-- Slight cool tint when idle, full brightness when it means something.
		image.ImageColor3 = if dim then Color3.fromRGB(150, 158, 172) else Color3.new(1, 1, 1)
		return
	end
	for _, entry in kunaiFrames do
		entry.frame.BackgroundTransparency = if dim then 0.55 else entry.base
	end
end

-- Drop shadow so the icon stays readable against a bright village.
local shadow = Instance.new("UIStroke")
shadow.Color = Color3.fromRGB(10, 12, 16)
shadow.Thickness = 1.5
shadow.Transparency = 0.55
shadow.Parent = needle

-- A freshly uploaded image sits in moderation for a while, and a wrong id fails
-- silently — either way you'd get an invisible compass. Verify it actually loaded
-- and quietly swap back to the drawn shape if it didn't.
if USE_IMAGE then
	task.spawn(function()
		local image = kunaiImage
		if not image then
			return
		end

		pcall(function()
			ContentProvider:PreloadAsync({ image })
		end)

		if image.IsLoaded then
			return
		end

		warn(
			`[QuestCompass] kunai image {GameConfig.KunaiIconId} didn't load `
				.. "(still in moderation, or wrong id) — using the drawn fallback"
		)
		image:Destroy()
		kunaiImage = nil
		collectFrames(drawKunai(needle, 0.72))
		setKunaiDim(not tracking)
	end)
end

local button = Instance.new("TextButton")
button.Size = UDim2.fromScale(1, 1)
button.BackgroundTransparency = 1
button.Text = ""
button.ZIndex = 5
button.Parent = dial

-- Distance readout under the dial.
local distanceLabel = Instance.new("TextLabel")
distanceLabel.Size = UDim2.fromOffset(92, 16)
distanceLabel.AnchorPoint = Vector2.new(0, 0)
distanceLabel.Position = UDim2.new(0, 20, 0.5, 48)
distanceLabel.BackgroundTransparency = 1
distanceLabel.Font = Enum.Font.GothamBold
distanceLabel.Text = ""
distanceLabel.TextSize = 11
distanceLabel.TextColor3 = ACCENT
distanceLabel.TextStrokeTransparency = 0.6
distanceLabel.Parent = gui

-- === mission panel ===

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(268, 0)
panel.AutomaticSize = Enum.AutomaticSize.Y
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Position = UDim2.new(0, 124, 0.5, 0)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = 0.06
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui
corner(panel, 10)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(72, 82, 100)
panelStroke.Thickness = 1
panelStroke.Transparency = 0.4
panelStroke.Parent = panel

local panelPad = Instance.new("UIPadding")
panelPad.PaddingTop = UDim.new(0, 13)
panelPad.PaddingBottom = UDim.new(0, 13)
panelPad.PaddingLeft = UDim.new(0, 14)
panelPad.PaddingRight = UDim.new(0, 14)
panelPad.Parent = panel

local panelList = Instance.new("UIListLayout")
panelList.SortOrder = Enum.SortOrder.LayoutOrder
panelList.Padding = UDim.new(0, 5)
panelList.Parent = panel

local function panelLabel(text: string, size: number, color: Color3, order: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, size + 5)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.Text = text
	l.TextSize = size
	l.TextColor3 = color
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.LayoutOrder = order
	l.Parent = panel
	return l
end

local heading = panelLabel("CURRENT MISSION", 10, MUTED, 1)
heading.Font = Enum.Font.GothamBold

local questName = panelLabel("", 17, TEXT, 2)
questName.Font = Enum.Font.GothamBold
questName.Size = UDim2.new(1, 0, 0, 22)

local locationLine = panelLabel("", 12, ACCENT, 3)
local targetLine = panelLabel("", 12, MUTED, 4)
local progressLine = panelLabel("", 12, GREEN, 5)
local giverLine = panelLabel("", 11, MUTED, 6)

local trackButton = Instance.new("TextButton")
trackButton.Size = UDim2.new(1, 0, 0, 32)
trackButton.BackgroundColor3 = ACCENT
trackButton.BorderSizePixel = 0
trackButton.Font = Enum.Font.GothamBold
trackButton.Text = "Track"
trackButton.TextSize = 13
trackButton.TextColor3 = Color3.fromRGB(20, 16, 12)
trackButton.LayoutOrder = 10
trackButton.Parent = panel
corner(trackButton, 6)

-- === giver marker ===

-- A kunai floating over the NPC who gave the quest, so you know where to go back
-- to. Client-side, so only the tracking player sees it.
local function clearGiverMarker()
	if giverMarker then
		giverMarker:Destroy()
		giverMarker = nil
	end
end

local function placeGiverMarker(giverId: string)
	clearGiverMarker()

	local model = Workspace:FindFirstChild(giverId)
	if not model or not model:IsA("Model") then
		return
	end
	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not anchor then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "QuestGiverMarker"
	billboard.Size = UDim2.fromOffset(60, 90)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 8.5, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 700
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 0.74)
	holder.BackgroundTransparency = 1
	holder.Parent = billboard

	-- Point down at the NPC's head.
	if USE_IMAGE then
		local icon = imageKunai(holder, 54)
		icon.Rotation = GameConfig.KunaiIconBaseRotation + 180
	else
		local marker = drawKunai(holder, 0.52)
		marker.Rotation = 180
	end

	local caption = Instance.new("TextLabel")
	caption.Size = UDim2.new(1, 0, 0.26, 0)
	caption.Position = UDim2.fromScale(0, 0.74)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamBold
	caption.Text = "MISSION"
	caption.TextSize = 11
	caption.TextColor3 = ACCENT
	caption.TextStrokeTransparency = 0.5
	caption.Parent = billboard

	-- Gentle bob, so it catches the eye in a busy street.
	TweenService:Create(
		holder,
		TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromScale(0, 0.07) }
	):Play()

	giverMarker = billboard
end

-- === rendering ===

local function setTracking(value: boolean)
	tracking = value and active ~= nil

	if tracking then
		trackButton.Text = "Tracking  ·  tap to stop"
		trackButton.BackgroundColor3 = PANEL
		trackButton.TextColor3 = GREEN
		setKunaiDim(false)

		local current = active
		if current and current.giverId then
			placeGiverMarker(current.giverId)
		end
	else
		trackButton.Text = "Track"
		trackButton.BackgroundColor3 = ACCENT
		trackButton.TextColor3 = Color3.fromRGB(20, 16, 12)
		-- Idle points straight up rather than holding a stale bearing.
		needle.Rotation = 0
		distanceLabel.Text = ""
		setKunaiDim(true)
		clearGiverMarker()
	end
end

local function renderPanel()
	local current = active

	if not current then
		questName.Text = "No active mission"
		locationLine.Text = "Visit a mission board"
		targetLine.Text = ""
		progressLine.Text = ""
		giverLine.Text = ""
		trackButton.Visible = false
		return
	end

	trackButton.Visible = true
	questName.Text = current.name
	locationLine.Text = `Location  ·  {current.areaName}`
	targetLine.Text = `Target  ·  {current.targetName}  (Lv {current.targetLevel})`
	progressLine.Text = `Progress  ·  {current.progress}/{current.killCount}`
	giverLine.Text = if current.giverName then `Given by {current.giverName}` else ""
end

button.Activated:Connect(function()
	panel.Visible = not panel.Visible
	if panel.Visible then
		renderPanel()
	end
end)

trackButton.Activated:Connect(function()
	setTracking(not tracking)
end)

Remotes.Events.QuestUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	local incoming = payload.active
	local previousId = if active then active.id else nil

	if type(incoming) == "table" then
		active = incoming :: Active
		-- Keep tracking across progress updates, but a different quest starts
		-- untracked so the compass never silently points somewhere unexpected.
		if incoming.id ~= previousId then
			setTracking(false)
		elseif tracking and incoming.giverId then
			placeGiverMarker(incoming.giverId)
		end
	else
		active = nil
		setTracking(false)
	end

	-- Faded unless it's actively pointing somewhere.
	setKunaiDim(not tracking)

	if panel.Visible then
		renderPanel()
	end
end)

-- Bearing update. Camera-relative: rotation 0 means "straight ahead", which is
-- what a player actually wants from a tracker.
RunService.RenderStepped:Connect(function()
	if not tracking then
		return
	end

	local current = active
	local target = current and current.zonePosition
	if not target then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return
	end

	local toTarget = target - root.Position
	local flat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flat.Magnitude < 1 then
		return
	end
	flat = flat.Unit

	local look = camera.CFrame.LookVector
	local camFlat = Vector3.new(look.X, 0, look.Z)
	if camFlat.Magnitude < 0.01 then
		return
	end
	camFlat = camFlat.Unit

	-- Signed angle about +Y. Negated because Roblox UI Rotation is clockwise while
	-- a positive rotation about +Y is counter-clockwise seen from above — without
	-- the flip the needle points at the mirror image of the objective.
	local dot = camFlat:Dot(flat)
	local crossY = camFlat.Z * flat.X - camFlat.X * flat.Z
	needle.Rotation = -math.deg(math.atan2(crossY, dot))

	distanceLabel.Text = `{math.floor(toTarget.Magnitude)} studs`
end)

-- Start dimmed: no quest is known until the server's first push.
setKunaiDim(true)
renderPanel()
