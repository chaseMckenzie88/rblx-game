--!strict
-- Builds Konohagakure from Village.luau.
--
-- Fixed seed, so the village is identical on every run. Delete Workspace/Konoha
-- and press Play to regenerate.
--
-- Structure of the build:
--   Builder     — raw primitives (blocks, cylinders, roofs, surface text)
--   Details     — clutter (water tanks, hanging signs, awnings, pipes, wires)
--   Structures  — archetypes (shophouse, round tower, pagoda, Hokage Tower, gate)
--   this file   — layout, packing, streets, zones
--
-- Part budget is real. Every building carries 25-45 parts once detailed, so the
-- village lands around 18-22k parts. StreamingEnabled (Game Settings → World)
-- is what makes that fine. Village.Detail scales the clutter if it isn't.

local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage.Shared
local Village = require(Shared.Config.Village)

local Builder = require(script.Parent.Builder)
local Details = require(script.Parent.Details)
local Structures = require(script.Parent.Structures)

local VillageService = {}

local P = Village.Palette
local STOREY = Village.StoreyHeight

local root: Folder
local rng = Random.new(Village.Seed)

type Rect = { minX: number, maxX: number, minZ: number, maxZ: number }
local claimed: { Rect } = {}

local function claim(centerX: number, centerZ: number, width: number, depth: number, pad: number)
	table.insert(claimed, {
		minX = centerX - width / 2 - pad,
		maxX = centerX + width / 2 + pad,
		minZ = centerZ - depth / 2 - pad,
		maxZ = centerZ + depth / 2 + pad,
	})
end

local function isFree(centerX: number, centerZ: number, width: number, depth: number): boolean
	local minX, maxX = centerX - width / 2, centerX + width / 2
	local minZ, maxZ = centerZ - depth / 2, centerZ + depth / 2

	for _, r in claimed do
		if minX < r.maxX and maxX > r.minX and minZ < r.maxZ and maxZ > r.minZ then
			return false
		end
	end
	return true
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- Trim is a darkened wall colour: plinths, window frames, banding. Deriving it
-- rather than configuring it keeps every building internally consistent.
local function trimOf(wall: Color3): Color3
	return Color3.new(wall.R * 0.68, wall.G * 0.64, wall.B * 0.6)
end

-- ============================================================ ground

local function buildGround()
	local folder = Builder.group("Ground", root)

	Builder.block(
		folder,
		"Basin",
		CFrame.new(0, -4, -200),
		Vector3.new(5200, 8, 5200),
		P.Grass,
		{ material = Enum.Material.Grass }
	)

	Builder.cylinder(
		folder,
		"VillageFloor",
		CFrame.new(0, -1, 0),
		Village.WallRadius * 2 + 60,
		4,
		P.Sand,
		{ material = Enum.Material.Ground }
	)

	-- Reserve the plaza before any district runs, or buildings land on the NPCs.
	claim(Village.PlazaPosition.X, Village.PlazaPosition.Z, 260, 260, 0)

	-- Reserve the main-street verge too. Street furniture is placed *after* the
	-- districts, so without this the power poles, stalls and lanterns end up
	-- buried inside shopfronts.
	claim(0, 260, 62, 1240, 0)
end

-- ============================================================ roads

local function buildRoads()
	local folder = Builder.group("Roads", root)

	for index, road in Village.Roads do
		local delta = road.to - road.from
		local length = delta.Magnitude
		local center = road.from + delta * 0.5
		local angle = math.atan2(delta.X, delta.Z)
		local cf = CFrame.new(Vector3.new(center.X, 0.6, center.Z)) * CFrame.Angles(0, angle, 0)

		Builder.block(
			folder,
			`Road{index}`,
			cf,
			Vector3.new(road.width, 1.2, length),
			P.Road,
			{ material = Enum.Material.Pebble }
		)

		-- Kerbs only on the wider streets; alleys are just packed dirt.
		if road.width >= 14 then
			for _, side in { -1, 1 } do
				Builder.block(
					folder,
					`Kerb{index}`,
					cf * CFrame.new(side * (road.width / 2 + 1), 0.6, 0),
					Vector3.new(2, 1.6, length),
					P.RoadEdge,
					{ material = Enum.Material.Concrete }
				)
			end
		end

		claim(
			center.X,
			center.Z,
			math.abs(delta.X) + road.width + 8,
			math.abs(delta.Z) + road.width + 8,
			0
		)
	end
end

-- ============================================================ wall + gates

