--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MovementMode = require(ReplicatedStorage.Shared.Prototype.MovementMode)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)

local CAMERA_DISTANCE = 18
local MIN_CAMERA_DISTANCE = 8
local MAX_CAMERA_DISTANCE = 300
local CAMERA_FOCUS_HEIGHT = 2
local CRUISE_CAMERA_FOCUS_HEIGHT = 3.25
local CAMERA_SENSITIVITY = 0.0035
local MIN_PITCH = math.rad(-85)
local MAX_PITCH = math.rad(85)
local CAMERA_COLLISION_BUFFER = 0.75
local CAMERA_ROLL_SPEED = math.rad(120)
local CRUISE_EXIT_BLEND_SPEED = 8
local RENDER_STEP_NAME = "PrototypePlanetCamera"

local function getFallbackForward(surfaceUp: Vector3): Vector3
	local currentCamera = Workspace.CurrentCamera
	if currentCamera ~= nil then
		return PlanetMath.getPlanarDirection(surfaceUp, currentCamera.CFrame.LookVector, currentCamera.CFrame.UpVector)
	end

	return PlanetMath.getPlanarDirection(surfaceUp, Vector3.new(0, 0, -1))
end

local function rotateAroundAxis(vector: Vector3, axis: Vector3, angle: number): Vector3
	return CFrame.fromAxisAngle(axis, angle):VectorToWorldSpace(vector)
end

local function lerpUnitVector(fromVector: Vector3, toVector: Vector3, alpha: number, fallbackVector: Vector3): Vector3
	local blendedVector = fromVector:Lerp(toVector, alpha)
	if blendedVector.Magnitude <= 0.001 then
		return fallbackVector.Unit
	end

	return blendedVector.Unit
end

local function orthonormalizeBasis(
	forwardVector: Vector3,
	upVector: Vector3,
	fallbackForward: Vector3,
	fallbackUp: Vector3
): (Vector3, Vector3)
	local resolvedForward = forwardVector
	if resolvedForward.Magnitude <= 0.001 then
		resolvedForward = fallbackForward
	end
	if resolvedForward.Magnitude <= 0.001 then
		resolvedForward = Vector3.zAxis
	end
	resolvedForward = resolvedForward.Unit

	local resolvedUp = upVector
	if resolvedUp.Magnitude <= 0.001 then
		resolvedUp = fallbackUp
	end
	if resolvedUp.Magnitude <= 0.001 or math.abs(resolvedForward:Dot(resolvedUp.Unit)) >= 0.98 then
		resolvedUp = fallbackUp
	end
	if resolvedUp.Magnitude <= 0.001 or math.abs(resolvedForward:Dot(resolvedUp.Unit)) >= 0.98 then
		resolvedUp = Vector3.yAxis
	end

	local rightVector = resolvedForward:Cross(resolvedUp)
	if rightVector.Magnitude <= 0.001 then
		rightVector = resolvedForward:Cross(Vector3.yAxis)
	end
	if rightVector.Magnitude <= 0.001 then
		rightVector = resolvedForward:Cross(Vector3.xAxis)
	end
	rightVector = rightVector.Unit

	resolvedUp = rightVector:Cross(resolvedForward).Unit
	return resolvedForward, resolvedUp
end

local function getCharacterMovementMode(character: Model): string
	local movementMode = character:GetAttribute(MovementMode.attributeName)
	if type(movementMode) == "string" then
		return movementMode
	end

	return MovementMode.Planet
end

local CameraController = {}

