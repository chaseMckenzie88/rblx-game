--!strict
-- Melee input and hit feedback.
--
-- The client's cooldown here is purely so the UI feels responsive and the remote
-- isn't spammed — CombatService enforces the real one. Never send damage or a
-- target from here; the server decides both.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local lastSwing = 0

-- === Animations ===
--
-- Loaded per character since the Animator dies with the rig. Played from the
-- client the moment you click rather than waiting for MeleeResult — a round trip
-- before the swing animates feels awful. The combo index used here is a local
-- mirror of the server's rules and is cosmetic only; CombatService remains the
-- authority on what actually landed.

local animator: Animator? = nil
local tracks: { [number]: AnimationTrack } = {}
local localCombo = 0

local function loadAnimations(character: Model)
	tracks = {}
	animator = nil

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	local found = humanoid:WaitForChild("Animator", 5) :: Animator?
	if not found then
		return
	end
	animator = found

	for index, assetId in GameConfig.MeleeAnimationIds do
		if type(assetId) ~= "number" or assetId <= 0 then
			continue
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{assetId}`

		-- A bad or unowned asset id throws here rather than at play time.
		local ok, track = pcall(function()
			return found:LoadAnimation(animation)
		end)

		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			tracks[index] = track
		else
			warn(`[Combat] couldn't load melee animation {index} (id {assetId})`)
		end
	end
end

local function playSwing()
	local now = os.clock()
	if now - lastSwing > GameConfig.MeleeComboResetTime then
		localCombo = 0
	end
	localCombo += 1
	if localCombo > GameConfig.MeleeComboLength then
		localCombo = 1
	end

	local track = tracks[localCombo]
	if track then
		track:Stop(0.05)
		track:Play(0.05)
		track:AdjustSpeed(GameConfig.MeleeAnimationSpeed)
	end
end

if player.Character then
	task.spawn(loadAnimations, player.Character)
end
player.CharacterAdded:Connect(loadAnimations)

-- === Input ===

-- Ignore clicks that were meant for the HUD, and don't swing while dead.
local function canSwing(): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return
	end
	if not canSwing() then
		return
	end

	local now = os.clock()
	if now - lastSwing < GameConfig.MeleeCooldown then
		return
	end

	playSwing() -- reads lastSwing, so it runs before the update below
	lastSwing = now

	Remotes.Events.MeleeSwing:FireServer()
end)

-- === Combo counter ===

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiCombat"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.fromOffset(160, 40)
comboLabel.AnchorPoint = Vector2.new(0.5, 1)
comboLabel.Position = UDim2.new(0.5, 0, 1, -62)
comboLabel.BackgroundTransparency = 1
comboLabel.Font = Enum.Font.GothamBlack
comboLabel.TextSize = 26
comboLabel.TextColor3 = Color3.fromRGB(255, 140, 60)
comboLabel.TextStrokeTransparency = 0.4
comboLabel.TextTransparency = 1
comboLabel.Text = ""
comboLabel.Parent = gui

local comboFade: Tween? = nil

Remotes.Events.MeleeResult.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	-- Whiffs shouldn't advertise a combo.
	if (tonumber(payload.hits) or 0) <= 0 then
		return
	end

	comboLabel.Text = if payload.finisher then "FINISH!" else `x{payload.combo}`
	comboLabel.TextColor3 = if payload.finisher
		then Color3.fromRGB(255, 90, 90)
		else Color3.fromRGB(255, 140, 60)
	comboLabel.TextTransparency = 0
	comboLabel.TextStrokeTransparency = 0.4

	if comboFade then
		comboFade:Cancel()
	end
	comboFade = TweenService:Create(comboLabel, TweenInfo.new(0.9, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})
	assert(comboFade):Play()
end)

-- === Floating damage numbers ===

local function spawnDamageNumber(position: Vector3, amount: number, killed: boolean, finisher: boolean)
	local anchor = Instance.new("Part")
	anchor.Name = "DamageAnchor"
	anchor.Size = Vector3.one
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.Anchored = true
	anchor.CanQuery = false
	anchor.CanTouch = false
	-- Jitter so simultaneous hits on one target don't stack into an unreadable blob.
	anchor.Position = position
		+ Vector3.new((math.random() - 0.5) * 2.5, math.random() * 1.2, (math.random() - 0.5) * 2.5)
	anchor.Parent = workspace

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 120
	billboard.Adornee = anchor
	billboard.Parent = anchor

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextSize = if killed then 30 elseif finisher then 26 else 20
	text.TextColor3 = if killed
		then Color3.fromRGB(255, 220, 90)
		elseif finisher then Color3.fromRGB(255, 120, 90)
		else Color3.fromRGB(255, 245, 235)
	text.TextStrokeTransparency = 0.35
	text.Text = tostring(amount)
	text.Parent = billboard

	local rise = TweenService:Create(anchor, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = anchor.Position + Vector3.new(0, 5.5, 0),
	})
	local fade = TweenService:Create(text, TweenInfo.new(0.85, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	})

	rise:Play()
	fade:Play()

	task.delay(0.95, function()
		anchor:Destroy()
	end)
end

Remotes.Events.DamageDealt.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or typeof(payload.position) ~= "Vector3" then
		return
	end
	spawnDamageNumber(
		payload.position,
		tonumber(payload.amount) or 0,
		payload.killed == true,
		payload.finisher == true
	)
end)
