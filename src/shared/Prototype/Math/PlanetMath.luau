--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)

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

local EPSILON = 0.01
local MIN_ROTATION_AXIS_MAGNITUDE = 0.0001

local PlanetMath = {}

function PlanetMath.getMotionTime(): number
	return Workspace:GetServerTimeNow()
end

function PlanetMath.projectOntoPlane(vector: Vector3, planeNormal: Vector3): Vector3
	return vector - vector:Dot(planeNormal) * planeNormal
end

function PlanetMath.getActivePlanet(position: Vector3): (PlanetDef?, number)
	local activePlanet: PlanetDef? = nil
	local closestDistance = math.huge

	for _, planet in PlanetDefinitions.planets do
		local distance = (position - PlanetMath.getPlanetCenter(planet)).Magnitude
		if distance < planet.influenceRadius and distance < closestDistance then
			closestDistance = distance
			activePlanet = planet
		end
	end

	return activePlanet, closestDistance
end

function PlanetMath.getSurfaceUp(position: Vector3): Vector3
	local activePlanet = PlanetMath.getActivePlanet(position)
	if activePlanet == nil then
		return Vector3.yAxis
	end

	local fromCenter = position - PlanetMath.getPlanetCenter(activePlanet)
	if fromCenter.Magnitude <= 0.001 then
		return Vector3.yAxis
	end

	return fromCenter.Unit
end

function PlanetMath.getPlanarDirection(surfaceUp: Vector3, primaryVector: Vector3, fallbackVector: Vector3?): Vector3
	local primaryDirection = PlanetMath.projectOntoPlane(primaryVector, surfaceUp)
	if primaryDirection.Magnitude > EPSILON then
		return primaryDirection.Unit
	end

	if fallbackVector ~= nil then
		local fallbackDirection = PlanetMath.projectOntoPlane(fallbackVector, surfaceUp)
		if fallbackDirection.Magnitude > EPSILON then
			return fallbackDirection.Unit
		end
	end

	local axisFallback = surfaceUp:Cross(Vector3.xAxis)
	if axisFallback.Magnitude <= EPSILON then
		axisFallback = surfaceUp:Cross(Vector3.zAxis)
	end

	return axisFallback.Unit
end

function PlanetMath.getRotationAxis(planet: PlanetDef): Vector3
	if planet.rotationAxis.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		return Vector3.yAxis
	end

	return planet.rotationAxis.Unit
end

function PlanetMath.getAngularVelocity(planet: PlanetDef): Vector3
	return PlanetMath.getRotationAxis(planet) * planet.angularSpeed
end

function PlanetMath.getOrbitAxis(planet: PlanetDef): Vector3
	if planet.orbitAxis == nil or planet.orbitAxis.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		return Vector3.yAxis
	end

	return planet.orbitAxis.Unit
end

function PlanetMath.getOrbitCenter(planet: PlanetDef): Vector3
	if planet.orbitCenter == nil then
		return planet.center
	end

	return planet.orbitCenter
end

function PlanetMath.getOrbitAngularSpeed(planet: PlanetDef): number
	if planet.orbitAngularSpeed == nil then
		return 0
	end

	return planet.orbitAngularSpeed
end

function PlanetMath.getPlanetCenter(planet: PlanetDef, timeSeconds: number?): Vector3
	local orbitAngularSpeed = PlanetMath.getOrbitAngularSpeed(planet)
	local orbitCenter = PlanetMath.getOrbitCenter(planet)
	local baseOffset = planet.center - orbitCenter

	if orbitAngularSpeed == 0 or baseOffset.Magnitude <= EPSILON then
		return planet.center
	end

	local resolvedTime = if timeSeconds ~= nil then timeSeconds else PlanetMath.getMotionTime()
	local orbitAngle = math.fmod(orbitAngularSpeed * resolvedTime, math.pi * 2)
	return orbitCenter
		+ CFrame.fromAxisAngle(PlanetMath.getOrbitAxis(planet), orbitAngle):VectorToWorldSpace(baseOffset)
end

function PlanetMath.getPlanetCenterVelocity(planet: PlanetDef, timeSeconds: number?): Vector3
	local orbitAngularSpeed = PlanetMath.getOrbitAngularSpeed(planet)
	if orbitAngularSpeed == 0 then
		return Vector3.zero
	end

	local orbitCenter = PlanetMath.getOrbitCenter(planet)
	local currentCenter = PlanetMath.getPlanetCenter(planet, timeSeconds)
	return (PlanetMath.getOrbitAxis(planet) * orbitAngularSpeed):Cross(currentCenter - orbitCenter)
end

function PlanetMath.getRotationalSurfaceVelocity(planet: PlanetDef, position: Vector3, timeSeconds: number?): Vector3
	local currentCenter = PlanetMath.getPlanetCenter(planet, timeSeconds)
	return PlanetMath.getAngularVelocity(planet):Cross(position - currentCenter)
end

function PlanetMath.getSurfaceVelocity(planet: PlanetDef, position: Vector3): Vector3
	return PlanetMath.getPlanetCenterVelocity(planet) + PlanetMath.getRotationalSurfaceVelocity(planet, position)
end

function PlanetMath.getPlanetRotationDelta(planet: PlanetDef, deltaTime: number): CFrame
	if math.abs(planet.angularSpeed) <= EPSILON or deltaTime == 0 then
		return CFrame.identity
	end

	return CFrame.fromAxisAngle(PlanetMath.getRotationAxis(planet), planet.angularSpeed * deltaTime)
end

function PlanetMath.rotateVectorWithPlanet(planet: PlanetDef, vector: Vector3, deltaTime: number): Vector3
	if vector.Magnitude <= EPSILON then
		return vector
	end

	return PlanetMath.getPlanetRotationDelta(planet, deltaTime):VectorToWorldSpace(vector)
end

return PlanetMath
