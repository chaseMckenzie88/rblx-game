--!strict
-- Per-building clutter. This module is the entire difference between a grey-box
-- and Konoha, and it is worth the part budget.
--
-- Everything the reference art actually shows, in rough order of how much it
-- matters to the silhouette:
--   1. rooftop water tanks — cylinders on stilts, the single most distinctive
--      thing about Konoha's skyline
--   2. hanging vertical kanji shop signs
--   3. awnings over shopfronts
--   4. louvered window shutters
--   5. drainpipes, AC boxes, roof vents
--   6. power poles with slung wires between them
--   7. balconies and exterior stairs
--
-- Every function takes a CFrame in the building's local frame, so details rotate
-- with the building they're attached to.

local Builder = require(script.Parent.Builder)

local Details = {}

-- Shop kanji seen on the reference signage. Mixed shops, food, bath, smithy.
Details.ShopKanji = {
	"炭火焼", "一楽", "呉服", "天", "しち", "湯", "茶", "酒",
	"麺", "魚", "米", "花", "本", "薬", "鍛冶", "金", "文", "菓子",
}

Details.Colors = {
	Tank = Color3.fromRGB(168, 172, 176),
	TankDark = Color3.fromRGB(132, 136, 142),
	Metal = Color3.fromRGB(142, 146, 152),
	Pipe = Color3.fromRGB(158, 160, 158),
	SignBoard = Color3.fromRGB(242, 236, 220),
	SignRed = Color3.fromRGB(186, 58, 46),
	SignDark = Color3.fromRGB(58, 48, 42),
	Wood = Color3.fromRGB(126, 92, 62),
	WoodDark = Color3.fromRGB(88, 62, 42),
	Shutter = Color3.fromRGB(150, 168, 138),
	Lantern = Color3.fromRGB(240, 214, 152),
	Wire = Color3.fromRGB(42, 42, 46),
	Cloth = Color3.fromRGB(214, 96, 78),
}

local C = Details.Colors

-- ============================================================ rooftop

-- Cylindrical tank on four stilts. Konoha's rooftops are covered in these.
function Details.waterTank(parent: Instance, at: CFrame, scale: number)
	local legHeight = 5 * scale
	local diameter = 13 * scale
	local tankHeight = 11 * scale

	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Builder.tube(
				parent,
				"TankLeg",
				at * CFrame.new(sx * diameter * 0.3, legHeight / 2, sz * diameter * 0.3),
				1.4 * scale,
				legHeight,
				C.TankDark,
				{ material = Enum.Material.Metal }
			)
		end
	end

	Builder.cylinder(
		parent,
		"Tank",
		at * CFrame.new(0, legHeight + tankHeight / 2, 0),
		diameter,
		tankHeight,
		C.Tank,
		{ material = Enum.Material.Metal }
	)
	-- Banding ribs, so it doesn't read as a plain can.
	for i = 1, 2 do
		Builder.cylinder(
			parent,
			"TankBand",
			at * CFrame.new(0, legHeight + tankHeight * (i / 3), 0),
			diameter + 0.8,
			1 * scale,
			C.TankDark,
			{ material = Enum.Material.Metal }
		)
	end
	-- Domed lid.
	Builder.cylinder(
		parent,
		"TankLid",
		at * CFrame.new(0, legHeight + tankHeight + 1, 0),
		diameter * 0.72,
		2.4 * scale,
		C.TankDark,
		{ material = Enum.Material.Metal }
	)
end

function Details.roofVent(parent: Instance, at: CFrame, scale: number)
	Builder.block(
		parent,
		"VentBox",
		at * CFrame.new(0, 2.4 * scale, 0),
		Vector3.new(9 * scale, 5 * scale, 7 * scale),
		C.Metal,
		{ material = Enum.Material.CorrodedMetal }
	)
	Builder.tube(
		parent,
		"VentPipe",
		at * CFrame.new(0, 8 * scale, 0),
		2.6 * scale,
		7 * scale,
		C.Pipe,
		{ material = Enum.Material.Metal }
	)
end

