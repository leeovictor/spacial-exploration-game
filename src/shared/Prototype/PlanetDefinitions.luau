--!strict

export type PlanetDef = {
	name: string,
	center: Vector3,
	radius: number,
	surfaceGravity: number, -- studs/s², applied as acceleration magnitude
	influenceRadius: number, -- distance from center within which gravity applies
}

local PlanetDefinitions = {}

local planets: { PlanetDef } = {
	{
		name = "PlanetA",
		center = Vector3.new(0, -220, 0),
		radius = 200,
		surfaceGravity = 196.2, -- matches default Roblox Workspace.Gravity for familiar feel
		influenceRadius = 900,
	},
}

PlanetDefinitions.planets = planets

return PlanetDefinitions