function CameraController.start()
	local player = Players.LocalPlayer
	local activeCleanup: (() -> ())? = nil

	local function onCharacterAdded(character: Model)
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end

		local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
		if rootPart == nil or humanoid == nil then
			return
		end

		local previousMouseBehavior = UserInputService.MouseBehavior
		local previousMouseIconEnabled = UserInputService.MouseIconEnabled
		local previousCameraType = nil :: Enum.CameraType?
		local previousCameraSubject = nil :: Instance?
		local pitch = math.rad(20)
		local cameraDistance = CAMERA_DISTANCE
		local planarForward = getFallbackForward(PlanetMath.getSurfaceUp(rootPart.Position))
		local freeCameraForward = planarForward
		local freeCameraUp = PlanetMath.getSurfaceUp(rootPart.Position)
		local blendedSurfaceUp = freeCameraUp
		local lastPlanetName: string? = nil
		local lastMovementMode = MovementMode.Planet
		local isBlendingFromCruise = false

		local wheelConn = UserInputService.InputChanged:Connect(
			function(input: InputObject, gameProcessedEvent: boolean)
				if gameProcessedEvent then
					return
				end

				if input.UserInputType == Enum.UserInputType.MouseWheel then
					cameraDistance =
						math.clamp(cameraDistance - input.Position.Z * 2, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
				end
			end
		)

		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
			if rootPart.Parent == nil then
				return
			end

			local currentCamera = Workspace.CurrentCamera
			if currentCamera == nil then
				return
			end

			if previousCameraType == nil then
				previousCameraType = currentCamera.CameraType
				previousCameraSubject = currentCamera.CameraSubject
			end

			currentCamera.CameraType = Enum.CameraType.Scriptable
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false

			local movementMode = getCharacterMovementMode(character)
			local modeChanged = movementMode ~= lastMovementMode
			local mouseDelta = UserInputService:GetMouseDelta()

			if movementMode == MovementMode.Cruise then
				if modeChanged then
					freeCameraForward, freeCameraUp = orthonormalizeBasis(
						currentCamera.CFrame.LookVector,
						currentCamera.CFrame.UpVector,
						rootPart.CFrame.LookVector,
						currentCamera.CFrame.UpVector
					)
					isBlendingFromCruise = false
					lastPlanetName = nil
				end

				if mouseDelta.X ~= 0 then
					freeCameraForward =
						rotateAroundAxis(freeCameraForward, freeCameraUp, -mouseDelta.X * CAMERA_SENSITIVITY)
				end

				local freeCameraRight = freeCameraForward:Cross(freeCameraUp)
				if freeCameraRight.Magnitude <= 0.01 then
					freeCameraRight = currentCamera.CFrame.RightVector
				end
				freeCameraRight = freeCameraRight.Unit

				if mouseDelta.Y ~= 0 then
					freeCameraForward =
						rotateAroundAxis(freeCameraForward, freeCameraRight, -mouseDelta.Y * CAMERA_SENSITIVITY)
				end

				if UserInputService:IsKeyDown(Enum.KeyCode.R) then
					freeCameraUp = rotateAroundAxis(freeCameraUp, freeCameraForward, CAMERA_ROLL_SPEED * deltaTime)
				end

				freeCameraForward, freeCameraUp = orthonormalizeBasis(
					freeCameraForward,
					freeCameraUp,
					currentCamera.CFrame.LookVector,
					currentCamera.CFrame.UpVector
				)

				local focusPosition = rootPart.Position + freeCameraUp * CRUISE_CAMERA_FOCUS_HEIGHT
				local desiredCameraPosition = focusPosition - freeCameraForward * cameraDistance

				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Exclude
				raycastParams.FilterDescendantsInstances = { character }

				local raycastResult =
					Workspace:Raycast(focusPosition, desiredCameraPosition - focusPosition, raycastParams)
				local cameraPosition = desiredCameraPosition
				if raycastResult ~= nil then
					local rayDirection = desiredCameraPosition - focusPosition
					local rayDistance = math.max(raycastResult.Distance - CAMERA_COLLISION_BUFFER, 0)
					cameraPosition = focusPosition + rayDirection.Unit * rayDistance
				end

				currentCamera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, freeCameraUp)
				currentCamera.Focus = CFrame.new(focusPosition)
				lastMovementMode = movementMode
				return
			end

			local surfaceUp = PlanetMath.getSurfaceUp(rootPart.Position)
			if modeChanged and lastMovementMode == MovementMode.Cruise then
				planarForward = PlanetMath.getPlanarDirection(
					surfaceUp,
					currentCamera.CFrame.LookVector,
					rootPart.CFrame.LookVector
				)
				pitch = math.clamp(math.asin(-currentCamera.CFrame.LookVector:Dot(surfaceUp)), MIN_PITCH, MAX_PITCH)
				blendedSurfaceUp = currentCamera.CFrame.UpVector
				isBlendingFromCruise = true
				lastPlanetName = nil
			end

			local activePlanet = PlanetMath.getActivePlanet(rootPart.Position)
			if activePlanet ~= nil then
				if lastPlanetName == activePlanet.name then
					planarForward = PlanetMath.rotateVectorWithPlanet(activePlanet, planarForward, deltaTime)
				else
					planarForward = PlanetMath.getPlanarDirection(
						surfaceUp,
						rootPart.CFrame.LookVector,
						currentCamera.CFrame.LookVector
					)
				end
				lastPlanetName = activePlanet.name
			else
				lastPlanetName = nil
			end

			local renderSurfaceUp = surfaceUp
			if isBlendingFromCruise then
				renderSurfaceUp = lerpUnitVector(
					blendedSurfaceUp,
					surfaceUp,
					math.min(deltaTime * CRUISE_EXIT_BLEND_SPEED, 1),
					surfaceUp
				)
				blendedSurfaceUp = renderSurfaceUp
				if renderSurfaceUp:Dot(surfaceUp) >= 0.999 then
					isBlendingFromCruise = false
				end
			end

			planarForward = PlanetMath.projectOntoPlane(planarForward, renderSurfaceUp)
			if planarForward.Magnitude <= 0.01 then
				planarForward = getFallbackForward(renderSurfaceUp)
			else
				planarForward = planarForward.Unit
			end

			if mouseDelta.X ~= 0 then
				planarForward = rotateAroundAxis(planarForward, renderSurfaceUp, -mouseDelta.X * CAMERA_SENSITIVITY)
				planarForward = PlanetMath.projectOntoPlane(planarForward, renderSurfaceUp).Unit
			end

			pitch = math.clamp(pitch + mouseDelta.Y * CAMERA_SENSITIVITY, MIN_PITCH, MAX_PITCH)

			local cameraRight = planarForward:Cross(renderSurfaceUp)
			if cameraRight.Magnitude <= 0.01 then
				cameraRight = rootPart.CFrame.RightVector
			end
			cameraRight = cameraRight.Unit
			planarForward = renderSurfaceUp:Cross(cameraRight).Unit

			local focusPosition = rootPart.Position + renderSurfaceUp * CAMERA_FOCUS_HEIGHT
			local cameraOffset = (-planarForward * math.cos(pitch) + renderSurfaceUp * math.sin(pitch)) * cameraDistance
			local desiredCameraPosition = focusPosition + cameraOffset

			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			raycastParams.FilterDescendantsInstances = { character }

			local raycastResult = Workspace:Raycast(focusPosition, desiredCameraPosition - focusPosition, raycastParams)
			local cameraPosition = desiredCameraPosition
			if raycastResult ~= nil then
				local rayDirection = desiredCameraPosition - focusPosition
				local rayDistance = math.max(raycastResult.Distance - CAMERA_COLLISION_BUFFER, 0)
				cameraPosition = focusPosition + rayDirection.Unit * rayDistance
			end

			currentCamera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, renderSurfaceUp)
			currentCamera.Focus = CFrame.new(focusPosition)
			lastMovementMode = movementMode
		end)

		local cleaned = false
		local function cleanup()
			if cleaned then
				return
			end
			cleaned = true

			wheelConn:Disconnect()
			RunService:UnbindFromRenderStep(RENDER_STEP_NAME)
			UserInputService.MouseBehavior = previousMouseBehavior
			UserInputService.MouseIconEnabled = previousMouseIconEnabled

			local currentCamera = Workspace.CurrentCamera
			if currentCamera ~= nil then
				currentCamera.CameraType = previousCameraType or Enum.CameraType.Custom
				currentCamera.CameraSubject = previousCameraSubject or humanoid
			end
		end

		humanoid.Died:Once(cleanup)
		activeCleanup = cleanup
	end

	local function onCharacterRemoving()
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end
	end

	if player.Character ~= nil then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
end

return CameraController
