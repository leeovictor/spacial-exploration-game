--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)

type RotationDef = PlanetDefinitions.RotationDef
type TranslationDef = PlanetDefinitions.TranslationDef
type StarDef = PlanetDefinitions.StarDef
type PlanetDef = PlanetDefinitions.PlanetDef
type StarSystemDef = PlanetDefinitions.StarSystemDef

local EPSILON = 0.01
local MIN_ROTATION_AXIS_MAGNITUDE = 0.0001
local HOURS_PER_DAY = 24
local HALF_DAY_HOURS = HOURS_PER_DAY * 0.5
local ROBLOX_SOLAR_TILT_DEGREES = 23.5

local PlanetMath = {}

local function getSystem(): StarSystemDef
	return PlanetDefinitions.system
end

local function getSignedAngularSpeed(speed: number, direction: string): number
	if direction == "clockwise" then
		return -speed
	end

	return speed
end

local function getOrbitPlaneBasis(orbitAxis: Vector3): (Vector3, Vector3)
	local tangent = orbitAxis:Cross(Vector3.yAxis)
	if tangent.Magnitude <= EPSILON then
		tangent = orbitAxis:Cross(Vector3.xAxis)
	end

	tangent = tangent.Unit
	local bitangent = orbitAxis:Cross(tangent)
	if bitangent.Magnitude <= EPSILON then
		bitangent = orbitAxis:Cross(Vector3.zAxis)
	end

	return tangent, bitangent.Unit
end

function PlanetMath.getMotionTime(): number
	return Workspace:GetServerTimeNow()
end

function PlanetMath.getSystem(): StarSystemDef
	return getSystem()
end

function PlanetMath.getStar(): StarDef
	return getSystem().star
end

function PlanetMath.getStarPosition(): Vector3
	return PlanetMath.getStar().position
end

function PlanetMath.getPlanets(): { PlanetDef }
	return getSystem().planets
end

function PlanetMath.projectOntoPlane(vector: Vector3, planeNormal: Vector3): Vector3
	return vector - vector:Dot(planeNormal) * planeNormal
end

function PlanetMath.getActivePlanet(position: Vector3, timeSeconds: number?): (PlanetDef?, number)
	local activePlanet: PlanetDef? = nil
	local closestDistance = math.huge
	local resolvedTime = if timeSeconds ~= nil then timeSeconds else PlanetMath.getMotionTime()

	for _, planet in PlanetMath.getPlanets() do
		local distance = (position - PlanetMath.getPlanetCenter(planet, resolvedTime)).Magnitude
		if distance < planet.influenceRadius and distance < closestDistance then
			closestDistance = distance
			activePlanet = planet
		end
	end

	return activePlanet, closestDistance
end

function PlanetMath.getSurfaceUp(position: Vector3, timeSeconds: number?): Vector3
	local activePlanet = PlanetMath.getActivePlanet(position, timeSeconds)
	if activePlanet == nil then
		return Vector3.yAxis
	end

	local resolvedTime = if timeSeconds ~= nil then timeSeconds else PlanetMath.getMotionTime()
	local fromCenter = position - PlanetMath.getPlanetCenter(activePlanet, resolvedTime)
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
	if planet.rotationDef.rotationAxis.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		return Vector3.yAxis
	end

	return planet.rotationDef.rotationAxis.Unit
end

function PlanetMath.getAngularVelocity(planet: PlanetDef): Vector3
	return PlanetMath.getRotationAxis(planet)
		* getSignedAngularSpeed(planet.rotationDef.angularSpeed, planet.rotationDef.direction)
end

function PlanetMath.getRotationAngularSpeed(planet: PlanetDef): number
	return getSignedAngularSpeed(planet.rotationDef.angularSpeed, planet.rotationDef.direction)
end

function PlanetMath.getOrbitAxis(planet: PlanetDef): Vector3
	local orbitAxis = planet.translationDef.orbitAxis
	if orbitAxis == nil or orbitAxis.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		return Vector3.yAxis
	end

	return orbitAxis.Unit
end

function PlanetMath.getOrbitCenter(_planet: PlanetDef): Vector3
	return PlanetMath.getStarPosition()
end

function PlanetMath.getOrbitAngularSpeed(planet: PlanetDef): number
	return getSignedAngularSpeed(planet.translationDef.orbitalSpeed, planet.translationDef.direction)
end

function PlanetMath.getPlanetCenter(planet: PlanetDef, timeSeconds: number?): Vector3
	local orbitAngularSpeed = PlanetMath.getOrbitAngularSpeed(planet)
	local orbitCenter = PlanetMath.getOrbitCenter(planet)
	local orbitRadius = planet.distanceFromStar

	if orbitRadius <= EPSILON then
		return orbitCenter
	end

	local orbitAxis = PlanetMath.getOrbitAxis(planet)
	local tangent, bitangent = getOrbitPlaneBasis(orbitAxis)
	local resolvedTime = if timeSeconds ~= nil then timeSeconds else PlanetMath.getMotionTime()
	local orbitAngle = math.fmod(planet.startOrbitAngle + orbitAngularSpeed * resolvedTime, math.pi * 2)
	local orbitOffset = tangent * (math.cos(orbitAngle) * orbitRadius)
		+ bitangent * (math.sin(orbitAngle) * orbitRadius)
	return orbitCenter + orbitOffset
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

function PlanetMath.getSurfaceVelocity(planet: PlanetDef, position: Vector3, timeSeconds: number?): Vector3
	return PlanetMath.getPlanetCenterVelocity(planet, timeSeconds)
		+ PlanetMath.getRotationalSurfaceVelocity(planet, position, timeSeconds)
end

function PlanetMath.getPlanetRotationDelta(planet: PlanetDef, deltaTime: number): CFrame
	local signedAngularSpeed = PlanetMath.getRotationAngularSpeed(planet)
	if math.abs(signedAngularSpeed) <= EPSILON or deltaTime == 0 then
		return CFrame.identity
	end

	return CFrame.fromAxisAngle(PlanetMath.getRotationAxis(planet), signedAngularSpeed * deltaTime)
end

function PlanetMath.rotateVectorWithPlanet(planet: PlanetDef, vector: Vector3, deltaTime: number): Vector3
	if vector.Magnitude <= EPSILON then
		return vector
	end

	return PlanetMath.getPlanetRotationDelta(planet, deltaTime):VectorToWorldSpace(vector)
end

function PlanetMath.getLightingClockTimeAndGeographicLatitude(
	planetCenter: Vector3,
	starPosition: Vector3
): (number, number)
	local sunOffset = starPosition - planetCenter
	if sunOffset.Magnitude <= EPSILON then
		return HALF_DAY_HOURS, ROBLOX_SOLAR_TILT_DEGREES
	end

	local sunDirection = sunOffset.Unit
	local horizontalMagnitude = math.sqrt(sunDirection.X * sunDirection.X + sunDirection.Y * sunDirection.Y)
	local geographicLatitude = math.deg(math.atan2(sunDirection.Z, horizontalMagnitude)) + ROBLOX_SOLAR_TILT_DEGREES
	local hourAngle = math.atan2(-sunDirection.X, sunDirection.Y)
	local clockTime = math.fmod(HALF_DAY_HOURS + hourAngle * HALF_DAY_HOURS / math.pi, HOURS_PER_DAY)

	if clockTime < 0 then
		clockTime += HOURS_PER_DAY
	end

	return clockTime, geographicLatitude
end

return PlanetMath
