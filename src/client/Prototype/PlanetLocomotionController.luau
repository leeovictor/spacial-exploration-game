--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local PlanetMath = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("Math"):WaitForChild("PlanetMath")
) :: any
local LocomotionConstants = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("LocomotionConstants")
) :: any

local GRAVITY_ATTACHMENT_NAME = "PlanetGravityAttachment"
local GRAVITY_FORCE_NAME = "PlanetGravityForce"
local ALIGN_ORIENTATION_NAME = "PlanetAlignOrientation"
local MOVE_VELOCITY_NAME = "PlanetMoveVelocity"

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

local PlanetLocomotionController = {}

function PlanetLocomotionController.attach(character: Model): (() -> ())?
	local rootPart = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
	if rootPart == nil or humanoid == nil then
		return nil
	end

	humanoid.AutoRotate = false
	humanoid.PlatformStand = true

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

	local queuedJump = false
	local jumpConn = UserInputService.JumpRequest:Connect(function()
		queuedJump = true
	end)

	local heartbeatConn = RunService.Heartbeat:Connect(function()
		if rootPart.Parent == nil then
			return
		end

		if humanoid.Health <= 0 then
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
			return
		end

		local position = rootPart.Position
		local mass = rootPart.AssemblyMass
		local activePlanet, radialDistance = PlanetMath.getActivePlanet(position)

		if activePlanet ~= nil then
			local toCenter = activePlanet.center - position
			if toCenter.Magnitude <= 0.001 then
				gravForce.Force = Vector3.zero
				moveVelocity.PlaneVelocity = Vector2.zero
				moveVelocity.Enabled = false
				return
			end

			local gravDir = toCenter.Unit
			gravForce.Force = gravDir * activePlanet.surfaceGravity * mass

			local surfaceUp = -gravDir
			local moveDirection = getDesiredMoveDirection(surfaceUp)
			local fallbackVector = Workspace.CurrentCamera and Workspace.CurrentCamera.CFrame.LookVector
				or Vector3.new(0, 0, -1)
			local tangentForward = PlanetMath.getPlanarDirection(surfaceUp, rootPart.CFrame.LookVector, fallbackVector)
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
			gravForce.Force = Vector3.zero
			moveVelocity.PlaneVelocity = Vector2.zero
			moveVelocity.Enabled = false
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

		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end

	humanoid.Died:Once(cleanup)

	return cleanup
end

return PlanetLocomotionController
