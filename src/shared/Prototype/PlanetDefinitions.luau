--!strict

export type RotationDirection = "clockwise" | "counterclockwise"

export type RotationDef = {
	rotationAxis: Vector3,
	angularSpeed: number, -- radians/s around rotationAxis in world space
	direction: RotationDirection,
}

export type TranslationDef = {
	orbitalSpeed: number, -- radians/s around the system star position
	orbitAxis: Vector3?,
	direction: RotationDirection,
}

export type StarDef = {
	name: string,
	position: Vector3,
	radius: number,
	color: Color3,
}

export type PlanetDef = {
	name: string,
	gravity: number, -- studs/s², applied as acceleration magnitude
	influenceRadius: number, -- distance from center within which gravity applies
	distanceFromStar: number,
	radius: number,
	rotationDef: RotationDef,
	translationDef: TranslationDef,
	startOrbitAngle: number,
}

export type StarSystemDef = {
	star: StarDef,
	planets: { PlanetDef },
}

local PlanetDefinitions = {}

local sharedStarPosition = Vector3.new(-300 * 20, -300, 0)

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
		gravity = 196.2, -- matches default Roblox Workspace.Gravity for familiar feel
		influenceRadius = 400 * 10,
		distanceFromStar = 10000,
		radius = 400,
		rotationDef = {
			rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(8), math.rad(10)),
			angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(300), -- 300s per rotation, fairly slow but noticeable
			direction = "counterclockwise",
		},
		translationDef = {
			orbitalSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 20), -- 40 minutes per orbit, just to make it noticeable
			orbitAxis = Vector3.yAxis,
			direction = "counterclockwise",
		},
		startOrbitAngle = 0,
	},
	{
		name = "PlanetB",
		gravity = 117.72,
		influenceRadius = 600 * 10,
		distanceFromStar = 20000,
		radius = 600,
		rotationDef = {
			rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(4), math.rad(-25)),
			angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(210),
			direction = "counterclockwise",
		},
		translationDef = {
			orbitalSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 10), -- closer orbit, faster period
			orbitAxis = Vector3.yAxis,
			direction = "counterclockwise",
		},
		startOrbitAngle = math.pi * 0.5,
	},
	{
		name = "PlanetC",
		gravity = 91.56,
		influenceRadius = 200 * 10,
		distanceFromStar = 30500,
		radius = 200,
		rotationDef = {
			rotationAxis = PlanetDefinitions.axisAngleToRotationAxis(math.rad(14), math.rad(40)),
			angularSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(260),
			direction = "clockwise",
		},
		translationDef = {
			orbitalSpeed = PlanetDefinitions.secondsPerRotationToAngularSpeed(60 * 58), -- farther orbit, slower period
			orbitAxis = Vector3.yAxis,
			direction = "counterclockwise",
		},
		startOrbitAngle = math.pi,
	},
}

local system: StarSystemDef = {
	star = {
		name = "PrototypeStar",
		position = sharedStarPosition,
		radius = 1800,
		color = Color3.fromRGB(255, 196, 96),
	},
	planets = planets,
}

PlanetDefinitions.system = system

return PlanetDefinitions
