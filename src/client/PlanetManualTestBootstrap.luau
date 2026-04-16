--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local PlanetEditableMeshBuilder = require(ReplicatedStorage.Shared.PlanetEditableMeshBuilder)

local OrePatchGenerator = require(ReplicatedStorage.Shared.Prototype.OrePatchGenerator)
local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)
local OrePatchRenderer = require(script.Parent.Prototype.OrePatchRenderer)

local PlanetManualTestBootstrap = {}

local INITIAL_MOTION_TIME = 0
local FIRST_PLANET_PATCH_COUNT = 30
local PATCH_GROUP_NAME = "DebugOrePatches"

local function createTestPatchSurfacePoint(
	planetDefinition: PlanetDefinitions.PlanetDef,
	timeSeconds: number,
	randomGenerator: Random
): Vector3
	local planetCenter = PlanetMath.getPlanetCenter(planetDefinition, timeSeconds)
	local y = randomGenerator:NextNumber(-1, 1)
	local radial = math.sqrt(math.max(0, 1 - y * y))
	local angle = randomGenerator:NextNumber(0, math.pi * 2)
	local surfaceDirection = Vector3.new(math.cos(angle) * radial, y, math.sin(angle) * radial)
	return planetCenter + surfaceDirection * planetDefinition.radius
end

local function createStarFromDefinition(starDefinition: PlanetDefinitions.StarDef): Part
	local existingStar = Workspace:FindFirstChild(starDefinition.name)
	if existingStar ~= nil then
		existingStar:Destroy()
	end

	local starPart = Instance.new("Part")
	starPart.Name = starDefinition.name
	starPart.Shape = Enum.PartType.Ball
	starPart.Anchored = true
	starPart.CanCollide = false
	starPart.CanQuery = false
	starPart.CanTouch = false
	starPart.CastShadow = false
	starPart.Locked = true
	starPart.Material = Enum.Material.Neon
	starPart.Color = starDefinition.color
	starPart.Size = Vector3.one * (starDefinition.radius * 2)
	starPart.CFrame = CFrame.new(starDefinition.position)
	starPart.Parent = Workspace

	return starPart
end

local function createPlanetFromDefinition(planetDefinition: PlanetDefinitions.PlanetDef)
	local existingPlanet = Workspace:FindFirstChild(planetDefinition.name)
	if existingPlanet ~= nil then
		existingPlanet:Destroy()
	end

	local result = PlanetEditableMeshBuilder.createPlanet({
		name = planetDefinition.name,
		parent = Workspace,
		center = PlanetMath.getPlanetCenter(planetDefinition, INITIAL_MOTION_TIME),
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
		rotationAxis = planetDefinition.rotationDef.rotationAxis,
		angularSpeed = planetDefinition.rotationDef.angularSpeed,
		debugShowRotationAxis = true,
		debugShowEquator = false,
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
	local system = PlanetDefinitions.system
	createStarFromDefinition(system.star)

	local results = table.create(#system.planets)

	for _, planetDefinition in system.planets do
		table.insert(results, createPlanetFromDefinition(planetDefinition))
	end

	local firstPlanetDefinition = system.planets[1]
	local firstPlanetResult = results[1]
	if firstPlanetDefinition ~= nil and firstPlanetResult ~= nil then
		local existingPatchGroup = firstPlanetResult.model:FindFirstChild(PATCH_GROUP_NAME)
		if existingPatchGroup ~= nil then
			existingPatchGroup:Destroy()
		end

		local patchGroup = Instance.new("Model")
		patchGroup.Name = PATCH_GROUP_NAME
		patchGroup.Parent = firstPlanetResult.model

		local randomGenerator = Random.new()
		for patchIndex = 1, FIRST_PLANET_PATCH_COUNT do
			local patchCenter = createTestPatchSurfacePoint(firstPlanetDefinition, INITIAL_MOTION_TIME, randomGenerator)
			local orePatch = OrePatchGenerator.generate({
				planet = firstPlanetDefinition,
				centerPosition = patchCenter,
				timeSeconds = INITIAL_MOTION_TIME,
				nodeCount = randomGenerator:NextInteger(4, 21),
				minSpacing = math.max(firstPlanetDefinition.radius * 0.008, 1.5),
				seed = randomGenerator:NextInteger(1, 1_000_000),
			})

			local patchParent = Instance.new("Model")
			patchParent.Name = string.format("Patch%02d", patchIndex)
			patchParent.Parent = patchGroup

			OrePatchRenderer.render(patchParent, orePatch)
		end
	end

	return results
end

return PlanetManualTestBootstrap
