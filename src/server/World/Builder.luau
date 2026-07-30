--!strict
-- Geometry primitives for the village.
--
-- Scale reference: a Roblox character is ~5 studs tall ≈ 1.7 m, so 1 stud ≈ 0.34 m
-- (near enough to a foot). Every dimension in the village config is chosen from
-- that, which is what makes the place feel real to walk through rather than
-- toy-sized. See Village.luau for the derived constants.
--
-- Performance rules baked in here, because a 200-building map on a GTX 1660 Super
-- lives or dies on them:
--   · everything Anchored — no physics solver work at all
--   · CastShadow off by default; only landmarks opt in
--   · no unions or CSG, no MeshParts, no decals
--   · parts grouped per district so streaming can cull whole neighbourhoods

local Builder = {}

export type Opts = {
	material: Enum.Material?,
	transparency: number?,
	castShadow: boolean?,
	reflectance: number?,
	shape: Enum.PartType?,
	collide: boolean?,
}

-- Shared defaults. Passing nothing gets you a cheap, anchored, shadowless part.
local function apply(p: BasePart, color: Color3, opts: Opts?)
	local o = opts or {}
	p.Anchored = true
	p.Color = color
	p.Material = o.material or Enum.Material.Concrete
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.CastShadow = o.castShadow == true
	p.CanCollide = o.collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Query/touch off where possible: fewer things for the spatial hash to track.
	p.CanTouch = false
end