local function buildWall()
	local folder = Builder.group("Wall", root)
	local radius = Village.WallRadius
	local height = Village.WallHeight

	local openings: { { center: number, half: number } } = {}
	for _, gate in Village.Gates do
		table.insert(openings, {
			center = math.rad(gate.angle),
			half = (gate.width / 2 + 26) / radius,
		})
	end

	local segments = 190
	local step = (math.pi * 2) / segments
	local segmentLength = (math.pi * 2 * radius) / segments + 2

	for i = 0, segments - 1 do
		local theta = i * step

		local skip = false
		for _, opening in openings do
			local diff = math.abs(((theta - opening.center + math.pi) % (math.pi * 2)) - math.pi)
			if diff < opening.half then
				skip = true
				break
			end
		end
		if skip then
			continue
		end

		local x = math.sin(theta) * radius
		local z = math.cos(theta) * radius
		local cf = CFrame.new(x, height / 2, z) * CFrame.Angles(0, theta, 0)

		-- Vertical plank cladding, matching the timber wall in the gate reference.
		Builder.block(
			folder,
			"Wall",
			cf,
			Vector3.new(segmentLength, height, Village.WallThickness),
			P.Wood,
			{ material = Enum.Material.WoodPlanks }
		)
		Builder.block(
			folder,
			"WallBase",
			cf * CFrame.new(0, -height / 2 + 8, 0),
			Vector3.new(segmentLength, 16, Village.WallThickness + 4),
			P.WallStone,
			{ material = Enum.Material.Slate }
		)
		Builder.block(
			folder,
			"Parapet",
			cf * CFrame.new(0, height / 2 + 2, 0),
			Vector3.new(segmentLength, 4, Village.WallThickness + 6),
			P.WallTrim,
			{ material = Enum.Material.Concrete }
		)
	end

	for _, gate in Village.Gates do
		local theta = math.rad(gate.angle)
		local at = CFrame.new(math.sin(theta) * radius, 0, math.cos(theta) * radius)
			* CFrame.Angles(0, theta, 0)

		if gate.id == "SouthMain" then
			Structures.mainGate(folder, at, gate.width)
		else
			-- Side gates: simpler posts and a plain lintel.
			for _, sx in { -1, 1 } do
				Builder.block(
					folder,
					"SideGatePost",
					at * CFrame.new(sx * (gate.width / 2 + 8), (height + 12) / 2, 0),
					Vector3.new(14, height + 12, Village.WallThickness + 8),
					P.WallStone,
					{ material = Enum.Material.Concrete }
				)
			end
			Builder.block(
				folder,
				"SideGateLintel",
				at * CFrame.new(0, height + 2, 0),
				Vector3.new(gate.width + 28, 12, Village.WallThickness + 10),
				P.GateGreen,
				{ material = Enum.Material.WoodPlanks }
			)
		end
	end
end

-- ============================================================ landmarks

local function specFor(landmark: Village.Landmark): Structures.Spec
	return {
		position = landmark.position,
		rotation = landmark.rotation,
		width = landmark.width,
		depth = landmark.depth,
		floors = landmark.floors,
		storey = STOREY,
		wallColor = landmark.wallColor,
		roofColor = landmark.roofColor,
		trimColor = trimOf(landmark.wallColor),
		windowColor = P.Window,
		frontFacing = true,
		detail = Village.Detail,
	}
end

