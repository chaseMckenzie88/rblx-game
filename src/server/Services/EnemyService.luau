--!strict
-- Training dummies: things you can hit that report damage and respawn. No AI,
-- no aggro, no pathfinding yet — that comes after melee feels right.
--
-- Rigs are built from code on purpose. The Rojo pipeline owns code only, so
-- anything that has to exist for a playtest gets spawned rather than modelled.
-- Replace the visuals in Studio later; EnemyService only cares about the
-- Humanoid and the PrimaryPart.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local EnemyAreas = require(Shared.Config.EnemyAreas)
local Village = require(Shared.Config.Village)
local Formulas = require(Shared.Formulas)

-- Builder lives under World/ but the doll rig needs its cylinder helper.
local Builder = require(script.Parent.Parent.World.Builder)

local EnemyService = {}

local rng = Random.new(Village.Seed + 7)

export type Enemy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	name: string,
	level: number,
	spawnPosition: Vector3,
	alive: boolean,
}

local enemies: { Enemy } = {}
local folder: Folder

-- Hand-placed overrides. Parts named EnemySpawn in Workspace (or anything inside
-- a Workspace/EnemySpawns folder) take priority over the generated zones — a
-- hand-built world always beats config coordinates.
local function manualSpawnPoints(): { Vector3 }
	local points: { Vector3 } = {}

	local container = Workspace:FindFirstChild("EnemySpawns")
	if container then
		for _, child in container:GetDescendants() do
			if child:IsA("BasePart") then
				table.insert(points, child.Position + Vector3.new(0, 3, 0))
			end
		end
	end

	for _, child in Workspace:GetChildren() do
		if child:IsA("BasePart") and child.Name == "EnemySpawn" then
			table.insert(points, child.Position + Vector3.new(0, 3, 0))
		end
	end

	return points
end

-- Scatter inside a zone, kept off the nameplate and out of the dead centre so
-- players aren't spawned on top of a mob when they walk in.
--
-- The margins are fractions of the radius, not fixed studs. The old constants
-- were tuned for the 240-340 stud outer zones and go negative on anything small
-- — the 82-stud Academy courtyard would have spawned every doll in one ring.
local INNER_MARGIN = 0.22
local OUTER_MARGIN = 0.86

local function scatter(center: Vector3, radius: number, count: number): { Vector3 }
	local points: { Vector3 } = {}
	local inner = radius * INNER_MARGIN
	local span = radius * OUTER_MARGIN - inner

	for _ = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		-- sqrt keeps the distribution even by area rather than clustering inward.
		local dist = inner + math.sqrt(rng:NextNumber()) * span
		table.insert(
			points,
			Vector3.new(
				center.X + math.cos(angle) * dist,
				center.Y + 3.5,
				center.Z + math.sin(angle) * dist
			)
		)
	end

	return points
end

