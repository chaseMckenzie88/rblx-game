--!strict
-- Shared NPC rig builder. Both the Nature Elder and the quest giver need the
-- same body + nameplate + ProximityPrompt, so it lives here once.
--
-- Built from code because the Rojo pipeline owns code only. Swap in real models
-- in Studio later — callers only touch the returned root and prompt.

local Workspace = game:GetService("Workspace")

local NPCBuilder = {}

export type Config = {
	name: string,
	displayName: string,
	actionText: string,
	robeColor: Color3,
	titleColor: Color3,
	-- Drop a part with this name in Workspace to position the NPC by hand.
	markerName: string,
	fallbackPosition: Vector3,
}

export type NPC = {
	model: Model,
	root: BasePart,
	prompt: ProximityPrompt,
}

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function resolvePosition(config: Config): Vector3
	local marker = Workspace:FindFirstChild(config.markerName)
	if marker and marker:IsA("BasePart") then
		return marker.Position + Vector3.new(0, 3, 0)
	end
	return config.fallbackPosition
end

function NPCBuilder.build(config: Config): NPC
	local origin = resolvePosition(config)

	local model = Instance.new("Model")
	model.Name = config.name

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(60, 70, 90), model)
	root.Transparency = 1
	root.CFrame = CFrame.new(origin)

	local robe = part("Torso", Vector3.new(2.2, 2.4, 1.1), config.robeColor, model)
	robe.CFrame = CFrame.new(origin)

	local head = part("Head", Vector3.new(1.3, 1.3, 1.3), Color3.fromRGB(225, 200, 165), model)
	head.CFrame = CFrame.new(origin + Vector3.new(0, 1.9, 0))

	model.PrimaryPart = root
	model.Parent = Workspace

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 26)
	sign.StudsOffsetWorldSpace = Vector3.new(0, 3.6, 0)
	sign.AlwaysOnTop = true
	sign.MaxDistance = 120
	sign.Adornee = root
	sign.Parent = root

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = config.displayName
	title.TextSize = 14
	title.TextColor3 = config.titleColor
	title.TextStrokeTransparency = 0.5
	title.Parent = sign

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = config.actionText
	prompt.ObjectText = config.displayName
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root

	return { model = model, root = root, prompt = prompt }
end

return NPCBuilder