local function buildLandmarks()
	local folder = Builder.group("Landmarks", root)

	for _, landmark in Village.Landmarks do
		local spec = specFor(landmark)
		local model: Model

		if landmark.kind == "HokageTower" then
			model = Structures.hokageTower(folder, landmark.position)
		elseif landmark.kind == "Pagoda" then
			model = Structures.pagoda(folder, spec, landmark.floors, landmark.id == "Academy")
			if landmark.sign then
				Details.wallSign(
					model,
					CFrame.new(
						landmark.position.X,
						STOREY * 0.7,
						landmark.position.Z + landmark.depth / 2 + 6
					),
					landmark.sign,
					math.min(120, landmark.width * 0.8)
				)
			end
		elseif landmark.kind == "Spire" then
			model = Structures.spire(folder, landmark.position, landmark.floors * STOREY)
		elseif landmark.kind == "Round" then
			model = Structures.roundTower(folder, spec, rng)
		else
			model = Structures.shophouse(folder, spec, rng)
			if landmark.sign then
				Details.hangingSign(
					model,
					CFrame.new(
						landmark.position.X + landmark.width * 0.3,
						STOREY * 2.2,
						landmark.position.Z + landmark.depth / 2 + 3
					),
					landmark.sign
				)
			end
		end

		model.Name = landmark.id

		-- Compounds get a perimeter wall with a roofed gateway.
		if landmark.kind == "Compound" then
			local base = CFrame.new(Vector3.new(landmark.position.X, 0, landmark.position.Z))
				* CFrame.Angles(0, math.rad(landmark.rotation), 0)
			local halfW = landmark.width / 2 + 46
			local halfD = landmark.depth / 2 + 38

			for _, side in { -1, 1 } do
				Builder.block(
					folder,
					`{landmark.id}WallX`,
					base * CFrame.new(side * halfW, 10, 0),
					Vector3.new(3, 20, halfD * 2),
					P.PlasterWarm,
					{ material = Enum.Material.Plaster }
				)
				Builder.block(
					folder,
					`{landmark.id}WallCapX`,
					base * CFrame.new(side * halfW, 20.5, 0),
					Vector3.new(6, 1.6, halfD * 2 + 3),
					landmark.roofColor,
					{ material = Enum.Material.Slate }
				)
				Builder.block(
					folder,
					`{landmark.id}WallZ`,
					base * CFrame.new(0, 10, side * halfD),
					Vector3.new(halfW * 2, 20, 3),
					P.PlasterWarm,
					{ material = Enum.Material.Plaster }
				)
				Builder.block(
					folder,
					`{landmark.id}WallCapZ`,
					base * CFrame.new(0, 20.5, side * halfD),
					Vector3.new(halfW * 2 + 3, 1.6, 6),
					landmark.roofColor,
					{ material = Enum.Material.Slate }
				)
			end

			if landmark.sign then
				Details.wallSign(folder, base * CFrame.new(0, 26, halfD), landmark.sign, 60)
			end

			claim(landmark.position.X, landmark.position.Z, halfW * 2 + 30, halfD * 2 + 30, 0)
		else
			claim(landmark.position.X, landmark.position.Z, landmark.width + 46, landmark.depth + 46, 0)
		end
	end
end

-- ============================================================ academy precinct

-- A run of fence: posts with a cap, two rails, and a stone kerb under it.
-- `at` sits on the ground at the centre of the run, which extends along local X.
local function railFence(parent: Instance, at: CFrame, length: number, height: number)
	local posts = math.max(2, math.floor(length / 15) + 1)
	local spacing = length / (posts - 1)

	for i = 0, posts - 1 do
		local x = -length / 2 + spacing * i
		Builder.block(
			parent,
			"FencePost",
			at * CFrame.new(x, height / 2, 0),
			Vector3.new(2.8, height, 2.8),
			P.WoodDark,
			{ material = Enum.Material.Wood }
		)
		Builder.block(
			parent,
			"FencePostCap",
			at * CFrame.new(x, height + 0.8, 0),
			Vector3.new(4.4, 1.6, 4.4),
			P.WoodDark,
			{ material = Enum.Material.Wood, collide = false }
		)
	end

	for _, t in { 0.44, 0.8 } do
		Builder.block(
			parent,
			"FenceRail",
			at * CFrame.new(0, height * t, 0),
			Vector3.new(length, 2.4, 1.4),
			P.Wood,
			{ material = Enum.Material.WoodPlanks }
		)
	end

	Builder.block(
		parent,
		"FenceKerb",
		at * CFrame.new(0, 1.1, 0),
		Vector3.new(length, 2.2, 4.4),
		P.WallStone,
		{ material = Enum.Material.Slate }
	)
end

