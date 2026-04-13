--!strict

-- GravityController
-- Applies custom gravity toward the nearest planet's center when the character
-- is within that planet's influence radius.
--
-- Approach:
--   - VectorForce on HumanoidRootPart pulls the character toward the planet center.
--   - AlignOrientation keeps the character upright relative to the surface normal.
--   - Humanoid.AutoRotate = false and PlatformStand = true so Roblox's built-in
--     orientation/stepping motors do not fight these constraints.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local PlanetDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("PlanetDefinitions")) :: any
local LocomotionConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("LocomotionConstants")
) :: any

local GRAVITY_ATTACHMENT_NAME = "PlanetGravityAttachment"
local GRAVITY_FORCE_NAME = "PlanetGravityForce"
local ALIGN_ORIENTATION_NAME = "PlanetAlignOrientation"
local MOVE_VELOCITY_NAME = "PlanetMoveVelocity"

type PlanetDef = {
	name: string,
	center: Vector3,
	radius: number,
	surfaceGravity: number,
	influenceRadius: number,
}

local function getActivePlanet(position: Vector3): (PlanetDef?, number)
	local activePlanet: PlanetDef? = nil
	local closestDistance = math.huge

	for _, planet in PlanetDefinitions.planets do
		local distance = (position - planet.center).Magnitude
		if distance < planet.influenceRadius and distance < closestDistance then
			closestDistance = distance
			activePlanet = planet
		end
	end

	return activePlanet, closestDistance
end

local function projectOntoPlane(vector: Vector3, planeNormal: Vector3): Vector3
	return vector - vector:Dot(planeNormal) * planeNormal
end

local function getInputAxis(positiveKey: Enum.KeyCode, negativeKey: Enum.KeyCode): number
	local axis = 0
	if UserInputService:IsKeyDown(positiveKey) then
		axis += 1
	end
	if UserInputService:IsKeyDown(negativeKey) then
		axis -= 1
	end
	return axis
end

local function getDesiredMoveDirection(surfaceUp: Vector3): Vector3
	local inputX = getInputAxis(Enum.KeyCode.D, Enum.KeyCode.A) + getInputAxis(Enum.KeyCode.Right, Enum.KeyCode.Left)
	local inputY = getInputAxis(Enum.KeyCode.W, Enum.KeyCode.S) + getInputAxis(Enum.KeyCode.Up, Enum.KeyCode.Down)

	local inputVector = Vector2.new(inputX, inputY)
	if inputVector.Magnitude <= 0 then
		return Vector3.zero
	end

	if inputVector.Magnitude > 1 then
		inputVector = inputVector.Unit
	end

	local currentCamera = workspace.CurrentCamera
	if currentCamera == nil then
		return Vector3.zero
	end

	local cameraForward = projectOntoPlane(currentCamera.CFrame.LookVector, surfaceUp)
	if cameraForward.Magnitude <= 0.01 then
		cameraForward = projectOntoPlane(currentCamera.CFrame.UpVector, surfaceUp)
	end
	if cameraForward.Magnitude <= 0.01 then
		cameraForward = projectOntoPlane(Vector3.new(0, 0, -1), surfaceUp)
	end

	local cameraRight = projectOntoPlane(currentCamera.CFrame.RightVector, surfaceUp)
	if cameraRight.Magnitude <= 0.01 then
		cameraRight = cameraForward:Cross(surfaceUp)
	end

	if cameraForward.Magnitude <= 0.01 or cameraRight.Magnitude <= 0.01 then
		return Vector3.zero
	end

	cameraForward = cameraForward.Unit
	cameraRight = cameraRight.Unit

	local desiredMove = cameraRight * inputVector.X + cameraForward * inputVector.Y
	if desiredMove.Magnitude <= 0.01 then
		return Vector3.zero
	end

	return desiredMove.Unit
end

local function getStableTangentForward(rootPart: BasePart, surfaceUp: Vector3): Vector3
	local tangentForward = projectOntoPlane(rootPart.CFrame.LookVector, surfaceUp)
	if tangentForward.Magnitude > 0.01 then
		return tangentForward.Unit
	end

	local fallbackForward = projectOntoPlane(
		workspace.CurrentCamera and workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, -1),
		surfaceUp
	)
	if fallbackForward.Magnitude > 0.01 then
		return fallbackForward.Unit
	end

	local axisFallback = surfaceUp:Cross(Vector3.new(1, 0, 0))
	if axisFallback.Magnitude <= 0.01 then
		axisFallback = surfaceUp:Cross(Vector3.new(0, 0, 1))
	end

	return axisFallback.Unit
end