function Builder.block(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	if opts and opts.shape then
		p.Shape = opts.shape
	end
	apply(p, color, opts)
	p.Parent = parent
	return p
end

function Builder.cylinder(
	parent: Instance,
	name: string,
	cf: CFrame,
	diameter: number,
	height: number,
	color: Color3,
	opts: Opts?
): Part
	-- A Cylinder part's X axis is its length, so the CFrame is rotated to stand it
	-- upright and Size is (height, diameter, diameter).
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(height, diameter, diameter)
	p.CFrame = cf * CFrame.Angles(0, 0, math.rad(90))
	apply(p, color, opts)
	p.Parent = parent
	return p
end

function Builder.wedge(
	parent: Instance,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	opts: Opts?
): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	apply(p, color, opts)
	p.Parent = parent
	return p
end

-- Two wedges back to back. Konoha's older quarters are all pitched tile roofs.
function Builder.pitchedRoof(
	parent: Instance,
	origin: CFrame,
	width: number,
	depth: number,
	height: number,
	color: Color3
)
	local half = width / 2
	local opts: Opts = { material = Enum.Material.Slate }

	Builder.wedge(
		parent,
		"RoofL",
		origin * CFrame.new(-half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Vector3.new(depth, height, half),
		color,
		opts
	)
	Builder.wedge(
		parent,
		"RoofR",
		origin * CFrame.new(half / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0),
		Vector3.new(depth, height, half),
		color,
		opts
	)
end

-- Stepped cone. Cheaper and more reliable than trying to fake a smooth cone from
-- primitives, and at play distance the stepping reads as tiled eaves.
function Builder.coneRoof(
	parent: Instance,
	origin: CFrame,
	baseDiameter: number,
	height: number,
	color: Color3,
	steps: number?
)
	local n = steps or 4
	local stepHeight = height / n

	for i = 0, n - 1 do
		local t = i / n
		local diameter = baseDiameter * (1 - t * 0.82)
		Builder.cylinder(
			parent,
			`Cone{i}`,
			origin * CFrame.new(0, stepHeight * i + stepHeight / 2, 0),
			diameter,
			stepHeight,
			color,
			{ material = Enum.Material.Slate }
		)
	end
end

-- Flat overhanging eaves — the single cheapest thing that stops a box looking
-- like a box.
function Builder.eaves(
	parent: Instance,
	origin: CFrame,
	width: number,
	depth: number,
	color: Color3
)
	Builder.block(
		parent,
		"Eaves",
		origin,
		Vector3.new(width + 3, 0.8, depth + 3),
		color,
		{ material = Enum.Material.Slate }
	)
end

-- Windows as thin emissive-ish panels rather than real holes: no CSG, and they
-- read well at night once lighting is in.
function Builder.windowStrip(
	parent: Instance,
	origin: CFrame,
	width: number,
	height: number,
	count: number,
	color: Color3
)
	if count < 1 then
		return
	end
	local spacing = width / count

	for i = 0, count - 1 do
		local x = -width / 2 + spacing * (i + 0.5)
		Builder.block(
			parent,
			"Window",
			origin * CFrame.new(x, 0, 0),
			Vector3.new(spacing * 0.5, height, 0.4),
			color,
			{
				material = Enum.Material.Glass,
				reflectance = 0.15,
				collide = false,
			}
		)
	end
end

-- Text on a surface. Used for the 火 on the Hokage Tower and the gate sign —
-- crisp, free, and instantly recognisable without any image assets.
function Builder.surfaceText(
	host: BasePart,
	face: Enum.NormalId,
	text: string,
	color: Color3,
	scale: number?
)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.CanvasSize = Vector2.new(200, 200)
	sg.LightInfluence = 0
	sg.Parent = host

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(scale or 1, scale or 1)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = sg
end

-- A pipe/rod at any orientation. Drainpipes, railings, antennae, tank legs.
function Builder.tube(
	parent: Instance,
	name: string,
	cf: CFrame,
	diameter: number,
	length: number,
	color: Color3,
	opts: Opts?
): Part
	local merged: Opts = {
		material = (opts and opts.material) or Enum.Material.Metal,
		-- Default non-colliding: pipes, railings and wires shouldn't snag the
		-- player. `if opts then opts.collide` would read a missing field as nil,
		-- which apply() treats as "collide", so test for nil explicitly.
		collide = if opts and opts.collide ~= nil then opts.collide else false,
		transparency = opts and opts.transparency,
		reflectance = opts and opts.reflectance,
	}
	return Builder.cylinder(parent, name, cf, diameter, length, color, merged)
end

function Builder.sphere(
	parent: Instance,
	name: string,
	position: Vector3,
	diameter: number,
	color: Color3,
	opts: Opts?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.new(diameter, diameter, diameter)
	p.CFrame = CFrame.new(position)
	apply(p, color, opts)
	p.Parent = parent
	return p
end

-- Stacked pagoda roof: several diminishing hipped tiers. This is the Academy and
-- the temple silhouette — wide overhangs, each tier smaller than the last.
function Builder.tieredRoof(
	parent: Instance,
	base: CFrame,
	width: number,
	depth: number,
	tiers: number,
	tierHeight: number,
	roofColor: Color3,
	wallColor: Color3
)
	for i = 0, tiers - 1 do
		local shrink = 1 - (i / tiers) * 0.55
		local w = width * shrink
		local d = depth * shrink
		local y = i * tierHeight

		-- Wall band for the storey.
		Builder.block(
			parent,
			`TierWall{i}`,
			base * CFrame.new(0, y + tierHeight * 0.42, 0),
			Vector3.new(w * 0.92, tierHeight * 0.84, d * 0.92),
			wallColor,
			{ material = Enum.Material.Plaster }
		)

		-- Wide overhanging eave slab — the defining feature.
		Builder.block(
			parent,
			`TierEave{i}`,
			base * CFrame.new(0, y + tierHeight * 0.9, 0),
			Vector3.new(w + 14, 1.6, d + 14),
			roofColor,
			{ material = Enum.Material.Slate }
		)
		-- Slight second lip for thickness.
		Builder.block(
			parent,
			`TierLip{i}`,
			base * CFrame.new(0, y + tierHeight * 0.98, 0),
			Vector3.new(w + 8, 1.4, d + 8),
			roofColor,
			{ material = Enum.Material.Slate }
		)
	end
end

-- Curved ridge horns. Japanese roofs turn up at the ends, and faking it with two
-- small angled blocks per corner is the cheapest big win on silhouette.
function Builder.ridgeHooks(
	parent: Instance,
	base: CFrame,
	width: number,
	depth: number,
	y: number,
	color: Color3
)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local corner = base * CFrame.new(sx * width / 2, y, sz * depth / 2)
			Builder.block(
				parent,
				"Horn",
				corner * CFrame.Angles(0, 0, math.rad(sx * -28)),
				Vector3.new(9, 2, 3),
				color,
				{ material = Enum.Material.Slate, collide = false }
			)
			Builder.block(
				parent,
				"HornTip",
				corner * CFrame.new(sx * 4, 2.4, 0),
				Vector3.new(3, 3.4, 3),
				color,
				{ material = Enum.Material.Slate, collide = false }
			)
		end
	end
end

-- A grouped model, so districts can be streamed and culled as units.
function Builder.group(name: string, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Pin a model's PrimaryPart so it can be moved as one piece later in Studio.
function Builder.anchorModel(model: Model, primary: BasePart)
	model.PrimaryPart = primary
end

return Builder
