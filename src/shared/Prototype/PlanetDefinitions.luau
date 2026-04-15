--!strict

export type PlanetDef = {
	name: string,
	center: Vector3,
	radius: number,
	surfaceGravity: number, -- studs/s², applied as acceleration magnitude
	influenceRadius: number, -- distance from center within which gravity applies
	rotationAxis: Vector3,
	angularSpeed: number, -- radians/s around rotationAxis in world space
	orbitCenter: Vector3?,
	orbitAxis: Vector3?,
	orbitAngularSpeed: number?, -- radians/s around orbitCenter in world space
}

local PlanetDefinitions = {}

local sharedStarCenter = Vector3.new(-300 * 20, -300, 0)

function PlanetDefinitions.secondsPerRotationToAngularSpeed(secondsPerRotation: number): number
	assert(secondsPerRotation > 0, "secondsPerRotation must be greater than zero")

	return (2 * math.pi) / secondsPerRotation
end

function PlanetDefinitions.axisAngleToRotationAxis(tiltAngle: number, azimuthAngle: number?): Vector3
	local resolvedAzimuthAngle = if azimuthAngle ~= nil then azimuthAngle else 0
	local horizontalMagnitude = math.sin(tiltAngle)

	return Vector3.new(
		math.cos(resolvedAzimuthAngle) * horizontalMagnitude,
		math.cos(tiltAngle),
		math.sin(resolvedAzimuthAngle) * horizontalMagnitude
	)
end

local planets: { PlanetDef } = {
	{
		name = "PlanetA",
		center = sharedStarCenter + Vector3.new(12000, 0, 0),
		radius = 300,
		surfaceGravity = 196.2, -- matches default Roblox Workspace.Gravity for familiar feel
		influenceRadius = 300 * 10,
		rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(8), math.rad(10)),
		angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(300), -- 300s per rotation, fairly slow but noticeable
		orbitCenter = sharedStarCenter,
		orbitAxis = Vector3.yAxis,
		orbitAngularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 40), -- 40 minutes per orbit, just to make it noticeable
	},
	{
		name = "PlanetB",
		center = sharedStarCenter + Vector3.new(0, 0, 7600),
		radius = 180,
		surfaceGravity = 117.72,
		influenceRadius = 180 * 10,
		rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(4), math.rad(-25)),
		angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(210),
		orbitCenter = sharedStarCenter,
		orbitAxis = Vector3.yAxis,
		orbitAngularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 28), -- closer orbit, faster period
	},
	{
		name = "PlanetC",
		center = sharedStarCenter + Vector3.new(-18500, 0, 0),
		radius = 140,
		surfaceGravity = 91.56,
		influenceRadius = 140 * 10,
		rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(14), math.rad(40)),
		angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(260),
		orbitCenter = sharedStarCenter,
		orbitAxis = Vector3.yAxis,
		orbitAngularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 58), -- farther orbit, slower period
	},
}

PlanetDefinitions.planets = planets

return PlanetDefinitions