-- -----------------------------------------------------------------------
-- Per-character setup
-- -----------------------------------------------------------------------
local function setupCharacter(character: Model): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if not rootPart or not humanoid then
		return nil
	end

	-- Disable built-in stepping/orientation so our constraints own the character.
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

	-- Attachment on the character root used by both VectorForce and AlignOrientation.
	local gravAttachment = Instance.new("Attachment")
	gravAttachment.Name = GRAVITY_ATTACHMENT_NAME
	gravAttachment.CFrame = CFrame.identity
	gravAttachment.Parent = rootPart

	-- VectorForce: applies directional gravity each heartbeat.
	local gravForce = Instance.new("VectorForce")
	gravForce.Name = GRAVITY_FORCE_NAME
	gravForce.Attachment0 = gravAttachment
	gravForce.RelativeTo = Enum.ActuatorRelativeTo.World
	gravForce.Force = Vector3.zero
	gravForce.Parent = rootPart

	local alignOrient = Instance.new("AlignOrientation")
	alignOrient.Name = ALIGN_ORIENTATION_NAME
	alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrient.Attachment0 = gravAttachment
	alignOrient.MaxTorque = math.huge
	alignOrient.Responsiveness = 30
	alignOrient.RigidityEnabled = false
	alignOrient.Parent = rootPart

	local moveVelocity = Instance.new("LinearVelocity")
	moveVelocity.Name = MOVE_VELOCITY_NAME
	moveVelocity.Attachment0 = gravAttachment
	moveVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	moveVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	moveVelocity.MaxForce = LocomotionConstants.maxAccelerationForce
	moveVelocity.PlaneVelocity = Vector2.zero
	moveVelocity.Enabled = false
	moveVelocity.Parent = rootPart

	local queuedJump = false
	local jumpConn = UserInputService.JumpRequest:Connect(function()
		queuedJump = true
	end)

	-- -----------------------------------------------------------------------
	-- Heartbeat loop
	-- -----------------------------------------------------------------------
	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if not rootPart.Parent then
			return
		end
		if (humanoid :: Humanoid).Health <= 0 then
			gravForce.Force = Vector3.zero
			return
		end

		local position = rootPart.Position
		local mass = rootPart.AssemblyMass
		local activePlanet, radialDistance = getActivePlanet(position)

		if activePlanet ~= nil then
			local toCenter = activePlanet.center - position
			if toCenter.Magnitude <= 0.001 then
				gravForce.Force = Vector3.zero
				moveVelocity.PlaneVelocity = Vector2.zero
				moveVelocity.Enabled = false
				return
			end

			-- Pull toward planet center proportional to mass (F = m*g * direction).
			local gravDir = toCenter.Unit
			gravForce.Force = gravDir * activePlanet.surfaceGravity * mass

			-- Orient character: local up = away from planet center.
			local surfaceUp = -gravDir
			local moveDirection = getDesiredMoveDirection(surfaceUp)
			local tangentForward = getStableTangentForward(rootPart, surfaceUp)
			if moveDirection.Magnitude > 0.01 then
				tangentForward = moveDirection.Unit
			end
			local tangentRight = tangentForward:Cross(surfaceUp)
			if tangentRight.Magnitude <= 0.01 then
				tangentRight = rootPart.CFrame.RightVector
			end
			tangentRight = tangentRight.Unit
			tangentForward = surfaceUp:Cross(tangentRight).Unit

			alignOrient.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + tangentForward, surfaceUp)

			moveVelocity.PrimaryTangentAxis = tangentRight
			moveVelocity.SecondaryTangentAxis = tangentForward
			moveVelocity.Enabled = true

			local desiredVelocity = Vector3.zero
			if moveDirection.Magnitude > 0.01 then
				desiredVelocity = moveDirection.Unit * LocomotionConstants.walkSpeed
			end

			moveVelocity.PlaneVelocity =
				Vector2.new(desiredVelocity:Dot(tangentRight), desiredVelocity:Dot(tangentForward))

			local surfaceOffset = radialDistance - activePlanet.radius
			local groundedDistance = rootPart.Size.Y * 0.5 + LocomotionConstants.groundedDistanceBuffer
			local isGrounded = surfaceOffset <= groundedDistance

			if queuedJump and isGrounded then
				local jumpSpeed = math.sqrt(2 * activePlanet.surfaceGravity * LocomotionConstants.jumpHeight)
				rootPart:ApplyImpulse(surfaceUp * mass * jumpSpeed)
			end
			queuedJump = false
		else
			-- Outside all planet influence — zero gravity (free float in space).
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
			queuedJump = false
		end
	end)

	-- Cleanup function called on death or character removal.
	local function cleanup()
		jumpConn:Disconnect()
		heartbeatConn:Disconnect()
		if gravAttachment.Parent then
			gravAttachment:Destroy()
		end
		if moveVelocity.Parent then
			moveVelocity:Destroy()
		end
		if alignOrient.Parent then
			alignOrient:Destroy()
		end
		if humanoid then
			(humanoid :: Humanoid).AutoRotate = true
			(humanoid :: Humanoid).PlatformStand = false
		end
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

-- -----------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------
local GravityController = {}

function GravityController.start()
	local player = Players.LocalPlayer
	local activeCleanup: (() -> ())? = nil

	local function onCharacterAdded(character: Model)
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end

		activeCleanup = setupCharacter(character)
	end

	local function onCharacterRemoving()
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end
	end

	-- Handle already-spawned character (e.g. if the script runs after spawn).
	if player.Character then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
end

return GravityController