-- The tree from the reference shot, with a rope swing under its lowest bough.
-- Deliberately not buildTree: that one is a trunk with stacked canopy boxes and
-- has nothing to hang a swing from.
local function buildSwingTree(parent: Instance, at: CFrame)
	local model = Builder.group("SwingTree", parent)

	local trunkHeight = 44
	local trunk = Builder.cylinder(
		model,
		"Trunk",
		at * CFrame.new(0, trunkHeight / 2, 0) * CFrame.Angles(math.rad(4), 0, math.rad(-3)),
		13,
		trunkHeight,
		P.WoodDark,
		{ material = Enum.Material.Wood, castShadow = true }
	)
	-- Flared root collar, so it doesn't read as a pole stuck in sand.
	Builder.cylinder(model, "Roots", at * CFrame.new(0, 2, 0), 20, 4, P.WoodDark, {
		material = Enum.Material.Wood,
	})

	-- The bough the swing hangs from: thick, low, and reaching out to one side.
	local boughY = 27
	local boughReach = 30
	Builder.cylinder(
		model,
		"Bough",
		at * CFrame.new(boughReach / 2, boughY, 0) * CFrame.Angles(0, 0, math.rad(84)),
		6.5,
		boughReach + 6,
		P.WoodDark,
		{ material = Enum.Material.Wood, castShadow = true }
	)
	-- A second bough the other way, or the tree looks like it fell over.
	Builder.cylinder(
		model,
		"Bough2",
		at * CFrame.new(-16, boughY + 9, 4) * CFrame.Angles(0, math.rad(20), math.rad(-70)),
		5,
		34,
		P.WoodDark,
		{ material = Enum.Material.Wood }
	)

	-- Canopy: overlapping slabs rather than one box, so the silhouette is ragged.
	local canopy = {
		{ Vector3.new(0, 54, 0), Vector3.new(62, 20, 58) },
		{ Vector3.new(-18, 47, 6), Vector3.new(40, 15, 38) },
		{ Vector3.new(20, 49, -8), Vector3.new(38, 14, 36) },
		{ Vector3.new(2, 65, -2), Vector3.new(42, 14, 40) },
	}
	for index, blob in canopy do
		Builder.block(
			model,
			`Canopy{index}`,
			at * CFrame.new(blob[1]),
			blob[2],
			if index % 2 == 0 then P.FoliageDark else P.Foliage,
			{ material = Enum.Material.LeafyGrass, castShadow = index == 1 }
		)
	end

	-- The swing: two ropes off the bough and a plank seat.
	local swingX = boughReach - 6
	local seatY = 7
	for _, sz in { -1, 1 } do
		Builder.block(
			model,
			"SwingRope",
			at * CFrame.new(swingX, (boughY + seatY) / 2, sz * 4),
			Vector3.new(0.5, boughY - seatY, 0.5),
			Color3.fromRGB(196, 176, 132),
			{ material = Enum.Material.Fabric, collide = false }
		)
	end
	Builder.block(
		model,
		"SwingSeat",
		at * CFrame.new(swingX, seatY, 0) * CFrame.Angles(math.rad(-6), 0, 0),
		Vector3.new(6, 1.2, 12),
		P.Wood,
		{ material = Enum.Material.WoodPlanks }
	)

	Builder.anchorModel(model, trunk)
	return model
end

