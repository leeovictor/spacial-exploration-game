--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlanetDefinitions = require(ReplicatedStorage.Shared.Prototype.PlanetDefinitions)
local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)

export type PlanetDef = PlanetDefinitions.PlanetDef

export type OreNode = {
	index: number,
	position: Vector3,
	normal: Vector3,
	radialDistanceFromPatchCenter: number,
}

export type OrePatch = {
	planetName: string,
	planetCenter: Vector3,
	centerPosition: Vector3,
	surfaceUp: Vector3,
	tangent: Vector3,
	bitangent: Vector3,
	patchRadius: number,
	nodeCount: number,
	nodes: { OreNode },
}

export type GenerateOrePatchOptions = {
	planet: PlanetDef,
	centerPosition: Vector3,
	timeSeconds: number?,
	nodeCount: number?,
	minSpacing: number?,
	seed: number?,
}

local MIN_NODE_COUNT = 4
local MAX_NODE_COUNT = 21
local DEFAULT_CANDIDATE_TRIES = 18
local DEFAULT_ATTEMPT_MULTIPLIER = 32
local DEFAULT_SEED = 13579

local OrePatchGenerator = {}

local function clampNodeCount(nodeCount: number?): number
	if nodeCount == nil then
		return MIN_NODE_COUNT
	end

	return math.clamp(math.floor(nodeCount + 0.5), MIN_NODE_COUNT, MAX_NODE_COUNT)
end

local function resolveMinSpacing(minSpacing: number?, planetRadius: number, nodeCount: number): number
	if minSpacing ~= nil then
		return math.max(0.5, minSpacing)
	end

	local estimatedSpacing = (planetRadius * 0.035) / math.sqrt(nodeCount)
	return math.max(1.5, estimatedSpacing)
end

local function getSurfaceBasis(surfaceUp: Vector3, preferredDirection: Vector3): (Vector3, Vector3)
	local tangent = PlanetMath.getPlanarDirection(surfaceUp, preferredDirection, Vector3.xAxis)
	local bitangent = surfaceUp:Cross(tangent)
	if bitangent.Magnitude <= 0.001 then
		bitangent = surfaceUp:Cross(Vector3.zAxis)
	end

	return tangent, bitangent.Unit
end

local function getRandomPointAroundAnchor(randomGenerator: Random, spacing: number): Vector2
	local distance = spacing * randomGenerator:NextNumber(1, 1.85)
	local angle = randomGenerator:NextNumber(0, math.pi * 2)
	return Vector2.new(math.cos(angle) * distance, math.sin(angle) * distance)
end

local function isCandidateFarEnough(candidate: Vector2, existingPoints: { Vector2 }, spacing: number): boolean
	for _, existingPoint in existingPoints do
		if (candidate - existingPoint).Magnitude < spacing then
			return false
		end
	end

	return true
end

local function computePatchRadius(planarPoints: { Vector2 }): number
	local maxDistance = 0

	for _, planarPoint in planarPoints do
		maxDistance = math.max(maxDistance, planarPoint.Magnitude)
	end

	return maxDistance
end

local function buildWorldNode(
	planetCenter: Vector3,
	radius: number,
	centerOffset: Vector3,
	tangent: Vector3,
	bitangent: Vector3,
	planarPoint: Vector2,
	index: number
): OreNode
	local localOffset = centerOffset + tangent * planarPoint.X + bitangent * planarPoint.Y
	local normal = localOffset.Unit
	local surfacePosition = planetCenter + normal * radius
	return {
		index = index,
		position = surfacePosition,
		normal = normal,
		radialDistanceFromPatchCenter = planarPoint.Magnitude,
	}
end

function OrePatchGenerator.generate(options: GenerateOrePatchOptions): OrePatch
	local resolvedTime = if options.timeSeconds ~= nil then options.timeSeconds else PlanetMath.getMotionTime()
	local planetCenter = PlanetMath.getPlanetCenter(options.planet, resolvedTime)
	local centerOffset = options.centerPosition - planetCenter
	local surfaceUp = if centerOffset.Magnitude > 0.001 then centerOffset.Unit else Vector3.yAxis
	local preferredDirection = PlanetMath.getStarPosition()
		- planetCenter
		+ PlanetMath.getRotationAxis(options.planet) * options.planet.radius
	local tangent, bitangent = getSurfaceBasis(surfaceUp, preferredDirection)
	local nodeCount = clampNodeCount(options.nodeCount)
	local spacing = resolveMinSpacing(options.minSpacing, options.planet.radius, nodeCount)
	local resolvedSeed = if options.seed ~= nil then options.seed else DEFAULT_SEED
	local randomGenerator = Random.new(resolvedSeed)
	local nodes = table.create(nodeCount)
	local acceptedPlanarPoints = table.create(nodeCount)
	local activePlanarPoints = table.create(nodeCount)
	local maxAttempts = math.max(nodeCount * DEFAULT_ATTEMPT_MULTIPLIER, nodeCount + DEFAULT_CANDIDATE_TRIES)

	table.insert(acceptedPlanarPoints, Vector2.zero)
	table.insert(activePlanarPoints, Vector2.zero)
	table.insert(
		nodes,
		buildWorldNode(planetCenter, options.planet.radius, centerOffset, tangent, bitangent, Vector2.zero, 1)
	)

	local attempts = 0
	while #acceptedPlanarPoints < nodeCount and #activePlanarPoints > 0 and attempts < maxAttempts do
		attempts += 1
		local anchorIndex = randomGenerator:NextInteger(1, #activePlanarPoints)
		local anchor = activePlanarPoints[anchorIndex]
		local acceptedCandidate: Vector2? = nil

		for _ = 1, DEFAULT_CANDIDATE_TRIES do
			local candidate = anchor + getRandomPointAroundAnchor(randomGenerator, spacing)
			if isCandidateFarEnough(candidate, acceptedPlanarPoints, spacing) then
				acceptedCandidate = candidate
				break
			end
		end

		if acceptedCandidate ~= nil then
			table.insert(acceptedPlanarPoints, acceptedCandidate)
			table.insert(activePlanarPoints, acceptedCandidate)
			table.insert(
				nodes,
				buildWorldNode(
					planetCenter,
					options.planet.radius,
					centerOffset,
					tangent,
					bitangent,
					acceptedCandidate,
					#acceptedPlanarPoints
				)
			)
		else
			table.remove(activePlanarPoints, anchorIndex)
		end
	end

	while #acceptedPlanarPoints < nodeCount do
		local anchor = acceptedPlanarPoints[randomGenerator:NextInteger(1, #acceptedPlanarPoints)]
		local candidate = anchor + getRandomPointAroundAnchor(randomGenerator, spacing * 0.8)
		table.insert(acceptedPlanarPoints, candidate)
		table.insert(
			nodes,
			buildWorldNode(
				planetCenter,
				options.planet.radius,
				centerOffset,
				tangent,
				bitangent,
				candidate,
				#acceptedPlanarPoints
			)
		)
	end

	local patchRadius = computePatchRadius(acceptedPlanarPoints)

	return {
		planetName = options.planet.name,
		planetCenter = planetCenter,
		centerPosition = planetCenter + surfaceUp * options.planet.radius,
		surfaceUp = surfaceUp,
		tangent = tangent,
		bitangent = bitangent,
		patchRadius = patchRadius,
		nodeCount = #nodes,
		nodes = nodes,
	}
end

return OrePatchGenerator
