--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)
local MovementControllerUtils = require(script.Parent.MovementControllerUtils)

local GRAVITY_ATTACHMENT_NAME = "PlanetGravityAttachment"
local GRAVITY_FORCE_NAME = "PlanetGravityForce"
local ALIGN_ORIENTATION_NAME = "PlanetAlignOrientation"
local MOVE_VELOCITY_NAME = "PlanetMoveVelocity"
local GROUND_DEBUG_SPHERE_NAME = "PlanetGroundProbeDebug"

local GROUND_NORMAL_THRESHOLD = 0.35
local GROUND_PROBE_START_HEIGHT = 0
local GROUNDED_VERTICAL_SPEED_THRESHOLD = 1

local function createGroundDebugSphere(): Part?
	if not RunService:IsStudio() then
		return nil
	end

	local debugSphere = Instance.new("Part")
	debugSphere.Name = GROUND_DEBUG_SPHERE_NAME
	debugSphere.Shape = Enum.PartType.Ball
	debugSphere.Anchored = true
	debugSphere.CanCollide = false
	debugSphere.CanQuery = false
	debugSphere.CanTouch = false
	debugSphere.CastShadow = false
	debugSphere.Locked = true
	debugSphere.Material = Enum.Material.ForceField
	debugSphere.Transparency = 0.75
	debugSphere.Size = Vector3.one
	debugSphere.Parent = Workspace

	return debugSphere
end

local function updateGroundDebugSphere(debugSphere: Part?, position: Vector3, radius: number, isGrounded: boolean)
	if debugSphere == nil then
		return
	end

	debugSphere.CFrame = CFrame.new(position)
	debugSphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	debugSphere.Color = if isGrounded then Color3.fromRGB(110, 255, 140) else Color3.fromRGB(255, 120, 120)
	debugSphere.Transparency = if isGrounded then 0.55 else 0.8
end

local function getGroundProbeResult(
	character: Model,
	rootPart: BasePart,
	surfaceUp: Vector3,
	characterSupportDistance: number,
	raycastParams: RaycastParams
): MovementControllerUtils.GroundProbeResult
	return MovementControllerUtils.getGroundProbeResult(
		character,
		rootPart,
		surfaceUp,
		characterSupportDistance,
		raycastParams,
		LocomotionConstants.groundProbeLength,
		GROUND_PROBE_START_HEIGHT,
		GROUND_NORMAL_THRESHOLD,
		LocomotionConstants.groundedDistanceBuffer
	)
end

local PlanetLocomotionController = {}

