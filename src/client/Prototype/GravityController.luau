--!strict

local PlayerController = require(script.Parent:WaitForChild("PlayerController")) :: any

local GravityController = {}

function GravityController.start()
	PlayerController.start()
end

return GravityController
