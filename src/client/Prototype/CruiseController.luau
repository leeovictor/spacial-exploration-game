--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CruiseState = require(ReplicatedStorage.Shared.Prototype.CruiseState)
local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local MovementControllerUtils = require(script.Parent.MovementControllerUtils)

local CRUISE_ATTACHMENT_NAME = "PlanetCruiseAttachment"
local CRUISE_FORCE_NAME = "PlanetCruiseGravityForce"
local CRUISE_ORIENTATION_NAME = "PlanetCruiseOrientation"
local CRUISE_THRUST_NAME = "PlanetCruiseThrust"
local CRUISE_FLIGHT_TILT = CFrame.Angles(math.rad(-90), 0, 0)

local GROUND_NORMAL_THRESHOLD = 0.35

type CruiseControllerOptions = {
	onLandingDetected: (() -> ())?,
}

local function getCruiseForwardDirection(lastDirection: Vector3): Vector3
	local currentCamera = MovementControllerUtils.getCurrentCamera()
	if currentCamera == nil then
		return lastDirection
	end

	local isAcceleratingForward = UserInputService:IsKeyDown(Enum.KeyCode.W)
		or UserInputService:IsKeyDown(Enum.KeyCode.Up)
	if not isAcceleratingForward then
		return lastDirection
	end

	local desiredDirection = currentCamera.CFrame.LookVector
	if desiredDirection.Magnitude <= 0.01 then
		return lastDirection
	end

	return desiredDirection.Unit
end

local CruiseController = {}

