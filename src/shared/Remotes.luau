--!strict
-- Creates remotes on the server, waits for them on the client. Both sides
-- require this module and index the same names, so a typo is a nil error at
-- startup instead of a message that silently goes nowhere.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"ProfileUpdated",   -- server -> client, full profile snapshot
	"SpendStatPoint",   -- client -> server, { stat: StatName }
	"RollNature",       -- client -> server
	"Notify",           -- server -> client, { text: string }
	"DebugAwardXP",     -- client -> server, Studio only (server refuses in live games)

	-- Combat. The client only ever *requests* a swing; the server picks targets
	-- and decides damage, so a tampered client can spam but can't hit harder.
	"MeleeSwing",       -- client -> server, request a swing
	"MeleeResult",      -- server -> client, { combo, finisher, hits }
	"DamageDealt",      -- server -> client, { position, amount, killed }
	"VitalsUpdated",    -- server -> client, { chakra, maxChakra }

	-- Quests
	"QuestUpdated",     -- server -> client, { active: {...}? }
	"OpenQuestBoard",   -- server -> client, { giver: {...}, quests: {...} }
	"ShowDialogue",     -- server -> client, { name, title, text } — one-time NPC line
	"AcceptQuest",      -- client -> server, { id: string }
	"AbandonQuest",     -- client -> server

	-- Movement
	"Dash",             -- client -> server, request a dash (server bills the chakra)
	"DashResult",       -- server -> client, { ok: boolean }

	-- Chakra nature
	"OpenNaturePanel",  -- server -> client, { hasNature, natureId? }
	"RequestNatureRoll",-- client -> server
	"NatureRollResult", -- server -> client, { id } — the reel lands on this
}

local FUNCTIONS = {
	"GetProfile",       -- client -> server, returns Profile
}

local isServer = RunService:IsServer()

local function container(): Folder
	if isServer then
		local folder = ReplicatedStorage:FindFirstChild("Remotes")
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = "Remotes"
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild("Remotes", 30) :: Folder
end

local function resolve(parent: Folder, name: string, className: string): Instance
	if isServer then
		local existing = parent:FindFirstChild(name)
		if existing then
			return existing
		end
		local remote = Instance.new(className)
		remote.Name = name
		remote.Parent = parent
		return remote
	end
	return parent:WaitForChild(name, 30)
end

local folder = container()

local Remotes = {
	Events = {} :: { [string]: RemoteEvent },
	Functions = {} :: { [string]: RemoteFunction },
}

for _, name in EVENTS do
	Remotes.Events[name] = resolve(folder, name, "RemoteEvent") :: RemoteEvent
end

for _, name in FUNCTIONS do
	Remotes.Functions[name] = resolve(folder, name, "RemoteFunction") :: RemoteFunction
end

return Remotes
