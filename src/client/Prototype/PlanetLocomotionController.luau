--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)

local GRAVITY_ATTACHMENT_NAME = "PlanetGravityAttachment"
local GRAVITY_FORCE_NAME = "PlanetGravityForce"
local ALIGN_ORIENTATION_NAME = "PlanetAlignOrientation"
local MOVE_VELOCITY_NAME = "PlanetMoveVelocity"
local GROUND_DEBUG_SPHERE_NAME = "PlanetGroundProbeDebug"

local GROUND_NORMAL_THRESHOLD = 0.35
local GROUND_PROBE_START_HEIGHT = 0
local GROUNDED_VERTICAL_SPEED_THRESHOLD = 1

type GroundProbeResult = {
	isGrounded: boolean,
	hasHit: boolean,
	hasWalkableGround: boolean,
	distance: number?,
	origin: Vector3,
	radius: number,
}

type CharacterBaseParts = { BasePart }

local function getGroundProbeRadius(rootPart: BasePart): number
	return math.max(math.min(rootPart.Size.X, rootPart.Size.Z) * 0.35, 1.5)
end

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
): GroundProbeResult
	local probeRadius = getGroundProbeRadius(rootPart)
	local probeOriginOffset = math.max(characterSupportDistance - probeRadius - GROUND_PROBE_START_HEIGHT, 0)
	local probeOrigin = rootPart.Position - surfaceUp * probeOriginOffset
	local probeDirection = -surfaceUp * LocomotionConstants.groundProbeLength
	local probeResult = Workspace:Spherecast(probeOrigin, probeRadius, probeDirection, raycastParams)
	local maxGroundDistance = GROUND_PROBE_START_HEIGHT + math.max(-LocomotionConstants.groundedDistanceBuffer, 0)

	if probeResult == nil then
		return {
			isGrounded = false,
			hasHit = false,
			hasWalkableGround = false,
			distance = nil,
			origin = probeOrigin,
			radius = probeRadius,
		}
	end

	if probeResult.Instance:IsDescendantOf(character) then
		return {
			isGrounded = false,
			hasHit = false,
			hasWalkableGround = false,
			distance = nil,
			origin = probeOrigin,
			radius = probeRadius,
		}
	end

	local hasWalkableGround = probeResult.Normal:Dot(surfaceUp) >= GROUND_NORMAL_THRESHOLD
	local isGrounded = probeResult.Distance <= maxGroundDistance and hasWalkableGround

	return {
		isGrounded = isGrounded,
		hasHit = true,
		hasWalkableGround = hasWalkableGround,
		distance = probeResult.Distance,
		origin = probeOrigin,
		radius = probeRadius,
	}
end

local function setLocomotionState(character: Model, stateName: string)
	if character:GetAttribute(LocomotionState.attributeName) == stateName then
		return
	end

	character:SetAttribute(LocomotionState.attributeName, stateName)
end

local function getPartSupportDistanceAlongDirection(
	rootPart: BasePart,
	part: BasePart,
	supportDirection: Vector3
): number
	local halfSize = part.Size * 0.5
	local axisX = part.CFrame.XVector
	local axisY = part.CFrame.YVector
	local axisZ = part.CFrame.ZVector
	local relativePosition = part.Position - rootPart.Position

	return -relativePosition:Dot(supportDirection)
		+ math.abs(axisX:Dot(supportDirection)) * halfSize.X
		+ math.abs(axisY:Dot(supportDirection)) * halfSize.Y
		+ math.abs(axisZ:Dot(supportDirection)) * halfSize.Z
end

local function getCharacterBaseParts(character: Model): CharacterBaseParts
	local baseParts = {}

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(baseParts, descendant)
		end
	end

	return baseParts
end

