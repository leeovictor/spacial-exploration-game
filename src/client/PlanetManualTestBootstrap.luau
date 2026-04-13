--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PlanetEditableMeshBuilder = require(ReplicatedStorage.Shared.PlanetEditableMeshBuilder)

local TEST_PLANET_NAME = "ClientManualTestPlanet"

local PlanetManualTestBootstrap = {}

function PlanetManualTestBootstrap.run()
	local existingPlanet = Workspace:FindFirstChild(TEST_PLANET_NAME)
	if existingPlanet ~= nil then
		existingPlanet:Destroy()
	end

	local result = PlanetEditableMeshBuilder.createPlanet({
		name = TEST_PLANET_NAME,
		parent = Workspace,
		center = Vector3.new(0, -320, 0),
		radius = 300,
		terrain = {
			amplitude = 18,
			frequency = 2.25,
			octaves = 4,
			persistence = 0.5,
			lacunarity = 2,
			seed = 17,
		},
		patchResolution = 64,
		faceSubdivisions = 1,
		anchored = true,
		canCollide = true,
		canQuery = true,
		canTouch = false,
		material = Enum.Material.SmoothPlastic,
		color = Color3.fromRGB(112, 136, 95),
		doubleSided = true,
		fallbackMaterial = Enum.Material.Slate,
		fallbackColor = Color3.fromRGB(85, 100, 72),
		collisionFidelity = Enum.CollisionFidelity.Hull,
		renderFidelity = Enum.RenderFidelity.Automatic,
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

return PlanetManualTestBootstrap
