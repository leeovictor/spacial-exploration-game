--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("Math"):WaitForChild("PlanetMath")
) :: any

local CAMERA_DISTANCE = 18
local MIN_CAMERA_DISTANCE = 8
local MAX_CAMERA_DISTANCE = 300
local CAMERA_FOCUS_HEIGHT = 4
local CAMERA_SENSITIVITY = 0.0035
local MIN_PITCH = math.rad(-75)
local MAX_PITCH = math.rad(55)
local CAMERA_COLLISION_BUFFER = 0.75
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

		RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function()
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

			local surfaceUp = PlanetMath.getSurfaceUp(rootPart.Position)
			planarForward = PlanetMath.projectOntoPlane(planarForward, surfaceUp)
			if planarForward.Magnitude <= 0.01 then
				planarForward = getFallbackForward(surfaceUp)
			else
				planarForward = planarForward.Unit
			end

			local mouseDelta = UserInputService:GetMouseDelta()
			if mouseDelta.X ~= 0 then
				planarForward = rotateAroundAxis(planarForward, surfaceUp, -mouseDelta.X * CAMERA_SENSITIVITY)
				planarForward = PlanetMath.projectOntoPlane(planarForward, surfaceUp).Unit
			end

			pitch = math.clamp(pitch + mouseDelta.Y * CAMERA_SENSITIVITY, MIN_PITCH, MAX_PITCH)

			local cameraRight = planarForward:Cross(surfaceUp)
			if cameraRight.Magnitude <= 0.01 then
				cameraRight = rootPart.CFrame.RightVector
			end
			cameraRight = cameraRight.Unit
			planarForward = surfaceUp:Cross(cameraRight).Unit

			local focusPosition = rootPart.Position + surfaceUp * CAMERA_FOCUS_HEIGHT
			local cameraOffset = (-planarForward * math.cos(pitch) + surfaceUp * math.sin(pitch)) * cameraDistance
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

			currentCamera.CFrame = CFrame.lookAt(cameraPosition, focusPosition, surfaceUp)
			currentCamera.Focus = CFrame.new(focusPosition)
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
