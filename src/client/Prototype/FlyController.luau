--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)
local MovementControllerUtils = require(script.Parent.MovementControllerUtils)

local FLY_ATTACHMENT_NAME = "PlanetFlyAttachment"
local FLY_ORIENTATION_NAME = "PlanetFlyOrientation"
local FLY_VELOCITY_NAME = "PlanetFlyVelocity"
local FLY_DEBUG_SPHERE_NAME = "PlanetFlightProbeDebug"

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

local FlyController = {}

type FlyControllerOptions = {
	onCruiseRequested: (() -> ())?,
}

function FlyController.attach(character: Model, options: FlyControllerOptions?): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if rootPart == nil or humanoid == nil then
		return nil
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
	local characterBaseParts = MovementControllerUtils.getCharacterBaseParts(character)
	local onCruiseRequested = if options ~= nil then options.onCruiseRequested else nil

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

	local groundRaycastParams = MovementControllerUtils.createCharacterRaycastParams(character)

	local debugSphere = createFlightDebugSphere()
	local lastPlanetName: string? = nil
	local lastPlanetCenter: Vector3? = nil
	local cruiseRequested = false
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
			MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			return
		end

		local currentTime = PlanetMath.getMotionTime()
		local activePlanet = PlanetMath.getActivePlanet(rootPart.Position, currentTime)
		if activePlanet == nil then
			lastPlanetName = nil
			lastPlanetCenter = nil
			flyVelocity.VectorVelocity = Vector3.zero
			flyVelocity.Enabled = false
			updateFlightDebugSphere(
				debugSphere,
				rootPart.Position,
				MovementControllerUtils.getGroundProbeRadius(rootPart),
				false
			)
			if rootPart.AssemblyLinearVelocity.Magnitude > 1 then
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Fall)
			else
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			end
			return
		end

		local surfaceUp = PlanetMath.getSurfaceUp(rootPart.Position, currentTime)
		local currentPlanetCenter = PlanetMath.getPlanetCenter(activePlanet, currentTime)
		if lastPlanetName == activePlanet.name and lastPlanetCenter ~= nil then
			MovementControllerUtils.translateCharacterWithPlanet(rootPart, currentPlanetCenter - lastPlanetCenter)
		end
		local position = rootPart.Position
		surfaceUp = PlanetMath.getSurfaceUp(position, currentTime)
		local characterSupportDistance =
			MovementControllerUtils.getCharacterSupportDistance(characterBaseParts, rootPart, surfaceUp)
		local groundProbe = MovementControllerUtils.getGroundProbeResult(
			character,
			rootPart,
			surfaceUp,
			characterSupportDistance,
			groundRaycastParams,
			LocomotionConstants.flyProbeLength,
			0,
			-1,
			0
		)
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
			+ PlanetMath.getRotationalSurfaceVelocity(activePlanet, rootPart.Position, currentTime)
		flyVelocity.Enabled = true

		if not cruiseRequested and onCruiseRequested ~= nil then
			local atFlyCeiling = currentHeight
				>= LocomotionConstants.flyMaxHeight - LocomotionConstants.flyHeightEpsilon
			local moveInput = MovementControllerUtils.getMoveInputVector()
			local wantsCruise = atFlyCeiling and UserInputService:IsKeyDown(Enum.KeyCode.Space) and moveInput.Y > 0
			if wantsCruise then
				cruiseRequested = true
				onCruiseRequested()
				return
			end
		end

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
		MovementControllerUtils.setLocomotionState(character, locomotionState)
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