-- The Academy and everything that belongs to it: the forecourt players spawn on,
-- the swing tree, and the fenced courtyard out back that is the tutorial zone.
--
-- Runs before buildDistricts so its claim lands first — otherwise the packer
-- fills the courtyard with shophouses.
local function buildAcademy()
	local A = Village.Academy
	local folder = Builder.group("AcademyGrounds", root)
	local base = A.base

	local spec: Structures.Spec = {
		position = A.position,
		rotation = A.rotation,
		width = A.width,
		depth = A.depth,
		floors = 5,
		storey = STOREY,
		wallColor = A.wallColor,
		roofColor = A.roofColor,
		trimColor = trimOf(A.wallColor),
		windowColor = P.Window,
		frontFacing = true,
		detail = Village.Detail,
	}

	local building = Structures.academy(folder, spec, A.tiers)
	building.Name = "Academy"

	-- ---- forecourt -----------------------------------------------------------
	-- Packed sand, not paving. The reference is a dirt yard.
	Builder.block(
		folder,
		"Forecourt",
		base * CFrame.new(0, 0.9, A.depth / 2 + A.forecourtDepth / 2),
		Vector3.new(A.width + 30, 2.6, A.forecourtDepth),
		P.Sand,
		{ material = Enum.Material.Ground }
	)

	buildSwingTree(folder, base * CFrame.new(A.width / 2 - 18, 2, A.depth / 2 + 30))

	-- Lanterns flanking the approach to the doors.
	for _, sx in { -1, 1 } do
		Details.lantern(folder, base * CFrame.new(sx * 30, 20, A.depth / 2 + 22))
	end

	-- ---- courtyard -----------------------------------------------------------
	local yard = base
		* CFrame.new(0, 0, -(A.depth / 2 + A.courtyardGap + A.courtyardDepth / 2))
	local halfW = A.courtyardWidth / 2
	local halfD = A.courtyardDepth / 2

	Builder.block(
		folder,
		"CourtyardFloor",
		yard * CFrame.new(0, 0.9, 0),
		Vector3.new(A.courtyardWidth, 2.6, A.courtyardDepth),
		P.Sand,
		{ material = Enum.Material.Ground }
	)

	-- Fence: full runs on three sides, split around a gate on the side that
	-- faces the building's back door.
	railFence(folder, yard * CFrame.new(0, 0, -halfD), A.courtyardWidth, A.fenceHeight)
	for _, sx in { -1, 1 } do
		railFence(
			folder,
			yard * CFrame.new(sx * halfW, 0, 0) * CFrame.Angles(0, math.rad(90), 0),
			A.courtyardDepth,
			A.fenceHeight
		)
	end

	local panel = (A.courtyardWidth - A.gateWidth) / 2
	for _, sx in { -1, 1 } do
		railFence(
			folder,
			yard * CFrame.new(sx * (A.gateWidth + panel) / 2, 0, halfD),
			panel,
			A.fenceHeight
		)
	end

	-- Gateway: two tall posts and a beam across, so the entrance reads as a way in.
	local gateHeight = A.fenceHeight + 12
	for _, sx in { -1, 1 } do
		Builder.block(
			folder,
			"GatePost",
			yard * CFrame.new(sx * A.gateWidth / 2, gateHeight / 2, halfD),
			Vector3.new(4.4, gateHeight, 4.4),
			P.WoodDark,
			{ material = Enum.Material.Wood, castShadow = true }
		)
	end
	Builder.block(
		folder,
		"GateBeam",
		yard * CFrame.new(0, gateHeight + 1.4, halfD),
		Vector3.new(A.gateWidth + 14, 3.4, 5),
		P.WoodDark,
		{ material = Enum.Material.Wood }
	)
	Builder.block(
		folder,
		"GateRoof",
		yard * CFrame.new(0, gateHeight + 4, halfD),
		Vector3.new(A.gateWidth + 22, 1.6, 11),
		A.roofColor,
		{ material = Enum.Material.Slate, collide = false }
	)

	-- Sand path from the gate to the back steps, so the route is obvious.
	Builder.block(
		folder,
		"CourtyardPath",
		base * CFrame.new(0, 0.9, -(A.depth / 2 + A.courtyardGap / 2)),
		Vector3.new(A.gateWidth, 2.6, A.courtyardGap + 8),
		P.Sand,
		{ material = Enum.Material.Ground }
	)

	-- Yard dressing along the far fence: a weapon rack and two benches. Enemies
	-- are EnemyService's job, so nothing here occupies the middle where the
	-- training dolls scatter.
	for _, sx in { -1, 1 } do
		Builder.block(
			folder,
			"Bench",
			yard * CFrame.new(sx * (halfW - 16), 5, -halfD + 16),
			Vector3.new(6, 1.6, 26),
			P.Wood,
			{ material = Enum.Material.WoodPlanks }
		)
		for _, sz in { -1, 1 } do
			Builder.block(
				folder,
				"BenchLeg",
				yard * CFrame.new(sx * (halfW - 16), 2.5, -halfD + 16 + sz * 9),
				Vector3.new(5, 5, 2),
				P.WoodDark,
				{ material = Enum.Material.Wood }
			)
		end
	end

	Builder.block(
		folder,
		"WeaponRack",
		yard * CFrame.new(0, 7, -halfD + 12),
		Vector3.new(34, 2.4, 3),
		P.Wood,
		{ material = Enum.Material.WoodPlanks }
	)
	for _, sx in { -1, 1 } do
		Builder.block(
			folder,
			"RackLeg",
			yard * CFrame.new(sx * 15, 4, -halfD + 12),
			Vector3.new(2.6, 8, 2.6),
			P.WoodDark,
			{ material = Enum.Material.Wood }
		)
	end

	-- ---- claim ---------------------------------------------------------------
	-- One axis-aligned box over building, forecourt and courtyard. rotation 90
	-- swaps the local axes into world ones: local depth runs along world X and
	-- local width along world Z.
	local spanX = A.depth + A.forecourtDepth + A.courtyardGap + A.courtyardDepth
	local centerX = A.position.X + A.forecourtDepth / 2 - (A.courtyardGap + A.courtyardDepth) / 2

	claim(centerX, A.position.Z, spanX, math.max(A.width + 30, A.courtyardWidth), 14)
end

-- ============================================================ districts

