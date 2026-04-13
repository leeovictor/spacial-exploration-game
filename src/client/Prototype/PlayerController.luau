--!strict

local Players = game:GetService("Players")
local PlanetLocomotionController = require(script.Parent.PlanetLocomotionController)

local PlayerController = {}

function PlayerController.start()
	local player = Players.LocalPlayer
	local activeCleanup: (() -> ())? = nil

	local function onCharacterAdded(character: Model)
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end

		activeCleanup = PlanetLocomotionController.attach(character)
	end

	local function onCharacterRemoving()
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end
	end

	if player.Character ~= nil then
		onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
end

return PlayerController
