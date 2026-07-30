--!strict
-- Dash on Q, sprint on Shift.
--
-- Dash fires the moment you press, rather than after the server approves — a round
-- trip before you move is instantly noticeable. The client mirrors the server's
-- cooldown and its own chakra reading, so an honest client's request is
-- effectively never refused; MovementService owns the actual ledger.
--
-- Sprint is a pure WalkSpeed multiplier and costs nothing, so it needs no server
-- involvement at all.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Shared = game.ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Remotes = require(Shared.Remotes)

local player = Players.LocalPlayer

local lastDash = 0
local chakra = 0

-- === Sprint ===
--
-- ProgressionService owns WalkSpeed (it derives it from level and reapplies on
-- spawn and level-up), so the sprint multiplier has to sit on top of whatever the
-- server last set rather than hardcoding a base.

local baseSpeed = 16
local sprinting = false

local function applySpeed(humanoid: Humanoid)
	humanoid.WalkSpeed = if sprinting then baseSpeed * GameConfig.SprintMultiplier else baseSpeed
end

local function currentHumanoid(): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function setSprinting(value: boolean)
	if sprinting == value then
		return
	end
	sprinting = value

	local humanoid = currentHumanoid()
	if humanoid then
		applySpeed(humanoid)
	end

	local camera = workspace.CurrentCamera
	if camera then
		TweenService:Create(camera, TweenInfo.new(0.28, Enum.EasingStyle.Quad), {
			FieldOfView = if value
				then 70 + GameConfig.SprintFovBoost
				else 70,
		}):Play()
	end
end

local function watchSpeed(character: Model)
	sprinting = false

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end

	baseSpeed = humanoid.WalkSpeed

	-- Distinguishing the server's writes from our own by *value* rather than a
	-- guard flag: with deferred signal behaviour a flag can clear before the signal
	-- fires, and we'd latch the sprint speed in as the new base and compound it.
	humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		local expected = if sprinting then baseSpeed * GameConfig.SprintMultiplier else baseSpeed
		if math.abs(humanoid.WalkSpeed - expected) < 0.01 then
			return
		end
		baseSpeed = humanoid.WalkSpeed
		applySpeed(humanoid)
	end)
end

if player.Character then
	task.spawn(watchSpeed, player.Character)
end
player.CharacterAdded:Connect(watchSpeed)

-- === Dash animation (optional) ===

local dashTrack: AnimationTrack? = nil

local function loadDashAnimation(character: Model)
	dashTrack = nil
	if GameConfig.DashAnimationId <= 0 then
		return
	end

	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	local animator = humanoid and humanoid:WaitForChild("Animator", 5) :: Animator?
	if not animator then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = `rbxassetid://{GameConfig.DashAnimationId}`

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		dashTrack = track
	else
		warn(`[Movement] couldn't load dash animation (id {GameConfig.DashAnimationId})`)
	end
end

if player.Character then
	task.spawn(loadDashAnimation, player.Character)
end
player.CharacterAdded:Connect(loadDashAnimation)

-- === Cooldown pip ===
-- Sits just above the vitals bars so cooldown state is glanceable.

local gui = Instance.new("ScreenGui")
gui.Name = "ShinobiMovement"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local pip = Instance.new("Frame")
pip.Size = UDim2.fromOffset(58, 22)
pip.AnchorPoint = Vector2.new(0.5, 1)
pip.Position = UDim2.new(0.5, 0, 1, -72)
pip.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
pip.BackgroundTransparency = 0.2
pip.BorderSizePixel = 0
pip.Parent = gui

local pipCorner = Instance.new("UICorner")
pipCorner.CornerRadius = UDim.new(0, 5)
pipCorner.Parent = pip

local pipFill = Instance.new("Frame")
pipFill.Size = UDim2.fromScale(1, 1)
pipFill.BackgroundColor3 = Color3.fromRGB(120, 190, 255)
pipFill.BackgroundTransparency = 0.55
pipFill.BorderSizePixel = 0
pipFill.Parent = pip

local pipFillCorner = Instance.new("UICorner")
pipFillCorner.CornerRadius = UDim.new(0, 5)
pipFillCorner.Parent = pipFill

local pipLabel = Instance.new("TextLabel")
pipLabel.Size = UDim2.fromScale(1, 1)
pipLabel.BackgroundTransparency = 1
pipLabel.Font = Enum.Font.GothamBold
pipLabel.Text = "Q  DASH"
pipLabel.TextSize = 9.5
pipLabel.TextColor3 = Color3.fromRGB(228, 240, 255)
pipLabel.ZIndex = 2
pipLabel.Parent = pip

-- === Dash ===

local function dashDirection(root: BasePart, humanoid: Humanoid): Vector3
	-- Dash where you're steering; fall back to facing if you're standing still.
	local move = humanoid.MoveDirection
	local direction = if move.Magnitude > 0.1 then move else root.CFrame.LookVector
	return Vector3.new(direction.X, 0, direction.Z).Unit
end

local function performDash()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local direction = dashDirection(root, humanoid)

	-- LinearVelocity rather than nudging AssemblyLinearVelocity: the humanoid
	-- controller would immediately fight a direct velocity write, whereas a
	-- constraint holds for its whole duration and then cleanly stops.
	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.MaxForce = math.huge
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VectorVelocity = direction * GameConfig.DashSpeed
		+ Vector3.new(0, GameConfig.DashUpwardBoost, 0)
	velocity.Parent = root

	if dashTrack then
		dashTrack:Play(0.05)
	end

	task.delay(GameConfig.DashDuration, function()
		velocity:Destroy()
		attachment:Destroy()
	end)

	-- Cooldown sweep on the pip.
	pipFill.Size = UDim2.fromScale(0, 1)
	TweenService:Create(
		pipFill,
		TweenInfo.new(GameConfig.DashCooldown, Enum.EasingStyle.Linear),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()
end

local function isSprintKey(code: Enum.KeyCode): boolean
	return code == Enum.KeyCode.LeftShift or code == Enum.KeyCode.RightShift
end

UserInputService.InputBegan:Connect(function(input, processed)
	if isSprintKey(input.KeyCode) and not processed then
		setSprinting(true)
		return
	end

	if processed or input.KeyCode ~= Enum.KeyCode.Q then
		return
	end

	local now = os.clock()
	if now - lastDash < GameConfig.DashCooldown then
		return
	end
	if chakra < GameConfig.DashCost then
		pipLabel.Text = "NO CHAKRA"
		task.delay(0.7, function()
			pipLabel.Text = "Q  DASH"
		end)
		return
	end

	lastDash = now
	performDash()
	Remotes.Events.Dash:FireServer()
end)

-- Release ignores `processed`: if a UI element swallowed the key-up you'd sprint
-- forever. Same reason we stop on focus loss.
UserInputService.InputEnded:Connect(function(input)
	if isSprintKey(input.KeyCode) then
		setSprinting(false)
	end
end)

UserInputService.WindowFocusReleased:Connect(function()
	setSprinting(false)
end)

-- Track chakra so the local gate matches what the server will decide.
Remotes.Events.VitalsUpdated.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" then
		chakra = tonumber(payload.chakra) or 0
	end
end)

Remotes.Events.DashResult.OnClientEvent:Connect(function(payload)
	if type(payload) == "table" and payload.ok == false then
		-- Rare: only if the server disagreed about cooldown or cost. The movement
		-- already happened, so just surface it rather than trying to rewind.
		pipLabel.Text = "TOO SOON"
		task.delay(0.7, function()
			pipLabel.Text = "Q  DASH"
		end)
	end
end)
