--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)

type PlanetDef = {
	name: string,
	center: Vector3,
	radius: number,
	surfaceGravity: number,
	influenceRadius: number,
	rotationAxis: Vector3,
	angularSpeed: number,
	orbitCenter: Vector3?,
	orbitAxis: Vector3?,
	orbitAngularSpeed: number?,
}

type PlanetRotationState = {
	planet: PlanetDef,
	orbitAxisPart: Part?,
	orbitReferenceMarker: Part?,
}

local heartbeatConnection: RBXScriptConnection? = nil
local planetStates: { [Model]: PlanetRotationState } = {}

local PlanetRotationController = {}

local function createOrbitAxisPart(planet: PlanetDef): Part?
	if planet.orbitCenter == nil then
		return nil
	end

	local axis = PlanetMath.getOrbitAxis(planet)
	local axisLength = math.max((planet.center - planet.orbitCenter).Magnitude * 2.4, planet.radius * 4)
	local thickness = math.max(planet.radius * 0.03, 0.75)
	local upVector = if math.abs(axis:Dot(Vector3.yAxis)) > 0.98 then Vector3.xAxis else Vector3.yAxis

	local axisPart = Instance.new("Part")
	axisPart.Name = string.format("%sOrbitAxisDebug", planet.name)
	axisPart.Anchored = true
	axisPart.CanCollide = false
	axisPart.CanQuery = false
	axisPart.CanTouch = false
	axisPart.CastShadow = false
	axisPart.Locked = true
	axisPart.Material = Enum.Material.Neon
	axisPart.Color = Color3.fromRGB(255, 145, 64)
	axisPart.Transparency = 0.2
	axisPart.Size = Vector3.new(thickness, thickness, axisLength)
	axisPart.CFrame = CFrame.lookAt(planet.orbitCenter, planet.orbitCenter + axis, upVector)
	axisPart.Parent = Workspace

	return axisPart
end

local function createOrbitReferenceMarker(planet: PlanetDef): Part?
	if planet.orbitCenter == nil then
		return nil
	end

	local marker = Instance.new("Part")
	marker.Name = string.format("%sOrbitReferenceDebug", planet.name)
	marker.Shape = Enum.PartType.Ball
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.CastShadow = false
	marker.Locked = true
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(255, 82, 82)
	marker.Transparency = 0.05
	marker.Size = Vector3.one * math.max(planet.radius * 0.15, 2)
	marker.CFrame = CFrame.new(PlanetMath.getOrbitCenter(planet))
	marker.Parent = Workspace

	return marker
end

local function updateOrbitDebug(state: PlanetRotationState)
	if state.planet.orbitCenter == nil then
		if state.orbitAxisPart ~= nil and state.orbitAxisPart.Parent ~= nil then
			state.orbitAxisPart:Destroy()
		end
		if state.orbitReferenceMarker ~= nil and state.orbitReferenceMarker.Parent ~= nil then
			state.orbitReferenceMarker:Destroy()
		end
		state.orbitAxisPart = nil
		state.orbitReferenceMarker = nil
		return
	end

	local orbitCenter = PlanetMath.getOrbitCenter(state.planet)
	local orbitAxis = PlanetMath.getOrbitAxis(state.planet)
	local axisLength = math.max((state.planet.center - orbitCenter).Magnitude * 2.4, state.planet.radius * 4)
	local thickness = math.max(state.planet.radius * 0.03, 0.75)
	local upVector = if math.abs(orbitAxis:Dot(Vector3.yAxis)) > 0.98 then Vector3.xAxis else Vector3.yAxis

	if state.orbitAxisPart == nil or state.orbitAxisPart.Parent == nil then
		state.orbitAxisPart = createOrbitAxisPart(state.planet)
	end
	if state.orbitReferenceMarker == nil or state.orbitReferenceMarker.Parent == nil then
		state.orbitReferenceMarker = createOrbitReferenceMarker(state.planet)
	end

	if state.orbitAxisPart ~= nil then
		state.orbitAxisPart.Size = Vector3.new(thickness, thickness, axisLength)
		state.orbitAxisPart.CFrame = CFrame.lookAt(orbitCenter, orbitCenter + orbitAxis, upVector)
		state.orbitAxisPart.Parent = Workspace
	end

	if state.orbitReferenceMarker ~= nil then
		state.orbitReferenceMarker.CFrame = CFrame.new(orbitCenter)
		state.orbitReferenceMarker.Parent = Workspace
	end
end

local function refreshPlanetStates()
	local nextStates: { [Model]: PlanetRotationState } = {}

	for _, planet in PlanetDefinitions.planets do
		local planetModel = Workspace:FindFirstChild(planet.name)
		if planetModel ~= nil and planetModel:IsA("Model") then
			local existingState = planetStates[planetModel]
			local nextState = {
				planet = planet,
				orbitAxisPart = if existingState ~= nil then existingState.orbitAxisPart else nil,
				orbitReferenceMarker = if existingState ~= nil then existingState.orbitReferenceMarker else nil,
			}
			updateOrbitDebug(nextState)
			nextStates[planetModel] = nextState
		end
	end

	for planetModel, state in planetStates do
		if nextStates[planetModel] == nil then
			if state.orbitAxisPart ~= nil and state.orbitAxisPart.Parent ~= nil then
				state.orbitAxisPart:Destroy()
			end
			if state.orbitReferenceMarker ~= nil and state.orbitReferenceMarker.Parent ~= nil then
				state.orbitReferenceMarker:Destroy()
			end
		end
	end

	planetStates = nextStates
end

function PlanetRotationController.start()
	if heartbeatConnection ~= nil then
		return
	end

	refreshPlanetStates()

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		refreshPlanetStates()
		local currentTime = PlanetMath.getMotionTime()

		for planetModel, state in planetStates do
			if planetModel.Parent == nil then
				continue
			end

			planetModel:PivotTo(
				CFrame.new(PlanetMath.getPlanetCenter(state.planet, currentTime))
					* CFrame.fromAxisAngle(
						PlanetMath.getRotationAxis(state.planet),
						math.fmod(state.planet.angularSpeed * currentTime, math.pi * 2)
					)
			)
		end
	end)
end

return PlanetRotationController
