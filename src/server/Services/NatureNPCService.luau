--!strict
-- The elder who reads your chakra nature.
--
-- Flow: walk up → prompt → (first time only) his line → nature panel → Spin.
-- The roll itself is server-side and one-shot; the client only gets told the
-- result so its reel can land on it.
--
-- Rolling is reachable *only* through this NPC. ProgressionService has no
-- RollNature remote listener, so there's no client-callable shortcut.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Remotes = require(Shared.Remotes)

local DataService = require(script.Parent.DataService)
local NPCBuilder = require(script.Parent.NPCBuilder)
local ProgressionService = require(script.Parent.ProgressionService)

local NatureNPCService = {}

-- Edit his dialogue here.
local ELDER_NAME = "Nature Elder"
local ELDER_TITLE = "Chakra Reader"
local ELDER_GREETING = "Hold this paper and channel your chakra into it. Fire burns it, "
	.. "wind cuts it, lightning crumples it — the paper never lies about what you are."

-- Session-scoped, like the quest givers: hearing the line again after a rejoin is
-- harmless and keeps the save format clean.
local greeted: { [Player]: boolean } = {}

local function panelPayload(player: Player)
	local profile = DataService.get(player)
	if not profile then
		return nil
	end
	return {
		hasNature = profile.Nature ~= nil,
		natureId = profile.Nature,
	}
end

function NatureNPCService.start()
	local npc = NPCBuilder.build({
		name = "NatureElder",
		displayName = ELDER_NAME,
		actionText = "Read chakra nature",
		robeColor = Color3.fromRGB(70, 60, 110),
		titleColor = Color3.fromRGB(200, 180, 255),
		markerName = "NatureNPC",
		-- Village plaza, facing the main street.
		fallbackPosition = Vector3.new(0, 3.5, 330),
	})

	npc.prompt.HoldDuration = 0.5
	npc.prompt.ObjectText = ELDER_TITLE

	npc.prompt.Triggered:Connect(function(player)
		local payload = panelPayload(player)
		if not payload then
			return
		end

		if not greeted[player] then
			greeted[player] = true
			Remotes.Events.ShowDialogue:FireClient(player, {
				name = ELDER_NAME,
				title = ELDER_TITLE,
				text = ELDER_GREETING,
				-- The client opens the panel once the line is dismissed, so the first
				-- meeting reads as a conversation rather than two popups at once.
				thenOpenNature = payload,
			})
			return
		end

		Remotes.Events.OpenNaturePanel:FireClient(player, payload)
	end)

	Remotes.Events.RequestNatureRoll.OnServerEvent:Connect(function(player)
		-- rollNature refuses a second roll, so this is safe to spam.
		local rolled = ProgressionService.rollNature(player)
		if rolled then
			Remotes.Events.NatureRollResult:FireClient(player, { id = rolled })
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		greeted[player] = nil
	end)

	print("[NatureNPCService] elder placed")
end

return NatureNPCService
