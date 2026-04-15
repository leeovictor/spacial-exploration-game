--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocomotionConstants = require(ReplicatedStorage.Shared.Prototype.LocomotionConstants)
local MovementMode = require(ReplicatedStorage.Shared.Prototype.MovementMode)
local CharacterAnimationController = require(script.Parent.CharacterAnimationController)
local CruiseController = require(script.Parent.CruiseController)
local FlyController = require(script.Parent.FlyController)
local PlanetLocomotionController = require(script.Parent.PlanetLocomotionController)

local PlayerController = {}

type MovementModeName = "planet" | "fly" | "cruise"

function PlayerController.start()
	local player = Players.LocalPlayer
	local activeCharacter: Model? = nil
	local activeAnimationCleanup: (() -> ())? = nil
	local activeMovementCleanup: (() -> ())? = nil
	local activeMovementMode: MovementModeName = MovementMode.Planet
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

	local function applyMovementMode(mode: MovementModeName)
		activeMovementMode = mode
		cleanupMovementController()

		if activeCharacter == nil then
			return
		end

		activeCharacter:SetAttribute(MovementMode.attributeName, mode)

		if mode == MovementMode.Fly then
			activeMovementCleanup = FlyController.attach(activeCharacter, {
				onCruiseRequested = function()
					if activeMovementMode ~= MovementMode.Fly then
						return
					end

					applyMovementMode(MovementMode.Cruise)
				end,
			})
		elseif mode == MovementMode.Cruise then
			activeMovementCleanup = CruiseController.attach(activeCharacter, {
				onLandingDetected = function()
					if activeMovementMode ~= MovementMode.Cruise then
						return
					end

					applyMovementMode(MovementMode.Planet)
				end,
			})
		else
			activeMovementCleanup = PlanetLocomotionController.attach(activeCharacter)
		end
	end

	local function onCharacterAdded(character: Model)
		cleanupAllControllers()
		activeCharacter = character
		activeMovementMode = MovementMode.Planet
		lastSpaceTapAt = 0

		activeAnimationCleanup = CharacterAnimationController.attach(character)
		applyMovementMode(activeMovementMode)
	end

	local function onCharacterRemoving()
		cleanupAllControllers()
		if activeCharacter ~= nil then
			activeCharacter:SetAttribute(MovementMode.attributeName, nil)
		end
		activeCharacter = nil
		activeMovementMode = MovementMode.Planet
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
		if activeMovementMode == MovementMode.Cruise then
			return
		end

		if now - lastSpaceTapAt <= LocomotionConstants.flyToggleDoubleTapWindow then
			local nextMode: MovementModeName = if activeMovementMode == MovementMode.Planet
				then MovementMode.Fly
				else MovementMode.Planet
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