local function buildDistricts(): number
	local folder = Builder.group("Districts", root)
	local placed = 0
	local gap = Village.BuildingGap

	for _, district in Village.Districts do
		local group = Builder.group(district.id, folder)
		local attempts = 0
		local built = 0

		while built < district.count and attempts < district.count * 22 do
			attempts += 1

			local round = rng:NextNumber() < district.roundChance
			local width = rng:NextInteger(district.widthRange.Min, district.widthRange.Max)
			local depth = if round then width else rng:NextInteger(district.depthRange.Min, district.depthRange.Max)

			local x = rng:NextNumber(district.bounds.minX, district.bounds.maxX)
			local z = rng:NextNumber(district.bounds.minZ, district.bounds.maxZ)

			if math.sqrt(x * x + z * z) > Village.WallRadius - 80 then
				continue
			end
			if not isFree(x, z, width + gap, depth + gap) then
				continue
			end

			-- Face the nearest cardinal street. Streets only read as streets if the
			-- buildings along them agree on a direction.
			local rotation = if math.abs(x) > math.abs(z)
				then (if x > 0 then 90 else 270)
				else (if z > 0 then 0 else 180)

			local wallColor = pick(district.wallColors)
			local spec: Structures.Spec = {
				position = Vector3.new(x, 0, z),
				rotation = rotation + rng:NextInteger(-3, 3),
				width = width,
				depth = depth,
				floors = rng:NextInteger(district.floorRange.Min, district.floorRange.Max),
				storey = STOREY,
				wallColor = wallColor,
				roofColor = pick(district.roofColors),
				trimColor = trimOf(wallColor),
				windowColor = P.Window,
				frontFacing = true,
				detail = Village.Detail,
			}

			if round then
				Structures.roundTower(group, spec, rng)
			else
				Structures.shophouse(group, spec, rng)
			end

			claim(x, z, width + gap, depth + gap, 0)
			built += 1
			placed += 1

			if placed % 40 == 0 then
				task.wait()
			end
		end
	end

	return placed
end

-- ============================================================ street furniture

local function buildStreetFurniture()
	local folder = Builder.group("StreetFurniture", root)

	-- Power poles down the main street, wires slung between consecutive tops.
	-- These read as strongly as the water tanks in the reference skyline.
	local previous: Vector3? = nil
	for z = 780, -300, -76 do
		local side = if (z // 76) % 2 == 0 then 1 else -1
		local at = CFrame.new(side * 17, 0, z)
		local top = Details.powerPole(folder, at, rng:NextInteger(46, 58))

		if previous then
			Details.wire(folder, previous, top)
		end
		previous = top
	end

	-- Market stalls lining the widest stretch of the main street.
	for i = 0, 11 do
		local z = 120 + i * 22
		local side = if i % 2 == 0 then -1 else 1
		Details.marketStall(
			folder,
			CFrame.new(side * 19, 1, z) * CFrame.Angles(0, if side < 0 then math.rad(90) else math.rad(-90), 0),
			pick({ P.RoofOrange, P.RoofTeal, P.RoofRed, P.RoofGold })
		)
	end

	-- Street lanterns on the approach to the tower.
	for z = 60, -340, -58 do
		for _, sx in { -1, 1 } do
			Details.lantern(folder, CFrame.new(sx * 15, 22, z))
		end
	end

	-- Cherry blossoms down the south edge of the Academy forecourt. Derived from
	-- Village.Academy rather than hard-coded: the old ring was centred on the
	-- building and would now be planted inside the courtyard fence.
	--
	-- South side only — the north side is where the swing tree stands, and two
	-- canopies in the same place read as one shapeless mass.
	local A = Village.Academy
	for i = 0, 3 do
		local position = (
			A.base * CFrame.new(-(A.width / 2 + 4), 0, A.depth / 2 + 10 + i * 15)
		).Position

		Builder.cylinder(
			folder,
			"Trunk",
			CFrame.new(position + Vector3.new(0, 11, 0)),
			5,
			22,
			P.WoodDark,
			{ material = Enum.Material.Wood }
		)
		for j = 0, 2 do
			Builder.block(
				folder,
				"Blossom",
				CFrame.new(position + Vector3.new(0, 24 + j * 7, 0)),
				Vector3.new(30 - j * 7, 11 - j, 30 - j * 7),
				Color3.fromRGB(244, 194, 214),
				{ material = Enum.Material.LeafyGrass }
			)
		end
	end
end

-- ============================================================ Hokage Rock

local function buildHokageRock()
	local folder = Builder.group("HokageRock", root)
	local spec = Village.HokageRock

	for i = 0, 2 do
		local t = i / 3
		Builder.block(
			folder,
			`Cliff{i}`,
			CFrame.new(spec.center.X, spec.height * t + spec.height * 0.16, spec.center.Z - i * 60),
			Vector3.new(spec.width - i * 120, spec.height * 0.36, spec.depth + i * 90),
			if i % 2 == 0 then P.Rock else P.RockDark,
			{ material = Enum.Material.Rock, castShadow = true }
		)
	end

	-- The five carved faces.
	local spacing = 210
	local startX = -((spec.faceCount - 1) * spacing) / 2

	for i = 0, spec.faceCount - 1 do
		local x = spec.center.X + startX + i * spacing
		local y = spec.height * 0.52
		local z = spec.center.Z + spec.depth / 2 - 4

		Builder.block(
			folder,
			`FaceRecess{i}`,
			CFrame.new(x, y, z),
			Vector3.new(130, 150, 10),
			P.RockDark,
			{ material = Enum.Material.Rock }
		)
		local panel = Builder.block(
			folder,
			`Face{i}`,
			CFrame.new(x, y, z + 5),
			Vector3.new(112, 132, 3),
			P.Rock,
			{ material = Enum.Material.Rock }
		)
		Builder.surfaceText(panel, Enum.NormalId.Front, tostring(i + 1), P.RockDark, 0.6)
	end

	-- Hanging banners on the cliff face, as in the reference.
	for i = 0, 5 do
		local x = spec.center.X - 420 + i * 168
		Builder.block(
			folder,
			"CliffBanner",
			CFrame.new(x, spec.height * 0.3, spec.center.Z + spec.depth / 2 + 2),
			Vector3.new(20, 78, 1),
			pick({ P.RoofRed, P.PlasterPale, P.RoofBlue, P.RoofGold }),
			{ material = Enum.Material.Fabric, collide = false }
		)
	end

	-- Switchback stair up the cliff, so the faces are reachable.
	local steps = 34
	for i = 0, steps - 1 do
		local t = i / steps
		Builder.block(
			folder,
			"CliffStep",
			CFrame.new(
				spec.center.X + 620 - t * 260,
				spec.height * 0.14 + t * spec.height * 0.5,
				spec.center.Z + spec.depth / 2 - t * 40
			),
			Vector3.new(26, 3, 22),
			P.RockDark,
			{ material = Enum.Material.Rock }
		)
	end
end

-- ============================================================ scatter

local function buildTree(parent: Instance, position: Vector3, scale: number, dark: boolean)
	local trunkHeight = 26 * scale
	Builder.cylinder(
		parent,
		"Trunk",
		CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)),
		6 * scale,
		trunkHeight,
		P.WoodDark,
		{ material = Enum.Material.Wood }
	)

	local color = if dark then P.FoliageDark else P.Foliage
	for i = 0, 2 do
		local y = trunkHeight + (i * 9 - 4) * scale
		Builder.block(
			parent,
			"Canopy",
			CFrame.new(position + Vector3.new(0, y, 0)),
			Vector3.new((34 - i * 8) * scale, (14 - i * 2) * scale, (34 - i * 8) * scale),
			color,
			{ material = Enum.Material.LeafyGrass }
		)
	end
