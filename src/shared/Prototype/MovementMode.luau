--!strict

local MovementMode = {
	attributeName = "PlanetMovementMode",
	Planet = "planet",
	Fly = "fly",
	Cruise = "cruise",
}

return table.freeze(MovementMode)
