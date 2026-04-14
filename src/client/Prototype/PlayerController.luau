--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local FlyController = require(script.Parent.FlyController)
local PlanetLocomotionController = require(script.Parent.PlanetLocomotionController)

local PlayerController = {}

type MovementMode = "planet" | "fly"

function PlayerController.start()
	local player = Players.LocalPlayer
	local activeCharacter: Model? = nil
	local activeAnimationCleanup: (() -> ())? = nil
	local activeMovementCleanup: (() -> ())? = nil
	local activeMovementMode: MovementMode = "planet"
	local lastSpaceTapAt = 0

	local function cleanupMovementController()
		if activeMovementCleanup ~= nil then
			activeMovementCleanup()
			activeMovementCleanup = nil
		end
	end

	local function cleanupAllControllers()
		cleanupMovementController()

		if activeAnimationCleanup ~= nil then
			activeAnimationCleanup()
			activeAnimationCleanup = nil
		end
	end

	local function applyMovementMode(mode: MovementMode)
		activeMovementMode = mode
		cleanupMovementController()

		if activeCharacter == nil then
			return
		end

		if mode == "fly" then
			activeMovementCleanup = FlyController.attach(activeCharacter)
		else
			activeMovementCleanup = PlanetLocomotionController.attach(activeCharacter)
		end
	end

	local function onCharacterAdded(character: Model)
		cleanupAllControllers()
		activeCharacter = character
		activeMovementMode = "planet"
		lastSpaceTapAt = 0

		activeAnimationCleanup = CharacterAnimationController.attach(character)
		applyMovementMode(activeMovementMode)
	end

	local function onCharacterRemoving()
		cleanupAllControllers()
		activeCharacter = nil
		activeMovementMode = "planet"
		lastSpaceTapAt = 0
	end

	if player.Character ~= nil then
		onCharacterAdded(player.Character)
	end

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessedEvent: boolean)
		if gameProcessedEvent then
			return
		end

		if input.UserInputType ~= Enum.UserInputType.Keyboard or input.KeyCode ~= Enum.KeyCode.Space then
			return
		end

		if activeCharacter == nil then
			return
		end

		local humanoid = activeCharacter:FindFirstChildOfClass("Humanoid")
		if humanoid == nil or humanoid.Health <= 0 then
			return
		end

		local now = os.clock()
		if now - lastSpaceTapAt <= LocomotionConstants.flyToggleDoubleTapWindow then
			local nextMode: MovementMode = if activeMovementMode == "planet" then "fly" else "planet"
			applyMovementMode(nextMode)
			lastSpaceTapAt = 0
			return
		end

		lastSpaceTapAt = now
	end)

	player.CharacterAdded:Connect(onCharacterAdded)
	player.CharacterRemoving:Connect(onCharacterRemoving)
end

return PlayerController
