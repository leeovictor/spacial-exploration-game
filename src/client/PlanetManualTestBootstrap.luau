--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PlanetEditableMeshBuilder = require(ReplicatedStorage.Shared.PlanetEditableMeshBuilder)

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)

local PlanetManualTestBootstrap = {}

local function createPlanetFromDefinition(planetDefinition)
	local existingPlanet = Workspace:FindFirstChild(planetDefinition.name)
	if existingPlanet ~= nil then
		existingPlanet:Destroy()
	end

	local result = PlanetEditableMeshBuilder.createPlanet({
		name = planetDefinition.name,
		parent = Workspace,
		center = planetDefinition.center,
		radius = planetDefinition.radius,
		patchResolution = 32,
		faceSubdivisions = 1,
		anchored = true,
		canCollide = true,
		canQuery = true,
		canTouch = false,
		material = Enum.Material.Snow,
		color = Color3.fromRGB(193, 233, 240),
		doubleSided = false,
		fallbackMaterial = Enum.Material.Slate,
		fallbackColor = Color3.fromRGB(85, 100, 72),
		collisionFidelity = Enum.CollisionFidelity.Hull,
		renderFidelity = Enum.RenderFidelity.Automatic,
		rotationAxis = planetDefinition.rotationAxis,
		angularSpeed = planetDefinition.angularSpeed,
		debugShowRotationAxis = true,
		debugShowEquator = true,
	})

	print(
		string.format(
			"[PlanetManualTest] built '%s' editable=%s patches=%d errors=%d",
			result.model.Name,
			tostring(result.usedEditableMeshes),
			#result.patches,
			#result.errors
		)
	)

	for _, errorMessage in result.errors do
		warn("[PlanetManualTest] " .. errorMessage)
	end

	return result
end

function PlanetManualTestBootstrap.run()
	local results = table.create(#PlanetDefinitions.planets)

	for _, planetDefinition in PlanetDefinitions.planets do
		table.insert(results, createPlanetFromDefinition(planetDefinition))
	end

	return results
end

return PlanetManualTestBootstrap
