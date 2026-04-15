--!strict

-- Disable Roblox default gravity. All gravity is handled per-planet on the client
-- via GravityController using VectorForce constraints.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)

Workspace.Gravity = 0

local SPAWN_SURFACE_OFFSET = 3

local function getSpawnPlanet()
	return PlanetDefinitions.system.planets[1]
end

local function getCharacterSpawnCFrame(character: Model, rootPart: BasePart, motionTime: number): CFrame?
	local spawnPlanet = getSpawnPlanet()
	if spawnPlanet == nil then
		return nil
	end

	local planetCenter = PlanetMath.getPlanetCenter(spawnPlanet, motionTime)
	local surfaceUp = PlanetMath.getRotationAxis(spawnPlanet)
	if surfaceUp.Magnitude <= 0.001 then
		surfaceUp = Vector3.yAxis
	else
		surfaceUp = surfaceUp.Unit
	end

	local supportDistance = math.max(character:GetExtentsSize().Magnitude * 0.5, rootPart.Size.Y * 0.5)
	local spawnPosition = planetCenter + surfaceUp * (spawnPlanet.radius + supportDistance + SPAWN_SURFACE_OFFSET)
	local forward = PlanetMath.getPlanarDirection(surfaceUp, Vector3.zAxis, Vector3.xAxis)

	return CFrame.lookAt(spawnPosition, spawnPosition + forward, surfaceUp)
end

local function placeCharacterOnPlanetSurface(character: Model)
	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return
	end

	local spawnPlanet = getSpawnPlanet()
	if spawnPlanet == nil then
		return
	end

	local motionTime = PlanetMath.getMotionTime()
	local spawnCFrame = getCharacterSpawnCFrame(character, rootPart, motionTime)
	if spawnCFrame == nil then
		return
	end

	character:PivotTo(spawnCFrame)
	rootPart.AssemblyLinearVelocity = PlanetMath.getSurfaceVelocity(spawnPlanet, rootPart.Position, motionTime)
	rootPart.AssemblyAngularVelocity = Vector3.zero
end

local function configureCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end

	task.defer(function()
		if character.Parent == nil then
			return
		end

		placeCharacterOnPlanetSurface(character)
	end)
end

local function configurePlayer(player: Player)
	if player.Character ~= nil then
		configureCharacter(player.Character)
	end

	player.CharacterAdded:Connect(configureCharacter)
end

for _, player in Players:GetPlayers() do
	configurePlayer(player)
end

Players.PlayerAdded:Connect(configurePlayer)