local function getCharacterSupportDistance(
	characterBaseParts: CharacterBaseParts,
	rootPart: BasePart,
	supportDirection: Vector3
): number
	local supportDistance = rootPart.Size:Dot(
		Vector3.new(
			math.abs(rootPart.CFrame.XVector:Dot(supportDirection)),
			math.abs(rootPart.CFrame.YVector:Dot(supportDirection)),
			math.abs(rootPart.CFrame.ZVector:Dot(supportDirection))
		)
	) * 0.5

	for _, part in characterBaseParts do
		supportDistance =
			math.max(supportDistance, getPartSupportDistanceAlongDirection(rootPart, part, supportDirection))
	end

	return supportDistance
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

	local currentCamera = Workspace.CurrentCamera
	if currentCamera == nil then
		return Vector3.zero
	end

	local cameraForward =
		PlanetMath.getPlanarDirection(surfaceUp, currentCamera.CFrame.LookVector, currentCamera.CFrame.UpVector)
	local cameraRight =
		PlanetMath.getPlanarDirection(surfaceUp, currentCamera.CFrame.RightVector, cameraForward:Cross(surfaceUp))
	local desiredMove = cameraRight * inputVector.X + cameraForward * inputVector.Y
	if desiredMove.Magnitude <= 0.01 then
		return Vector3.zero
	end

	return desiredMove.Unit
end

local function translateCharacterWithPlanet(rootPart: BasePart, translationDelta: Vector3)
	if translationDelta.Magnitude <= 0 then
		return
	end

	rootPart.CFrame = CFrame.new(rootPart.Position + translationDelta) * (rootPart.CFrame - rootPart.Position)
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
	setLocomotionState(character, LocomotionState.Idle)
	local characterBaseParts = getCharacterBaseParts(character)

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

	local groundRaycastParams = RaycastParams.new()
	groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRaycastParams.FilterDescendantsInstances = { character }
	groundRaycastParams.IgnoreWater = true

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
			setLocomotionState(character, LocomotionState.Idle)
			return
		end

		local position = rootPart.Position
		local mass = rootPart.AssemblyMass
		local activePlanet = PlanetMath.getActivePlanet(position)

		if activePlanet ~= nil then
			local currentPlanetCenter = PlanetMath.getPlanetCenter(activePlanet)
			if lastPlanetName == activePlanet.name and lastPlanetCenter ~= nil then
				translateCharacterWithPlanet(rootPart, currentPlanetCenter - lastPlanetCenter)
				position = rootPart.Position
			end
			local radialDistance = (position - currentPlanetCenter).Magnitude
			local toCenter = currentPlanetCenter - position
			if toCenter.Magnitude <= 0.001 then
				gravForce.Force = Vector3.zero
				moveVelocity.PlaneVelocity = Vector2.zero
				moveVelocity.Enabled = false
				setLocomotionState(character, LocomotionState.Idle)
				return
			end

			local gravDir = toCenter.Unit
			gravForce.Force = gravDir * activePlanet.surfaceGravity * mass

			local surfaceUp = -gravDir
			local characterSupportDistance = getCharacterSupportDistance(characterBaseParts, rootPart, surfaceUp)
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

			local moveDirection = getDesiredMoveDirection(surfaceUp)
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

			local inheritedSurfaceVelocity =
				PlanetMath.projectOntoPlane(PlanetMath.getRotationalSurfaceVelocity(activePlanet, position), surfaceUp)
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

			setLocomotionState(character, locomotionState)

			if queuedJump and canJumpFromProbe then
				local jumpSpeed = math.sqrt(2 * activePlanet.surfaceGravity * LocomotionConstants.jumpHeight)
				rootPart:ApplyImpulse(surfaceUp * mass * jumpSpeed)
			end
			queuedJump = false
		else
			lastPlanetName = nil
			lastPlanetCenter = nil
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
			updateGroundDebugSphere(groundDebugSphere, rootPart.Position, getGroundProbeRadius(rootPart), false)
			if rootPart.AssemblyLinearVelocity.Magnitude > 1 then
				setLocomotionState(character, LocomotionState.Fall)
			else
				setLocomotionState(character, LocomotionState.Idle)
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
