--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlanetDefinitions =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Prototype"):WaitForChild("PlanetDefinitions")) :: any

type PlanetDef = {
	name: string,
	center: Vector3,
	radius: number,
	surfaceGravity: number,
	influenceRadius: number,
}

local EPSILON = 0.01

local PlanetMath = {}

function PlanetMath.projectOntoPlane(vector: Vector3, planeNormal: Vector3): Vector3
	return vector - vector:Dot(planeNormal) * planeNormal
end

function PlanetMath.getActivePlanet(position: Vector3): (PlanetDef?, number)
	local activePlanet: PlanetDef? = nil
	local closestDistance = math.huge

	for _, planet in PlanetDefinitions.planets do
		local distance = (position - planet.center).Magnitude
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

	local fromCenter = position - activePlanet.center
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

return PlanetMath
