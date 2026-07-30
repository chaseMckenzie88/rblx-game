--!strict
-- Levels, XP, stat points, and nature rolls. This is the only module allowed
-- to mutate a profile's progression fields — everything else goes through it,
-- so there is exactly one place where cheating has to be blocked.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Types = require(Shared.Types)
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Natures = require(Shared.Config.Natures)
local Ranks = require(Shared.Config.Ranks)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local ProgressionService = {}

local function notify(player: Player, text: string)
	Remotes.Events.Notify:FireClient(player, { text = text })
end

-- Push the whole profile to the client. Small enough that diffing isn't worth
-- the complexity, and it keeps the HUD impossible to desync.
function ProgressionService.push(player: Player)
	local profile = DataService.get(player)
	if profile then
		Remotes.Events.ProfileUpdated:FireClient(player, profile)
	end
end

-- Apply level-derived values to the character. Called on spawn and level-up.
function ProgressionService.applyToCharacter(player: Player)
	local profile = DataService.get(player)
	local character = player.Character
	if not profile or not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local derived = Formulas.derive(profile)
	local healthRatio = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1

	humanoid.MaxHealth = derived.MaxHealth
	humanoid.Health = derived.MaxHealth * math.clamp(healthRatio, 0, 1)
	humanoid.WalkSpeed = derived.WalkSpeed

	-- Spending a Chakra point raises MaxChakra, so the bar has to be told.
	-- Required lazily: ChakraService reads profiles through DataService, and a
	-- top-level require here would make the two modules circular.
	local ChakraService = require(script.Parent.ChakraService)
	ChakraService.push(player)
end

function ProgressionService.awardXP(player: Player, amount: number)
	local profile = DataService.get(player)
	if not profile or amount <= 0 or profile.Level >= GameConfig.MaxLevel then
		return
	end

	profile.XP += math.floor(amount)

	local startingLevel = profile.Level
	local startingRank = Ranks.forLevel(startingLevel)

	-- while, not if: a big XP drop can cross several levels at once.
	while profile.Level < GameConfig.MaxLevel do
		local needed = Formulas.xpForNextLevel(profile.Level)
		if profile.XP < needed then
			break
		end
		profile.XP -= needed
		profile.Level += 1
		profile.StatPoints += GameConfig.StatPointsPerLevel
	end

	if profile.Level > startingLevel then
		ProgressionService.applyToCharacter(player)
		notify(player, `Level {profile.Level}`)

		local newRank = Ranks.forLevel(profile.Level)
		if newRank.Name ~= startingRank.Name then
			notify(player, `Promoted to {newRank.Name}`)
		end
	end

	ProgressionService.push(player)
end

function ProgressionService.spendStatPoint(player: Player, stat: string, amount: number?)
	local profile = DataService.get(player)
	if not profile then
		return
	end

	-- Validate against the template rather than a hand-written list, so a new
	-- stat added to Types.Stats is automatically spendable.
	if profile.Stats[stat :: any] == nil then
		return
	end

	local requested = math.floor(tonumber(amount) or 1)
	if requested < 1 then
		return
	end

	local room = GameConfig.MaxPointsPerStat - profile.Stats[stat :: any]
	local spend = math.min(requested, profile.StatPoints, room)
	if spend <= 0 then
		return
	end

	profile.StatPoints -= spend
	profile.Stats[stat :: any] += spend

	ProgressionService.applyToCharacter(player)
	ProgressionService.push(player)
end

-- Rolls once and returns the id, or nil if the player already has a nature.
--
-- Deliberately does NOT announce the result: the client plays a spinning reel and
-- reveals it at the end, so a toast here would spoil the payoff. The profile is
-- still pushed immediately — data integrity first, presentation second — and the
-- HUD holds back its nature row while a spin is running.
function ProgressionService.rollNature(player: Player): string?
	local profile = DataService.get(player)
	if not profile then
		return nil
	end

	if profile.Nature then
		notify(player, "You already have a chakra nature.")
		return nil
	end

	local rolled = Natures.roll()
	profile.Nature = rolled

	ProgressionService.push(player)
	return rolled
end

function ProgressionService.start()
	Remotes.Events.SpendStatPoint.OnServerEvent:Connect(function(player, payload)
		if type(payload) == "table" then
			ProgressionService.spendStatPoint(player, payload.stat, payload.amount)
		end
	end)

	-- No RollNature listener on purpose. Rolling is triggered by the Nature Elder's
	-- ProximityPrompt, which already fires server-side — wiring the remote too
	-- would hand clients a way to roll without ever walking to the NPC.

	Remotes.Functions.GetProfile.OnServerInvoke = function(player)
		return DataService.get(player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Humanoid properties set too early get clobbered by the default rig.
			task.wait(0.1)
			ProgressionService.applyToCharacter(player)
		end)
	end)
end

return ProgressionService
