--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)

local FLY_ATTACHMENT_NAME = "PlanetFlyAttachment"
local FLY_ORIENTATION_NAME = "PlanetFlyOrientation"
local FLY_VELOCITY_NAME = "PlanetFlyVelocity"
local FLY_DEBUG_SPHERE_NAME = "PlanetFlightProbeDebug"

type GroundProbeResult = {
	hasHit: boolean,
	distance: number?,
	origin: Vector3,
	radius: number,
}

type CharacterBaseParts = { BasePart }

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

local function createFlightDebugSphere(): Part?
	if not RunService:IsStudio() then
		return nil
	end

	local debugSphere = Instance.new("Part")
	debugSphere.Name = FLY_DEBUG_SPHERE_NAME
	debugSphere.Shape = Enum.PartType.Ball
	debugSphere.Anchored = true
	debugSphere.CanCollide = false
	debugSphere.CanQuery = false
	debugSphere.CanTouch = false
	debugSphere.CastShadow = false
	debugSphere.Locked = true
	debugSphere.Material = Enum.Material.Neon
	debugSphere.Transparency = 0.8
	debugSphere.Size = Vector3.one
	debugSphere.Parent = Workspace

	return debugSphere
end

local function updateFlightDebugSphere(
	debugSphere: Part?,
	position: Vector3,
	radius: number,
	isWithinFlightBand: boolean
)
	if debugSphere == nil then
		return
	end

	debugSphere.CFrame = CFrame.new(position)
	debugSphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	debugSphere.Color = if isWithinFlightBand then Color3.fromRGB(110, 180, 255) else Color3.fromRGB(255, 170, 110)
	debugSphere.Transparency = if isWithinFlightBand then 0.75 else 0.55
end

local function getGroundProbeRadius(rootPart: BasePart): number
	return math.max(math.min(rootPart.Size.X, rootPart.Size.Z) * 0.35, 1.5)
end

local function getGroundProbeResult(
	character: Model,
	rootPart: BasePart,
	surfaceUp: Vector3,
	characterSupportDistance: number,
	raycastParams: RaycastParams
): GroundProbeResult
	local probeRadius = getGroundProbeRadius(rootPart)
	local probeOriginOffset = math.max(characterSupportDistance - probeRadius, 0)
	local probeOrigin = rootPart.Position - surfaceUp * probeOriginOffset
	local probeDirection = -surfaceUp * LocomotionConstants.flyProbeLength
	local probeResult = Workspace:Spherecast(probeOrigin, probeRadius, probeDirection, raycastParams)

	if probeResult == nil or probeResult.Instance:IsDescendantOf(character) then
		return {
			hasHit = false,
			distance = nil,
			origin = probeOrigin,
			radius = probeRadius,
		}
	end

	return {
		hasHit = true,
		distance = probeResult.Distance,
		origin = probeOrigin,
		radius = probeRadius,
	}
end

local FlyController = {}