end

-- ============================================================ outer zones

local function buildZones()
	local folder = Builder.group("Zones", root)

	for _, zone in Village.Zones do
		-- The Academy courtyard is a zone for quests and spawning only; its
		-- geometry belongs to buildAcademy. A grass disc and an area sign
		-- dropped on it would land on top of the sand and the fence.
		if zone.kind == "Courtyard" then
			continue
		end

		local group = Builder.group(zone.id, folder)

		Builder.cylinder(
			group,
			"Floor",
			CFrame.new(zone.center + Vector3.new(0, 0.4, 0)),
			zone.radius * 2,
			3,
			zone.groundColor,
			{ material = Enum.Material.Grass }
		)

		local marker = Builder.block(
			group,
			"AreaSign",
			CFrame.new(zone.center + Vector3.new(0, 16, zone.radius - 30)),
			Vector3.new(90, 26, 2),
			P.WoodDark,
			{ material = Enum.Material.WoodPlanks }
		)
		Builder.surfaceText(marker, Enum.NormalId.Front, zone.displayName, P.PlasterPale, 0.8)

		for i = 1, zone.treeCount do
			local angle = rng:NextNumber() * math.pi * 2
			local dist = math.sqrt(rng:NextNumber()) * (zone.radius - 40)
			local position = zone.center
				+ Vector3.new(math.cos(angle) * dist, 1, math.sin(angle) * dist)

			local scale = if zone.kind == "Forest"
				then rng:NextNumber(2.4, 4.2)
				else rng:NextNumber(0.9, 1.5)

			buildTree(group, position, scale, zone.kind == "Forest")
			if i % 20 == 0 then
				task.wait()
			end
		end

		if zone.kind == "Training" then
			for i = -1, 1 do
				Builder.cylinder(
					group,
					"TrainingPost",
					CFrame.new(zone.center + Vector3.new(i * 22, 13, -40)),
					9,
					26,
					P.Wood,
					{ material = Enum.Material.Wood }
				)
			end
			Builder.block(
				group,
				"MemorialStone",
				CFrame.new(zone.center + Vector3.new(70, 6, 30)) * CFrame.Angles(math.rad(-14), 0, 0),
				Vector3.new(46, 12, 22),
				P.RockDark,
				{ material = Enum.Material.Rock }
			)
			Builder.block(
				group,
				"River",
				CFrame.new(zone.center + Vector3.new(0, 0.8, 150)),
				Vector3.new(zone.radius * 1.6, 2, 70),
				P.Water,
				{ material = Enum.Material.Water, transparency = 0.35, collide = false }
			)
		elseif zone.kind == "Forest" then
			local posts = 30
			for i = 0, posts - 1 do
				local theta = (i / posts) * math.pi * 2
				local x = zone.center.X + math.sin(theta) * zone.radius
				local z = zone.center.Z + math.cos(theta) * zone.radius
				Builder.block(
					group,
					"Fence",
					CFrame.new(x, 14, z) * CFrame.Angles(0, theta, 0),
					Vector3.new(zone.radius * 2 * math.pi / posts + 2, 28, 1.5),
					Color3.fromRGB(96, 98, 92),
					{ material = Enum.Material.DiamondPlate, transparency = 0.45 }
				)
			end
		elseif zone.kind == "Ruins" then
			for _ = 1, 16 do
				local angle = rng:NextNumber() * math.pi * 2
				local dist = rng:NextNumber(40, zone.radius - 50)
				local position = zone.center
					+ Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
				local h = rng:NextInteger(18, 54)
				Builder.block(
					group,
					"Pillar",
					CFrame.new(position + Vector3.new(0, h / 2, 0))
						* CFrame.Angles(math.rad(rng:NextInteger(-8, 8)), rng:NextNumber() * 6, 0),
					Vector3.new(rng:NextInteger(12, 20), h, rng:NextInteger(12, 20)),
					P.RockDark,
					{ material = Enum.Material.Slate }
				)
			end
		end
	end
