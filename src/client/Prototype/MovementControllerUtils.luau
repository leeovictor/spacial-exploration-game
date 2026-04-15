--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocomotionState = require(ReplicatedStorage.Shared.Prototype.LocomotionState)

export type GroundProbeResult = {
	isGrounded: boolean,
	hasHit: boolean,
	hasWalkableGround: boolean,
	distance: number?,
	origin: Vector3,
	radius: number,
}

export type CharacterBaseParts = { BasePart }

local MovementControllerUtils = {}

function MovementControllerUtils.setLocomotionState(character: Model, stateName: string)
	if character:GetAttribute(LocomotionState.attributeName) == stateName then
		return
	end

	character:SetAttribute(LocomotionState.attributeName, stateName)
end

function MovementControllerUtils.getPartSupportDistanceAlongDirection(
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

function MovementControllerUtils.getCharacterBaseParts(character: Model): CharacterBaseParts
	local baseParts = {}

	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(baseParts, descendant)
		end
	end

	return baseParts
end

function MovementControllerUtils.getCharacterSupportDistance(
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
		supportDistance = math.max(
			supportDistance,
			MovementControllerUtils.getPartSupportDistanceAlongDirection(rootPart, part, supportDirection)
		)
	end

	return supportDistance
end

function MovementControllerUtils.getInputAxis(positiveKey: Enum.KeyCode, negativeKey: Enum.KeyCode): number
	local axis = 0
	if UserInputService:IsKeyDown(positiveKey) then
		axis += 1
	end
	if UserInputService:IsKeyDown(negativeKey) then
		axis -= 1
	end
	return axis
end

function MovementControllerUtils.getMoveInputVector(): Vector2
	local inputX = MovementControllerUtils.getInputAxis(Enum.KeyCode.D, Enum.KeyCode.A)
		+ MovementControllerUtils.getInputAxis(Enum.KeyCode.Right, Enum.KeyCode.Left)
	local inputY = MovementControllerUtils.getInputAxis(Enum.KeyCode.W, Enum.KeyCode.S)
		+ MovementControllerUtils.getInputAxis(Enum.KeyCode.Up, Enum.KeyCode.Down)

	local inputVector = Vector2.new(inputX, inputY)
	if inputVector.Magnitude > 1 then
		return inputVector.Unit
	end

	return inputVector
end

function MovementControllerUtils.getCurrentCamera(): Camera?
	return Workspace.CurrentCamera
end

function MovementControllerUtils.getGroundProbeRadius(rootPart: BasePart, radiusScale: number?): number
	local resolvedRadiusScale = if radiusScale ~= nil then radiusScale else 1
	return math.max(math.min(rootPart.Size.X, rootPart.Size.Z) * 0.35 * resolvedRadiusScale, 1.5)
end

function MovementControllerUtils.getDesiredPlanarMoveDirection(surfaceUp: Vector3, planetMath: any): Vector3
	local inputVector = MovementControllerUtils.getMoveInputVector()
	if inputVector.Magnitude <= 0 then
		return Vector3.zero
	end

	local currentCamera = MovementControllerUtils.getCurrentCamera()
	if currentCamera == nil then
		return Vector3.zero
	end

	local cameraForward =
		planetMath.getPlanarDirection(surfaceUp, currentCamera.CFrame.LookVector, currentCamera.CFrame.UpVector)
	local cameraRight =
		planetMath.getPlanarDirection(surfaceUp, currentCamera.CFrame.RightVector, cameraForward:Cross(surfaceUp))
	local desiredMove = cameraRight * inputVector.X + cameraForward * inputVector.Y
	if desiredMove.Magnitude <= 0.01 then
		return Vector3.zero
	end

	return desiredMove.Unit
end

function MovementControllerUtils.translateCharacterWithPlanet(rootPart: BasePart, translationDelta: Vector3)
	if translationDelta.Magnitude <= 0 then
		return
	end

	rootPart.CFrame = CFrame.new(rootPart.Position + translationDelta) * (rootPart.CFrame - rootPart.Position)
end

function MovementControllerUtils.createCharacterRaycastParams(character: Model): RaycastParams
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { character }
	raycastParams.IgnoreWater = true
	return raycastParams
end

function MovementControllerUtils.getGroundProbeResult(
	character: Model,
	rootPart: BasePart,
	surfaceUp: Vector3,
	characterSupportDistance: number,
	raycastParams: RaycastParams,
	probeLength: number,
	groundProbeStartHeight: number,
	groundNormalThreshold: number,
	groundedDistanceBuffer: number,
	probeRadiusScale: number?
): GroundProbeResult
	local probeRadius = MovementControllerUtils.getGroundProbeRadius(rootPart, probeRadiusScale)
	local probeOriginOffset = math.max(characterSupportDistance - probeRadius - groundProbeStartHeight, 0)
	local probeOrigin = rootPart.Position - surfaceUp * probeOriginOffset
	local probeDirection = -surfaceUp * probeLength
	local probeResult = Workspace:Spherecast(probeOrigin, probeRadius, probeDirection, raycastParams)
	local maxGroundDistance = groundProbeStartHeight + math.max(-groundedDistanceBuffer, 0)

	if probeResult == nil or probeResult.Instance:IsDescendantOf(character) then
		return {
			isGrounded = false,
			hasHit = false,
			hasWalkableGround = false,
			distance = nil,
			origin = probeOrigin,
			radius = probeRadius,
		}
	end

	local hasWalkableGround = probeResult.Normal:Dot(surfaceUp) >= groundNormalThreshold
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

return table.freeze(MovementControllerUtils)