function CruiseController.attach(character: Model, options: CruiseControllerOptions?): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if rootPart == nil or humanoid == nil then
		return nil
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true
	MovementControllerUtils.setLocomotionState(character, LocomotionState.Fall)

	local characterBaseParts = MovementControllerUtils.getCharacterBaseParts(character)
	local onLandingDetected = if options ~= nil then options.onLandingDetected else nil

	local cruiseAttachment = Instance.new("Attachment")
	cruiseAttachment.Name = CRUISE_ATTACHMENT_NAME
	cruiseAttachment.CFrame = CFrame.identity
	cruiseAttachment.Parent = rootPart

	local gravForce = Instance.new("VectorForce")
	gravForce.Name = CRUISE_FORCE_NAME
	gravForce.Attachment0 = cruiseAttachment
	gravForce.RelativeTo = Enum.ActuatorRelativeTo.World
	gravForce.Force = Vector3.zero
	gravForce.Parent = rootPart

	local alignOrient = Instance.new("AlignOrientation")
	alignOrient.Name = CRUISE_ORIENTATION_NAME
	alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrient.Attachment0 = cruiseAttachment
	alignOrient.MaxTorque = math.huge
	alignOrient.Responsiveness = 35
	alignOrient.RigidityEnabled = false
	alignOrient.Parent = rootPart

	local cruiseThrust = Instance.new("VectorForce")
	cruiseThrust.Name = CRUISE_THRUST_NAME
	cruiseThrust.Attachment0 = cruiseAttachment
	cruiseThrust.RelativeTo = Enum.ActuatorRelativeTo.World
	cruiseThrust.Force = Vector3.zero
	cruiseThrust.Parent = rootPart

	local groundRaycastParams = MovementControllerUtils.createCharacterRaycastParams(character)
	local lastPlanetName: string? = nil
	local lastPlanetCenter: Vector3? = nil
	local landingTime = 0
	local landingRequested = false
	local cruiseDirection = rootPart.CFrame.LookVector
	local currentCruiseSpeed = LocomotionConstants.cruiseSpeed
	character:SetAttribute(CruiseState.currentSpeedAttributeName, currentCruiseSpeed)

	local heartbeatConn = RunService.Heartbeat:Connect(function(deltaTime)
		if rootPart.Parent == nil then
			return
		end

		if humanoid.Health <= 0 then
			gravForce.Force = Vector3.zero
			cruiseThrust.Force = Vector3.zero
			character:SetAttribute(CruiseState.currentSpeedAttributeName, 0)
			MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			return
		end

		local position = rootPart.Position
		local mass = rootPart.AssemblyMass
		local activePlanet = PlanetMath.getActivePlanet(position)
		local surfaceUp = Vector3.yAxis
		local inheritedVelocity = Vector3.zero

		if activePlanet ~= nil then
			local currentPlanetCenter = PlanetMath.getPlanetCenter(activePlanet)
			if lastPlanetName == activePlanet.name and lastPlanetCenter ~= nil then
				MovementControllerUtils.translateCharacterWithPlanet(rootPart, currentPlanetCenter - lastPlanetCenter)
				position = rootPart.Position
			end

			local toCenter = currentPlanetCenter - position
			if toCenter.Magnitude > 0.001 then
				local gravDir = toCenter.Unit
				surfaceUp = -gravDir
				local radialDistance = math.max((position - currentPlanetCenter).Magnitude, activePlanet.radius)
				local gravityScale = (activePlanet.radius * activePlanet.radius) / (radialDistance * radialDistance)
				local gravityAcceleration = activePlanet.surfaceGravity * gravityScale
				gravForce.Force = gravDir * gravityAcceleration * mass
				inheritedVelocity = PlanetMath.getRotationalSurfaceVelocity(activePlanet, position)

				local characterSupportDistance =
					MovementControllerUtils.getCharacterSupportDistance(characterBaseParts, rootPart, surfaceUp)
				radialDistance = (position - currentPlanetCenter).Magnitude
				local minSurfaceDistance = activePlanet.radius + characterSupportDistance
				if radialDistance < minSurfaceDistance then
					local tangentVelocity = rootPart.AssemblyLinearVelocity
						- surfaceUp * rootPart.AssemblyLinearVelocity:Dot(surfaceUp)
					local outwardVelocity = math.max(0, rootPart.AssemblyLinearVelocity:Dot(surfaceUp))
					rootPart.CFrame = CFrame.new(currentPlanetCenter + surfaceUp * minSurfaceDistance)
						* (rootPart.CFrame - rootPart.Position)
					rootPart.AssemblyLinearVelocity = tangentVelocity + surfaceUp * outwardVelocity
					position = rootPart.Position
				end

				local groundProbe = MovementControllerUtils.getGroundProbeResult(
					character,
					rootPart,
					surfaceUp,
					characterSupportDistance,
					groundRaycastParams,
					LocomotionConstants.cruiseGroundProbeLength,
					LocomotionConstants.cruiseGroundProbeStartHeight,
					GROUND_NORMAL_THRESHOLD,
					LocomotionConstants.groundedDistanceBuffer,
					LocomotionConstants.cruiseGroundProbeRadiusScale
				)
				local verticalSpeed = rootPart.AssemblyLinearVelocity:Dot(surfaceUp)
				local hasLandingStateFromProbe = groundProbe.isGrounded
					or (
						groundProbe.hasWalkableGround
						and verticalSpeed <= LocomotionConstants.cruiseLandingVerticalSpeedThreshold
					)
				local isLanding = hasLandingStateFromProbe
				if isLanding then
					landingTime += deltaTime
					if not landingRequested and landingTime >= LocomotionConstants.cruiseLandingConfirmTime then
						landingRequested = true
						if onLandingDetected ~= nil then
							onLandingDetected()
						end
						return
					end
				else
					landingTime = 0
				end
			else
				gravForce.Force = Vector3.zero
				landingTime = 0
			end

			lastPlanetName = activePlanet.name
			lastPlanetCenter = currentPlanetCenter
		else
			gravForce.Force = Vector3.zero
			lastPlanetName = nil
			lastPlanetCenter = nil
			landingTime = 0
		end

		cruiseDirection = getCruiseForwardDirection(cruiseDirection)
		local accelerationRate = LocomotionConstants.cruiseAcceleration
		if
			UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		then
			accelerationRate = LocomotionConstants.cruiseBoostAcceleration
		end

		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			currentCruiseSpeed =
				math.min(currentCruiseSpeed + accelerationRate * deltaTime, LocomotionConstants.cruiseMaxSpeed)
		elseif UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			currentCruiseSpeed = math.max(
				currentCruiseSpeed - LocomotionConstants.cruiseDeceleration * deltaTime,
				LocomotionConstants.cruiseMinSpeed
			)
		end

		character:SetAttribute(CruiseState.currentSpeedAttributeName, currentCruiseSpeed)
		local currentCamera = MovementControllerUtils.getCurrentCamera()
		local strafeAxis = MovementControllerUtils.getInputAxis(Enum.KeyCode.D, Enum.KeyCode.A)
			+ MovementControllerUtils.getInputAxis(Enum.KeyCode.Right, Enum.KeyCode.Left)
		local strafeVelocity = Vector3.zero
		if strafeAxis ~= 0 then
			local strafeRight = if currentCamera ~= nil
				then currentCamera.CFrame.RightVector
				else rootPart.CFrame.RightVector
			if strafeRight.Magnitude > 0.01 then
				strafeVelocity = strafeRight.Unit * strafeAxis * currentCruiseSpeed
			end
		end

		local cruiseVelocityVector = cruiseDirection * currentCruiseSpeed + strafeVelocity + inheritedVelocity
		local velocityError = cruiseVelocityVector - rootPart.AssemblyLinearVelocity
		local desiredAcceleration = velocityError * LocomotionConstants.cruiseVelocityCorrectionGain
		local desiredForce = desiredAcceleration * mass
		if desiredForce.Magnitude > LocomotionConstants.cruiseMaxForce then
			desiredForce = desiredForce.Unit * LocomotionConstants.cruiseMaxForce
		end
		cruiseThrust.Force = desiredForce

		if currentCamera ~= nil then
			local movementLookDirection = cruiseVelocityVector
			if movementLookDirection.Magnitude <= 0.01 then
				movementLookDirection = currentCamera.CFrame.LookVector
			end

			alignOrient.CFrame = CFrame.lookAt(
				rootPart.Position,
				rootPart.Position + movementLookDirection,
				currentCamera.CFrame.UpVector
			) * CRUISE_FLIGHT_TILT
		else
			local movementLookDirection = cruiseVelocityVector
			if movementLookDirection.Magnitude <= 0.01 then
				movementLookDirection = cruiseDirection
			end

			alignOrient.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + movementLookDirection, surfaceUp)
				* CRUISE_FLIGHT_TILT
		end

		if activePlanet == nil then
			if rootPart.AssemblyLinearVelocity.Magnitude > 1 then
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Fall)
			else
				MovementControllerUtils.setLocomotionState(character, LocomotionState.Idle)
			end
		elseif rootPart.AssemblyLinearVelocity:Dot(surfaceUp) > 1 then
			MovementControllerUtils.setLocomotionState(character, LocomotionState.Jump)
		else
			MovementControllerUtils.setLocomotionState(character, LocomotionState.Fall)
		end
	end)

	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		heartbeatConn:Disconnect()

		if cruiseAttachment.Parent then
			cruiseAttachment:Destroy()
		end
		if gravForce.Parent then
			gravForce:Destroy()
		end
		if cruiseThrust.Parent then
			cruiseThrust:Destroy()
		end
		if alignOrient.Parent then
			alignOrient:Destroy()
		end

		character:SetAttribute(CruiseState.currentSpeedAttributeName, nil)
		character:SetAttribute(LocomotionState.attributeName, nil)

		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return CruiseController
