--!strict
-- Dash accounting. The client performs the actual movement — waiting on a server
-- round trip before you visibly move feels awful, and in Roblox the client owns
-- its own character's physics anyway, so server-side motion would just fight it.
--
-- What the server does own is the ledger: the cooldown and the chakra cost. A
-- tampered client could therefore dash without paying, which is a movement-only
-- exploit and an accepted trade for responsiveness. Anything that grants damage
-- or rewards stays fully server-authoritative.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local ChakraService = require(script.Parent.ChakraService)
local DataService = require(script.Parent.DataService)

local MovementService = {}

local lastDash: { [Player]: number } = {}

function MovementService.tryDash(player: Player): boolean
	if not DataService.get(player) then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	local now = os.clock()
	local previous = lastDash[player] or 0
	-- Small tolerance so a client honestly at the cooldown edge isn't rejected by
	-- network jitter.
	if now - previous < GameConfig.DashCooldown - 0.05 then
		return false
	end

	if not ChakraService.trySpend(player, GameConfig.DashCost) then
		return false
	end

	lastDash[player] = now
	return true
end

function MovementService.start()
	Remotes.Events.Dash.OnServerEvent:Connect(function(player)
		local ok = MovementService.tryDash(player)
		Remotes.Events.DashResult:FireClient(player, { ok = ok })
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastDash[player] = nil
	end)
end

return MovementService
