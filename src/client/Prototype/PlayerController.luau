--!strict

local Players = game:GetService("Players")
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local PlanetLocomotionController = require(script.Parent.PlanetLocomotionController)

local PlayerController = {}

function PlayerController.start()
	local player = Players.LocalPlayer
	local activeCleanup: (() -> ())? = nil

	local function runCleanup(callbacks: { (() -> ())? }): () -> ()
		local cleaned = false

		return function()
			if cleaned then
				return
			end
			cleaned = true

			for _, callback in callbacks do
				if callback ~= nil then
					callback()
				end
			end
		end
	end

	local function onCharacterAdded(character: Model)
		if activeCleanup ~= nil then
			activeCleanup()
			activeCleanup = nil
		end

		activeCleanup = runCleanup({
			PlanetLocomotionController.attach(character),
			CharacterAnimationController.attach(character),
		})
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