function FlyController.attach(character: Model): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if rootPart == nil or humanoid == nil then
		return nil
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	setLocomotionState(character, LocomotionState.Idle)
	local characterBaseParts = getCharacterBaseParts(character)

	local flyAttachment = Instance.new("Attachment")
	flyAttachment.Name = FLY_ATTACHMENT_NAME
	flyAttachment.CFrame = CFrame.identity
	flyAttachment.Parent = rootPart

	local alignOrient = Instance.new("AlignOrientation")
	alignOrient.Name = FLY_ORIENTATION_NAME
	alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrient.Attachment0 = flyAttachment
	alignOrient.MaxTorque = math.huge
	alignOrient.Responsiveness = 35
	alignOrient.RigidityEnabled = false
	alignOrient.Parent = rootPart

	local flyVelocity = Instance.new("LinearVelocity")
	flyVelocity.Name = FLY_VELOCITY_NAME
	flyVelocity.Attachment0 = flyAttachment
	flyVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	flyVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	flyVelocity.MaxForce = LocomotionConstants.maxAccelerationForce * 2
	flyVelocity.VectorVelocity = Vector3.zero
	flyVelocity.Enabled = true
	flyVelocity.Parent = rootPart

	local groundRaycastParams = RaycastParams.new()
	groundRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
	groundRaycastParams.FilterDescendantsInstances = { character }
	groundRaycastParams.IgnoreWater = true

	local debugSphere = createFlightDebugSphere()
	local lastPlanetName: string? = nil
	local lastPlanetCenter: Vector3? = nil
	local tangentForward = PlanetMath.getPlanarDirection(
		PlanetMath.getSurfaceUp(rootPart.Position),
		rootPart.CFrame.LookVector,
		Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector or Vector3.new(0, 0, -1)
	)

	local heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if rootPart.Parent == nil then
			return
		end

		if humanoid.Health <= 0 then
			flyVelocity.VectorVelocity = Vector3.zero
			flyVelocity.Enabled = false
			setLocomotionState(character, LocomotionState.Idle)
			return
		end

		local activePlanet = PlanetMath.getActivePlanet(rootPart.Position)
		if activePlanet == nil then
			lastPlanetName = nil
			lastPlanetCenter = nil
			flyVelocity.VectorVelocity = Vector3.zero
			flyVelocity.Enabled = false
			updateFlightDebugSphere(debugSphere, rootPart.Position, getGroundProbeRadius(rootPart), false)
			if rootPart.AssemblyLinearVelocity.Magnitude > 1 then
				setLocomotionState(character, LocomotionState.Fall)
			else
				setLocomotionState(character, LocomotionState.Idle)
			end
			return
		end

		local surfaceUp = PlanetMath.getSurfaceUp(rootPart.Position)
		local currentPlanetCenter = PlanetMath.getPlanetCenter(activePlanet)
		if lastPlanetName == activePlanet.name and lastPlanetCenter ~= nil then
			translateCharacterWithPlanet(rootPart, currentPlanetCenter - lastPlanetCenter)
		end
		local position = rootPart.Position
		surfaceUp = PlanetMath.getSurfaceUp(position)
		local characterSupportDistance = getCharacterSupportDistance(characterBaseParts, rootPart, surfaceUp)
		local groundProbe =
			getGroundProbeResult(character, rootPart, surfaceUp, characterSupportDistance, groundRaycastParams)
		local currentHeight = groundProbe.distance
		if currentHeight == nil then
			currentHeight =
				math.max((position - currentPlanetCenter).Magnitude - activePlanet.radius - characterSupportDistance, 0)
		end

		if currentHeight > LocomotionConstants.flyMaxHeight + LocomotionConstants.flyHeightEpsilon then
			local clampedPosition = rootPart.Position
				- surfaceUp * ((currentHeight :: number) - LocomotionConstants.flyMaxHeight)
			rootPart.CFrame = CFrame.new(clampedPosition) * (rootPart.CFrame - rootPart.Position)

			local surfaceVelocity = rootPart.AssemblyLinearVelocity
			local tangentVelocity = surfaceVelocity - surfaceUp * surfaceVelocity:Dot(surfaceUp)
			local inwardVelocity = math.min(surfaceVelocity:Dot(surfaceUp), 0)
			rootPart.AssemblyLinearVelocity = tangentVelocity + surfaceUp * inwardVelocity
			currentHeight = LocomotionConstants.flyMaxHeight
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

		local flightLookDirection = -surfaceUp
		alignOrient.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flightLookDirection, tangentForward)

		local desiredHorizontalVelocity = Vector3.zero
		if moveDirection.Magnitude > 0.01 then
			desiredHorizontalVelocity = moveDirection * LocomotionConstants.flySpeed
		end

		local verticalAxis = 0
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			verticalAxis += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.C) then
			verticalAxis -= 1
		end

		local desiredVerticalSpeed = 0
		if
			verticalAxis > 0
			and currentHeight < LocomotionConstants.flyMaxHeight - LocomotionConstants.flyHeightEpsilon
		then
			desiredVerticalSpeed = LocomotionConstants.flyVerticalSpeed
		elseif verticalAxis < 0 and currentHeight > LocomotionConstants.flyHeightEpsilon then
			desiredVerticalSpeed = -LocomotionConstants.flyVerticalSpeed
		end

		flyVelocity.VectorVelocity = desiredHorizontalVelocity
			+ surfaceUp * desiredVerticalSpeed
			+ PlanetMath.getRotationalSurfaceVelocity(activePlanet, rootPart.Position)
		flyVelocity.Enabled = true
		updateFlightDebugSphere(
			debugSphere,
			groundProbe.origin,
			groundProbe.radius,
			currentHeight <= LocomotionConstants.flyMaxHeight + LocomotionConstants.flyHeightEpsilon
		)

		local locomotionState = LocomotionState.Idle
		if desiredVerticalSpeed > 0.01 then
			locomotionState = LocomotionState.Jump
		elseif desiredHorizontalVelocity.Magnitude > 0.01 or desiredVerticalSpeed < -0.01 then
			locomotionState = LocomotionState.Fall
		end
		setLocomotionState(character, locomotionState)
	end)

	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		heartbeatConn:Disconnect()

		if flyAttachment.Parent then
			flyAttachment:Destroy()
		end
		if flyVelocity.Parent then
			flyVelocity:Destroy()
		end
		if alignOrient.Parent then
			alignOrient:Destroy()
		end
		if debugSphere ~= nil and debugSphere.Parent then
			debugSphere:Destroy()
		end

		character:SetAttribute(LocomotionState.attributeName, nil)

		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return FlyController