end

-- ============================================================ spawn

local function buildSpawn()
	local folder = Builder.group("Spawn", root)

	-- The plaza and the spawn are separate places now: players start on the
	-- Academy forecourt, but the village square is still where the higher-tier
	-- quest givers stand, so it still gets built.
	Builder.cylinder(
		folder,
		"Plaza",
		CFrame.new(Village.PlazaPosition.X, 1.2, Village.PlazaPosition.Z),
		130,
		3,
		P.PlasterPale,
		{ material = Enum.Material.Marble }
	)
	-- Inlaid ring, so the plaza reads as designed rather than a blank disc.
	Builder.cylinder(
		folder,
		"PlazaRing",
		CFrame.new(Village.PlazaPosition.X, 2.5, Village.PlazaPosition.Z),
		96,
		1,
		P.RoadEdge,
		{ material = Enum.Material.Slate, collide = false }
	)

	local spawnLocation = Instance.new("SpawnLocation")
	spawnLocation.Name = "VillageSpawn"
	spawnLocation.Size = Vector3.new(28, 1, 28)
	spawnLocation.CFrame = CFrame.new(Village.SpawnPosition)
	spawnLocation.Anchored = true
	spawnLocation.Transparency = 1
	spawnLocation.CanCollide = false
	spawnLocation.Duration = 0
	spawnLocation.Parent = folder
end

-- ============================================================ api

function VillageService.zone(id: string): Village.Zone?
	for _, zone in Village.Zones do
		if zone.id == id then
			return zone
		end
	end
	return nil
end

function VillageService.start()
	local existing = Workspace:FindFirstChild("Konoha")
	if existing then
		existing:Destroy()
	end

	root = Instance.new("Folder")
	root.Name = "Konoha"
	root.Parent = Workspace

	local started = os.clock()

	buildGround()
	buildRoads()
	buildLandmarks()
	buildAcademy()
	local placed = buildDistricts()
	buildStreetFurniture()
	buildWall()
	buildHokageRock()
	buildZones()
	buildSpawn()

	local parts = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		end
	end

	print(
		string.format(
			"[VillageService] Konoha built — %d buildings, %d parts, %.2fs (detail %.2f)",
			placed,
			parts,
			os.clock() - started,
			Village.Detail
		)
	)
end

return VillageService
