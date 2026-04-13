--!strict

local LocomotionState = {
	attributeName = "PlanetLocomotionState",
	Idle = "Idle",
	Walk = "Walk",
	Jump = "Jump",
	Fall = "Fall",
}

return table.freeze(LocomotionState)