function Details.chimney(parent: Instance, at: CFrame, height: number)
	Builder.block(
		parent,
		"Chimney",
		at * CFrame.new(0, height / 2, 0),
		Vector3.new(7, height, 7),
		Color3.fromRGB(148, 122, 104),
		{ material = Enum.Material.Brick }
	)
	Builder.block(
		parent,
		"ChimneyCap",
		at * CFrame.new(0, height + 1, 0),
		Vector3.new(9.5, 2, 9.5),
		Color3.fromRGB(112, 92, 78),
		{ material = Enum.Material.Slate }
	)
end

-- Antenna mast — the reference skyline has these poking up everywhere.
function Details.antenna(parent: Instance, at: CFrame, height: number)
	Builder.tube(parent, "Mast", at * CFrame.new(0, height / 2, 0), 1.1, height, C.Metal)
	for i = 1, 3 do
		Builder.block(
			parent,
			"Crossbar",
			at * CFrame.new(0, height * (0.45 + i * 0.16), 0),
			Vector3.new(7 - i * 1.4, 0.5, 0.5),
			C.Metal,
			{ collide = false }
		)
	end
end

-- ============================================================ signage

-- Vertical hanging board with kanji running down it. The most recognisable piece
-- of Konoha street dressing after the water tanks.
function Details.hangingSign(parent: Instance, at: CFrame, kanji: string, boardColor: Color3?)
	local height = 26
	local width = 11

	-- Bracket out from the wall.
	Builder.block(parent, "SignArm", at * CFrame.new(0, 2, -2.5), Vector3.new(1.2, 1.2, 6), C.Metal)

	local board = Builder.block(
		parent,
		"SignBoard",
		at * CFrame.new(0, -height / 2, 0),
		Vector3.new(width, height, 1.2),
		boardColor or C.SignBoard,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)

	-- Kanji on both faces so it reads walking either way down the street.
	Builder.surfaceText(board, Enum.NormalId.Front, kanji, C.SignRed, 0.82)
	Builder.surfaceText(board, Enum.NormalId.Back, kanji, C.SignRed, 0.82)

	-- Dark frame edges.
	for _, sx in { -1, 1 } do
		Builder.block(
			parent,
			"SignEdge",
			at * CFrame.new(sx * width / 2, -height / 2, 0),
			Vector3.new(1, height, 1.6),
			C.SignDark,
			{ material = Enum.Material.Wood, collide = false }
		)
	end
end

-- Horizontal board over a doorway.
function Details.wallSign(parent: Instance, at: CFrame, text: string, width: number)
	local board = Builder.block(
		parent,
		"WallSign",
		at,
		Vector3.new(width, 11, 1.2),
		C.SignDark,
		{ material = Enum.Material.WoodPlanks, collide = false }
	)
	Builder.surfaceText(board, Enum.NormalId.Front, text, C.SignBoard, 0.8)
end

