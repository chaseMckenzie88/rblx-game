--!strict
-- Taijutsu melee. The client sends "I swung" and nothing else — the server owns
-- the cooldown, picks the targets, and computes the damage. A modified client
-- can therefore spam the remote, but every swing still costs the real cooldown
-- and hits only what's genuinely in front of the real character.
--
-- Nature matchups are deliberately NOT applied here: the elemental cycle is a
-- ninjutsu mechanic. Punching someone doesn't have an element. Natures.matchup
-- gets wired in when jutsu land.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local EnemyService = require(script.Parent.EnemyService)

local CombatService = {}

type ComboState = {
	combo: number,
	lastSwing: number,
}

local combos: { [Player]: ComboState } = {}

local COS_HALF_ARC = math.cos(math.rad(GameConfig.MeleeArcDegrees / 2))

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Everything alive, in range, and inside the frontal cone — nearest first.
local function targetsInFront(root: BasePart): { EnemyService.Enemy }
	local origin = root.Position
	local facing = root.CFrame.LookVector

	local found: { { enemy: EnemyService.Enemy, distance: number } } = {}

	for _, enemy in EnemyService.all() do
		if not enemy.alive then
			continue
		end

		local offset = enemy.root.Position - origin
		local distance = offset.Magnitude
		if distance > GameConfig.MeleeRange or distance < 0.1 then
			continue
		end

		-- Dot of unit vectors is the cosine of the angle between them, so this
		-- is an arc test without ever calling acos.
		if facing:Dot(offset.Unit) < COS_HALF_ARC then
			continue
		end

		table.insert(found, { enemy = enemy, distance = distance })
	end

	table.sort(found, function(a, b)
		return a.distance < b.distance
	end)

	local result: { EnemyService.Enemy } = {}
	for index, entry in found do
		if index > GameConfig.MeleeMaxTargets then
			break
		end
		table.insert(result, entry.enemy)
	end
	return result
end

function CombatService.swing(player: Player)
	local profile = DataService.get(player)
	local root = characterRoot(player)
	if not profile or not root then
		return
	end

	local state = combos[player]
	if not state then
		state = { combo = 0, lastSwing = 0 }
		combos[player] = state
	end

	local now = os.clock()

	-- The authoritative rate limit. Client-side cooldown is cosmetic.
	if now - state.lastSwing < GameConfig.MeleeCooldown then
		return
	end

	-- Idle too long and the combo drops.
	if now - state.lastSwing > GameConfig.MeleeComboResetTime then
		state.combo = 0
	end

	state.lastSwing = now
	state.combo += 1

	local isFinisher = state.combo >= GameConfig.MeleeComboLength
	local comboIndex = state.combo
	if isFinisher then
		state.combo = 0
	end

	local derived = Formulas.derive(profile)
	local damage = derived.TaijutsuDamage
	if isFinisher then
		damage *= GameConfig.MeleeFinisherBonus
	end

	local targets = targetsInFront(root)

	Remotes.Events.MeleeResult:FireClient(player, {
		combo = comboIndex,
		finisher = isFinisher,
		hits = #targets,
	})

	for _, enemy in targets do
		local applied = EnemyService.damage(enemy, damage, player)
		if applied <= 0 then
			continue
		end

		Remotes.Events.DamageDealt:FireClient(player, {
			position = enemy.root.Position,
			amount = math.floor(applied + 0.5),
			killed = not enemy.alive,
			finisher = isFinisher,
		})

		-- Anchored dummies ignore this; it starts working on its own once real
		-- mobile enemies exist.
		if not enemy.root.Anchored then
			local direction = (enemy.root.Position - root.Position).Unit
			enemy.root:ApplyImpulse(direction * GameConfig.MeleeKnockback * enemy.root.AssemblyMass)
		end
	end
end

function CombatService.start()
	Remotes.Events.MeleeSwing.OnServerEvent:Connect(function(player)
		CombatService.swing(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		combos[player] = nil
	end)
end

return CombatService