local function part(name: string, size: Vector3, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	-- Anchored: dummies hold position so they're easy to test against. Knockback
	-- is skipped for anchored roots and switches on by itself for mobile enemies.
	p.Anchored = true
	p.Parent = parent
	return p
end

local function healthBar(enemy: Enemy)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "HealthBar"
	billboard.Size = UDim2.fromOffset(120, 30)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Adornee = enemy.root
	billboard.Parent = enemy.root

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, 0, 0, 14)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.Text = `{enemy.name}  ·  Lv {enemy.level}`
	name.TextSize = 12
	name.TextColor3 = Color3.fromRGB(235, 240, 248)
	name.TextStrokeTransparency = 0.5
	name.Parent = billboard

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.Size = UDim2.new(1, -16, 0, 6)
	track.Position = UDim2.new(0, 8, 0, 16)
	track.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	track.BorderSizePixel = 0
	track.Parent = billboard

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(235, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = track

	local function sync()
		local ratio = if enemy.humanoid.MaxHealth > 0
			then enemy.humanoid.Health / enemy.humanoid.MaxHealth
			else 0
		fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		track.Visible = enemy.alive
		name.Visible = enemy.alive
	end

	enemy.humanoid.HealthChanged:Connect(sync)
	sync()
end

-- Straw dummy lashed to a wooden post, with a painted target on its chest.
-- Deliberately not humanoid: these are the Academy's practice targets.
local function buildDollBody(model: Model, position: Vector3)
	local STRAW = Color3.fromRGB(206, 176, 108)
	local ROPE = Color3.fromRGB(156, 122, 72)
	local POST = Color3.fromRGB(104, 76, 52)

	Builder.cylinder(model, "Post", CFrame.new(position - Vector3.new(0, 1, 0)), 1.6, 7, POST, {
		material = Enum.Material.Wood,
	})

	local torso = part("Torso", Vector3.new(2.4, 3, 1.8), STRAW, model)
	torso.Material = Enum.Material.Fabric
	torso.CFrame = CFrame.new(position + Vector3.new(0, 0.6, 0))

	-- Rope bindings around the straw. No rotation: a band round a upright body is
	-- a flat disc with a vertical axis, which is what Builder.cylinder already
	-- makes from a plain CFrame.
	for i = 0, 1 do
		Builder.cylinder(
			model,
			"Rope",
			CFrame.new(position + Vector3.new(0, 0.1 + i * 1.2, 0)),
			2.7,
			0.35,
			ROPE,
			{ material = Enum.Material.Fabric, collide = false }
		)
	end

	-- Crossbar arms.
	local arms = part("Arms", Vector3.new(5.4, 0.7, 0.7), POST, model)
	arms.Material = Enum.Material.Wood
	arms.CFrame = CFrame.new(position + Vector3.new(0, 1.5, 0))

	local head = part("Head", Vector3.new(1.5, 1.5, 1.5), STRAW, model)
	head.Material = Enum.Material.Fabric
	head.CFrame = CFrame.new(position + Vector3.new(0, 3, 0))

	-- Concentric target on the chest — red, white, red.
	local rings = { { 1.7, Color3.fromRGB(188, 62, 52) }, { 1.1, Color3.fromRGB(238, 232, 218) }, { 0.5, Color3.fromRGB(188, 62, 52) } }
	for index, ring in rings do
		Builder.cylinder(
			model,
			`Target{index}`,
			CFrame.new(position + Vector3.new(0, 0.7, 0.95 + index * 0.06))
				* CFrame.Angles(math.rad(-90), 0, 0),
			ring[1] :: number,
			0.12,
			ring[2] :: Color3,
			{ material = Enum.Material.SmoothPlastic, collide = false }
		)
	end
end

local function buildNinBody(model: Model, position: Vector3)
	local torso = part("Torso", Vector3.new(2, 2, 1), Color3.fromRGB(90, 105, 130), model)
	torso.CFrame = CFrame.new(position)

	local head = part("Head", Vector3.new(1.2, 1.2, 1.2), Color3.fromRGB(225, 200, 165), model)
	head.CFrame = CFrame.new(position + Vector3.new(0, 1.7, 0))
end

local function build(position: Vector3, level: number, enemyName: string, kind: string): Enemy
	local model = Instance.new("Model")
	model.Name = enemyName

	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.fromRGB(70, 80, 100), model)
	root.Transparency = 1
	root.CFrame = CFrame.new(position)

	if kind == "Doll" then
		buildDollBody(model, position)
	else
		buildNinBody(model, position)
	end

	local humanoid = Instance.new("Humanoid")
	-- Without this a Humanoid with no Neck joint dies the instant it spawns.
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.MaxHealth = Formulas.enemyHealth(level)
	humanoid.Health = humanoid.MaxHealth
	humanoid.Parent = model

	model.PrimaryPart = root
	model.Parent = folder

	local enemy: Enemy = {
		model = model,
		humanoid = humanoid,
		root = root,
		name = enemyName,
		level = level,
		spawnPosition = position,
		alive = true,
	}

	healthBar(enemy)
	return enemy
end

function EnemyService.all(): { Enemy }
	return enemies
end

-- Returns the damage actually applied, so the caller can report a real number
-- rather than what it hoped to deal.
function EnemyService.damage(enemy: Enemy, amount: number, attacker: Player?): number
	if not enemy.alive or amount <= 0 then
		return 0
	end

	local before = enemy.humanoid.Health
	enemy.humanoid.Health = math.max(0, before - amount)
	local applied = before - enemy.humanoid.Health

	if enemy.humanoid.Health <= 0 then
		EnemyService.kill(enemy, attacker)
	end

	return applied
end

function EnemyService.kill(enemy: Enemy, attacker: Player?)
	if not enemy.alive then
		return
	end
	enemy.alive = false

	-- Kills pay no XP of their own — they only advance a quest, and QuestService
	-- pays out on completion. Routed here rather than in CombatService so every
	-- future kill source (jutsu, traps, other players) counts through one path.
	if attacker then
		local QuestService = require(script.Parent.QuestService)
		QuestService.reportKill(attacker, enemy.name, enemy.level)
	end

	for _, descendant in enemy.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		end
	end

	task.delay(GameConfig.EnemyRespawnDelay, function()
		if not enemy.model.Parent then
			return
		end
		enemy.humanoid.Health = enemy.humanoid.MaxHealth
		enemy.alive = true
		for _, descendant in enemy.model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Transparency = if descendant.Name == "HumanoidRootPart" then 1 else 0
				descendant.CanCollide = descendant.Name ~= "HumanoidRootPart"
			end
		end
	end)
end

function EnemyService.start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = Workspace

	-- One population per configured area, positioned from the matching village
	-- zone so quest targets actually live where the quest says they do.
	for _, area in EnemyAreas do
		local zone: Village.Zone? = nil
		for _, candidate in Village.Zones do
			if candidate.id == area.ZoneId then
				zone = candidate
				break
			end
		end

		if not zone then
			warn(`[EnemyService] no village zone named '{area.ZoneId}' — skipping {area.EnemyName}`)
			continue
		end

		for _, position in scatter(zone.center, zone.radius, area.Count) do
			table.insert(enemies, build(position, area.Level, area.EnemyName, area.Kind))
		end

		print(`[EnemyService] {area.Count}× {area.EnemyName} (Lv {area.Level}) in {zone.displayName}`)
	end

	-- Anything hand-placed gets the default enemy on top of the above.
	for _, position in manualSpawnPoints() do
		table.insert(
			enemies,
			build(position, GameConfig.EnemyDefaultLevel, GameConfig.EnemyDefaultName, "Doll")
		)
	end

	print(`[EnemyService] {#enemies} enemies total`)
end

return EnemyService