-- The circular 忍 crest — Academy and official buildings.
--
-- `at` should be an unrotated frame sitting just off the wall; the crest faces +Z.
-- The ring needs CFrame.Angles(-90°, 0, 0) because Builder.cylinder stands its
-- axis along the frame's UP vector — without it the disc renders edge-on to the
-- viewer instead of facing them.
function Details.crest(parent: Instance, at: CFrame, diameter: number, ringColor: Color3)
	Builder.cylinder(
		parent,
		"CrestRing",
		at * CFrame.Angles(math.rad(-90), 0, 0),
		diameter,
		1.6,
		ringColor,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	local face = Builder.block(
		parent,
		"CrestFace",
		at * CFrame.new(0, 0, 0.9),
		Vector3.new(diameter * 0.72, diameter * 0.72, 0.8),
		C.SignBoard,
		{ material = Enum.Material.SmoothPlastic, collide = false }
	)
	Builder.surfaceText(face, Enum.NormalId.Front, "忍", C.SignRed, 0.9)
end

-- ============================================================ facade

-- Sloped shopfront awning. Also a mid-height parkour step off the street.
function Details.awning(parent: Instance, at: CFrame, width: number, color: Color3)
	Builder.block(
		parent,
		"Awning",
		at * CFrame.Angles(math.rad(-22), 0, 0),
		Vector3.new(width, 1, 11),
		color,
		{ material = Enum.Material.Fabric }
	)
	-- Valance strip along the front edge.
	Builder.block(
		parent,
		"AwningTrim",
		at * CFrame.new(0, -2.6, 5.2),
		Vector3.new(width, 3, 0.8),
		color,
		{ material = Enum.Material.Fabric, collide = false }
	)
	for _, sx in { -1, 1 } do
		Builder.tube(
			parent,
			"AwningStay",
			at * CFrame.new(sx * width / 2, -1.4, 2.6) * CFrame.Angles(0, 0, math.rad(90)),
			0.7,
			6,
			C.Metal
		)
	end
end

-- Louvered shutters flanking a window. Reference art is full of these.
function Details.shutters(parent: Instance, at: CFrame, width: number, height: number)
	for _, sx in { -1, 1 } do
		local panel = Builder.block(
			parent,
			"Shutter",
			at * CFrame.new(sx * (width / 2 + 2.4), 0, 0.3),
			Vector3.new(4.4, height, 0.7),
			C.Shutter,
			{ material = Enum.Material.WoodPlanks, collide = false }
		)
		-- Louver slats.
		local slats = math.max(2, math.floor(height / 3))
		for i = 0, slats - 1 do
			Builder.block(
				parent,
				"Slat",
				panel.CFrame * CFrame.new(0, height / 2 - (i + 0.5) * (height / slats), 0.5),
				Vector3.new(4, height / slats * 0.6, 0.3),
				Color3.fromRGB(118, 134, 108),
				{ material = Enum.Material.Wood, collide = false }
			)
		end
	end
end

function Details.drainpipe(parent: Instance, at: CFrame, height: number)
	Builder.tube(parent, "Drainpipe", at * CFrame.new(0, height / 2, 0), 2, height, C.Pipe)
	-- Collar brackets.
	for i = 1, math.max(1, math.floor(height / 16)) do
		Builder.block(
			parent,
			"PipeCollar",
			at * CFrame.new(0, i * 16, 0),
			Vector3.new(3, 1, 3),
			C.Metal,
			{ collide = false }
		)
	end
end

function Details.acUnit(parent: Instance, at: CFrame)
	Builder.block(
		parent,
		"ACBox",
		at,
		Vector3.new(7, 5.5, 4),
		C.Metal,
		{ material = Enum.Material.CorrodedMetal, collide = false }
	)
	Builder.cylinder(
		parent,
		"ACFan",
		at * CFrame.new(0, 0, -2.2),
		4,
		0.6,
		Color3.fromRGB(84, 86, 90),
		{ material = Enum.Material.Metal, collide = false }
	)
end

function Details.balcony(parent: Instance, at: CFrame, width: number)
	Builder.block(
		parent,
		"BalconyFloor",
		at,
		Vector3.new(width, 1, 9),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	-- Railing: top rail plus balusters.
	Builder.block(
		parent,
		"BalconyRail",
		at * CFrame.new(0, 5, 4.2),
		Vector3.new(width, 0.9, 0.9),
		C.WoodDark,
		{ material = Enum.Material.Wood, collide = false }
	)
	local posts = math.max(3, math.floor(width / 6))
	for i = 0, posts - 1 do
		Builder.block(
			parent,
			"Baluster",
			at * CFrame.new(-width / 2 + (i + 0.5) * (width / posts), 2.6, 4.2),
			Vector3.new(0.7, 5, 0.7),
			C.WoodDark,
			{ material = Enum.Material.Wood, collide = false }
		)
	end
end

-- Switchback exterior stair. Reads as lived-in, and doubles as a climb route.
function Details.exteriorStairs(parent: Instance, at: CFrame, height: number)
	local steps = math.max(4, math.floor(height / 2.6))
	local run = 15

	for i = 0, steps - 1 do
		local t = i / steps
		Builder.block(
			parent,
			"Step",
			at * CFrame.new(0, height * t + 1, -run * t),
			Vector3.new(9, 1.2, run / steps + 1.6),
			C.Wood,
			{ material = Enum.Material.WoodPlanks }
		)
	end
	-- Rail pitched to match the stair. math.atan already returns radians, so
	-- feeding it straight to CFrame.Angles is correct.
	Builder.block(
		parent,
		"StairRail",
		at * CFrame.new(4.5, height * 0.5 + 5, -run * 0.5)
			* CFrame.Angles(math.atan(height / run), 0, 0),
		Vector3.new(0.8, 0.8, math.sqrt(height * height + run * run)),
		C.WoodDark,
		{ material = Enum.Material.Wood, collide = false }
	)
end

function Details.lantern(parent: Instance, at: CFrame)
	Builder.block(parent, "LanternArm", at * CFrame.new(0, 1, -1.6), Vector3.new(0.8, 0.8, 4), C.Metal)
	local body = Builder.cylinder(
		parent,
		"Lantern",
		at * CFrame.new(0, -3, 0),
		6,
		8,
		C.Lantern,
		{ material = Enum.Material.Neon, collide = false }
	)
	local light = Instance.new("PointLight")
	light.Brightness = 1.1
	light.Range = 22
	light.Color = Color3.fromRGB(255, 208, 140)
	light.Parent = body
end

-- Cloth noren curtain in a doorway.
function Details.noren(parent: Instance, at: CFrame, width: number)
	local cloth = Builder.block(
		parent,
		"Noren",
		at,
		Vector3.new(width, 8, 0.5),
		C.Cloth,
		{ material = Enum.Material.Fabric, collide = false }
	)
	Builder.surfaceText(cloth, Enum.NormalId.Front, "麺", C.SignBoard, 0.7)
end

-- ============================================================ street

-- Power pole with crossarms. Wires are strung separately by VillageService so it
-- can connect consecutive poles.
function Details.powerPole(parent: Instance, at: CFrame, height: number): Vector3
	Builder.tube(parent, "Pole", at * CFrame.new(0, height / 2, 0), 3.2, height, C.WoodDark, {
		material = Enum.Material.Wood,
		collide = true,
	})

	for i = 0, 1 do
		local y = height - 6 - i * 7
		Builder.block(
			parent,
			"Crossarm",
			at * CFrame.new(0, y, 0),
			Vector3.new(20, 1.4, 1.4),
			C.WoodDark,
			{ material = Enum.Material.Wood, collide = false }
		)
		for _, sx in { -1, 1 } do
			Builder.cylinder(
				parent,
				"Insulator",
				at * CFrame.new(sx * 8, y + 1.6, 0),
				2,
				2.4,
				Color3.fromRGB(96, 108, 96),
				{ material = Enum.Material.Glass, collide = false }
			)
		end
	end

	return (at * CFrame.new(0, height - 6, 0)).Position
end

-- A slung wire between two points, with a little sag.
function Details.wire(parent: Instance, from: Vector3, to: Vector3)
	local segments = 4
	local sag = 4

	for i = 0, segments - 1 do
		local t0 = i / segments
		local t1 = (i + 1) / segments

		local function pointAt(t: number): Vector3
			local flat = from:Lerp(to, t)
			-- Parabolic droop, zero at both ends.
			return flat - Vector3.new(0, sag * math.sin(t * math.pi), 0)
		end

		local a, b = pointAt(t0), pointAt(t1)
		local mid = (a + b) / 2
		local length = (b - a).Magnitude

		Builder.block(
			parent,
			"Wire",
			CFrame.lookAt(mid, b),
			Vector3.new(0.35, 0.35, length),
			C.Wire,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
end

-- Market stall: frame, striped canopy, produce crates.
function Details.marketStall(parent: Instance, at: CFrame, canopyColor: Color3)
	Builder.block(
		parent,
		"StallCounter",
		at * CFrame.new(0, 4, 0),
		Vector3.new(20, 8, 11),
		C.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, sx in { -1, 1 } do
		Builder.tube(parent, "StallPost", at * CFrame.new(sx * 9, 8, 0), 1.2, 16, C.WoodDark, {
			material = Enum.Material.Wood,
		})
	end
	Builder.block(
		parent,
		"StallCanopy",
		at * CFrame.new(0, 16, 0),
		Vector3.new(24, 1, 15),
		canopyColor,
		{ material = Enum.Material.Fabric }
	)
	for i = 0, 2 do
		Builder.block(
			parent,
			"Crate",
			at * CFrame.new(-6 + i * 6, 9.4, 1),
			Vector3.new(5, 3, 5),
			Color3.fromRGB(146, 112, 74),
			{ material = Enum.Material.WoodPlanks, collide = false }
		)
	end
end

return Details