function PlanetLocomotionController.attach(character: Model): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if rootPart == nil or humanoid == nil then
		return nil
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
	local characterBaseParts = MovementControllerUtils.getCharacterBaseParts(character)

	local gravAttachment = Instance.new("Attachment")
	gravAttachment.Name = GRAVITY_ATTACHMENT_NAME
	gravAttachment.CFrame = CFrame.identity
	gravAttachment.Parent = rootPart

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

	local groundRaycastParams = MovementControllerUtils.createCharacterRaycastParams(character)

	local groundDebugSphere = createGroundDebugSphere()

	local queuedJump = false
	local lastPlanetName: string? = nil
	local lastPlanetCenter: Vector3? = nil
	local tangentForward = PlanetMath.getPlanarDirection(
		PlanetMath.getSurfaceUp(rootPart.Position),
		rootPart.CFrame.LookVector,
		Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, -1)
	)
	local jumpConn = UserInputService.JumpRequest:Connect(function()
		queuedJump = true
	end)

	local heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if rootPart.Parent == nil then
			return
		end

		if humanoid.Health <= 0 then
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
			MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			return
		end

		local position = rootPart.Position
		local mass = rootPart.AssemblyMass
		local currentTime = PlanetMath.getMotionTime()
		local activePlanet = PlanetMath.getActivePlanet(position, currentTime)

		if activePlanet ~= nil then
			local currentPlanetCenter = PlanetMath.getPlanetCenter(activePlanet, currentTime)
			if lastPlanetName == activePlanet.name and lastPlanetCenter ~= nil then
				MovementControllerUtils.translateCharacterWithPlanet(rootPart, currentPlanetCenter - lastPlanetCenter)
				position = rootPart.Position
			end
			local radialDistance = (position - currentPlanetCenter).Magnitude
			local toCenter = currentPlanetCenter - position
			if toCenter.Magnitude <= 0.001 then
				gravForce.Force = Vector3.zero
				moveVelocity.PlaneVelocity = Vector2.zero
				moveVelocity.Enabled = false
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
				return
			end

			local gravDir = toCenter.Unit
			gravForce.Force = gravDir * activePlanet.gravity * mass

			local surfaceUp = -gravDir
			local characterSupportDistance =
				MovementControllerUtils.getCharacterSupportDistance(characterBaseParts, rootPart, surfaceUp)
			local minSurfaceDistance = activePlanet.radius + characterSupportDistance
			if radialDistance < minSurfaceDistance then
				local tangentVelocity = rootPart.AssemblyLinearVelocity
					- surfaceUp * rootPart.AssemblyLinearVelocity:Dot(surfaceUp)
				local outwardVelocity = math.max(0, rootPart.AssemblyLinearVelocity:Dot(surfaceUp))
				rootPart.CFrame = CFrame.new(currentPlanetCenter + surfaceUp * minSurfaceDistance)
					* (rootPart.CFrame - rootPart.Position)
				rootPart.AssemblyLinearVelocity = tangentVelocity + surfaceUp * outwardVelocity
				position = rootPart.Position
				radialDistance = minSurfaceDistance
			end

			local moveDirection = MovementControllerUtils.getDesiredPlanarMoveDirection(surfaceUp, PlanetMath)
			local fallbackVector = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector
				or Vector3.new(0, 0, -1)
			if lastPlanetName == activePlanet.name then
				tangentForward = PlanetMath.rotateVectorWithPlanet(activePlanet, tangentForward, deltaTime)
			else
				tangentForward = PlanetMath.getPlanarDirection(surfaceUp, rootPart.CFrame.LookVector, fallbackVector)
			end
			lastPlanetName = activePlanet.name
			lastPlanetCenter = currentPlanetCenter
			tangentForward = PlanetMath.getPlanarDirection(surfaceUp, tangentForward, fallbackVector)
			if moveDirection.Magnitude > 0.01 then
				tangentForward = moveDirection
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
				desiredVelocity = moveDirection * LocomotionConstants.walkSpeed
			end

			local inheritedSurfaceVelocity = PlanetMath.projectOntoPlane(
				PlanetMath.getRotationalSurfaceVelocity(activePlanet, position, currentTime),
				surfaceUp
			)
			local totalDesiredVelocity = desiredVelocity + inheritedSurfaceVelocity

			moveVelocity.PlaneVelocity =
				Vector2.new(totalDesiredVelocity:Dot(tangentRight), totalDesiredVelocity:Dot(tangentForward))

			local groundProbe =
				getGroundProbeResult(character, rootPart, surfaceUp, characterSupportDistance, groundRaycastParams)
			updateGroundDebugSphere(groundDebugSphere, groundProbe.origin, groundProbe.radius, groundProbe.isGrounded)
			local locomotionState = LocomotionState.Idle
			local verticalSpeed = rootPart.AssemblyLinearVelocity:Dot(surfaceUp)
			local hasGroundedStateFromProbe = groundProbe.isGrounded
				or (groundProbe.hasWalkableGround and verticalSpeed <= GROUNDED_VERTICAL_SPEED_THRESHOLD)
			local canJumpFromProbe = groundProbe.hasWalkableGround
				and verticalSpeed <= GROUNDED_VERTICAL_SPEED_THRESHOLD

			if hasGroundedStateFromProbe then
				if desiredVelocity.Magnitude > 0.01 then
					locomotionState = LocomotionState.Walk
				end
			else
				if verticalSpeed > 1 then
					locomotionState = LocomotionState.Jump
				else
					locomotionState = LocomotionState.Fall
				end
			end

			MovementControllerUtils.setLocomotionState(character, locomotionState)

			if queuedJump and canJumpFromProbe then
				local jumpSpeed = math.sqrt(2 * activePlanet.gravity * LocomotionConstants.jumpHeight)
				rootPart:ApplyImpulse(surfaceUp * mass * jumpSpeed)
			end
			queuedJump = false
		else
			lastPlanetName = nil
			lastPlanetCenter = nil
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
			updateGroundDebugSphere(
				groundDebugSphere,
				rootPart.Position,
				MovementControllerUtils.getGroundProbeRadius(rootPart),
				false
			)
			if rootPart.AssemblyLinearVelocity.Magnitude > 1 then
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Fall)
			else
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			end
			queuedJump = false
		end
	end)

	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		jumpConn:Disconnect()
		heartbeatConn:Disconnect()

		if gravAttachment.Parent then
			gravAttachment:Destroy()
		end
		if gravForce.Parent then
			gravForce:Destroy()
		end
		if moveVelocity.Parent then
			moveVelocity:Destroy()
		end
		if alignOrient.Parent then
			alignOrient:Destroy()
		end
		if groundDebugSphere ~= nil and groundDebugSphere.Parent then
			groundDebugSphere:Destroy()
		end

		character:SetAttribute(LocomotionState.attributeName, nil)

		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return PlanetLocomotionController
