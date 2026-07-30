--!strict
-- Live chakra pool. MaxChakra is derived from the profile, but *current* chakra
-- is runtime-only state — it deliberately does not persist, so logging out is
-- never a way to skip a cooldown.
--
-- Health has no equivalent service: Humanoid.Health already is the live value,
-- and the client can read its own Humanoid without a round trip.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Formulas = require(Shared.Formulas)
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)

local ChakraService = {}

type State = {
	current: number,
	lastSpend: number,
}

local states: { [Player]: State } = {}

local function maxFor(player: Player): number
	local profile = DataService.get(player)
	if not profile then
		return GameConfig.BaseChakra
	end
	return Formulas.derive(profile).MaxChakra
end

function ChakraService.push(player: Player)
	local state = states[player]
	if not state then
		return
	end
	Remotes.Events.VitalsUpdated:FireClient(player, {
		chakra = math.floor(state.current),
		maxChakra = maxFor(player),
	})
end

function ChakraService.get(player: Player): number
	local state = states[player]
	return if state then state.current else 0
end

-- Fill to full. Called on spawn and whenever MaxChakra changes.
function ChakraService.refill(player: Player)
	local state = states[player]
	if state then
		state.current = maxFor(player)
		ChakraService.push(player)
	end
end

-- Returns false and spends nothing if the player can't afford it, so callers
-- can use this as the gate itself rather than checking first.
function ChakraService.trySpend(player: Player, amount: number): boolean
	local state = states[player]
	if not state or amount < 0 then
		return false
	end
	if state.current < amount then
		return false
	end

	state.current -= amount
	state.lastSpend = os.clock()
	ChakraService.push(player)
	return true
end

function ChakraService.start()
	local function track(player: Player)
		states[player] = { current = maxFor(player), lastSpend = 0 }
		ChakraService.push(player)

		player.CharacterAdded:Connect(function()
			-- Fresh character, fresh pool.
			task.wait(0.2)
			ChakraService.refill(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		track(player)
	end
	Players.PlayerAdded:Connect(track)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	-- Regen loop. Accumulates real elapsed time rather than assuming a fixed
	-- step, so a hitching server doesn't quietly slow regen down.
	local accumulated = 0
	RunService.Heartbeat:Connect(function(delta)
		accumulated += delta
		if accumulated < 0.25 then
			return
		end
		local step = accumulated
		accumulated = 0

		local now = os.clock()
		for player, state in states do
			local profile = DataService.get(player)
			if not profile then
				continue
			end
			if now - state.lastSpend < GameConfig.ChakraRegenDelayAfterUse then
				continue
			end

			local cap = maxFor(player)
			if state.current >= cap then
				continue
			end

			state.current = math.min(cap, state.current + Formulas.chakraRegen(profile.Level) * step)
			ChakraService.push(player)
		end
	end)
end

return ChakraService
