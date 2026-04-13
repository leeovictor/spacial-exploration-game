--!strict

local AssetService = game:GetService("AssetService")

export type PlanetBuildOptions = {
	name: string?,
	parent: Instance?,
	center: Vector3,
	radius: number,
	terrain: PlanetTerrainOptions?,
	patchResolution: number?,
	faceSubdivisions: number?,
	anchored: boolean?,
	canCollide: boolean?,
	canQuery: boolean?,
	canTouch: boolean?,
	material: Enum.Material?,
	color: Color3?,
	transparency: number?,
	doubleSided: boolean?,
	castShadow: boolean?,
	renderFidelity: Enum.RenderFidelity?,
	collisionFidelity: Enum.CollisionFidelity?,
	fallbackMaterial: Enum.Material?,
	fallbackColor: Color3?,
	fallbackTransparency: number?,
}

export type PlanetTerrainOptions = {
	amplitude: number?,
	frequency: number?,
	octaves: number?,
	persistence: number?,
	lacunarity: number?,
	seed: number?,
}

export type PlanetPatch = {
	meshPart: MeshPart,
	editableMesh: EditableMesh,
	faceIndex: number,
	patchX: number,
	patchY: number,
}

export type PlanetBuildResult = {
	model: Model,
	patches: { PlanetPatch },
	usedEditableMeshes: boolean,
	errors: { string },
}

type PlanetPatchDescriptor = {
	faceIndex: number,
	patchX: number,
	patchY: number,
	minU: number,
	maxU: number,
	minV: number,
	maxV: number,
	centerOffset: Vector3,
}

local DEFAULT_PATCH_RESOLUTION = 12
local DEFAULT_FACE_SUBDIVISIONS = 2
local MAX_PATCH_RESOLUTION = 100
local DEFAULT_TERRAIN_FREQUENCY = 2
local DEFAULT_TERRAIN_OCTAVES = 4
local DEFAULT_TERRAIN_PERSISTENCE = 0.5
local DEFAULT_TERRAIN_LACUNARITY = 2

local FACE_AXES = {
	{ normal = Vector3.new(0, 0, 1), right = Vector3.new(1, 0, 0), up = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(0, 0, -1), right = Vector3.new(-1, 0, 0), up = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(1, 0, 0), right = Vector3.new(0, 0, -1), up = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(-1, 0, 0), right = Vector3.new(0, 0, 1), up = Vector3.new(0, 1, 0) },
	{ normal = Vector3.new(0, 1, 0), right = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, -1) },
	{ normal = Vector3.new(0, -1, 0), right = Vector3.new(1, 0, 0), up = Vector3.new(0, 0, 1) },
}

local PlanetEditableMeshBuilder = {}

local function lerp(a: number, b: number, alpha: number): number
	return a + (b - a) * alpha
end

local function getGridIndex(x: number, y: number, resolution: number): number
	return y * (resolution + 1) + x + 1
end

local function getFaceAxes(faceIndex: number)
	local faceAxes = FACE_AXES[faceIndex]
	if faceAxes == nil then
		error(string.format("Unsupported cube face index %d", faceIndex))
	end

	return faceAxes
end

local function getSphereOffset(faceIndex: number, u: number, v: number, radius: number): Vector3
	local faceAxes = getFaceAxes(faceIndex)
	local cubePoint = faceAxes.normal + faceAxes.right * u + faceAxes.up * v
	return cubePoint.Unit * radius
end

local function getTerrainHeight(unitDirection: Vector3, terrainOptions: PlanetTerrainOptions?): number
	if terrainOptions == nil then
		return 0
	end

	local amplitude = if terrainOptions.amplitude ~= nil then terrainOptions.amplitude else 0
	if amplitude == 0 then
		return 0
	end

	local frequency = if terrainOptions.frequency ~= nil then terrainOptions.frequency else DEFAULT_TERRAIN_FREQUENCY
	local octaves = if terrainOptions.octaves ~= nil then terrainOptions.octaves else DEFAULT_TERRAIN_OCTAVES
	local persistence = if terrainOptions.persistence ~= nil
		then terrainOptions.persistence
		else DEFAULT_TERRAIN_PERSISTENCE
	local lacunarity = if terrainOptions.lacunarity ~= nil
		then terrainOptions.lacunarity
		else DEFAULT_TERRAIN_LACUNARITY
	local seed = if terrainOptions.seed ~= nil then terrainOptions.seed else 0

	local noiseValue = 0
	local currentAmplitude = 1
	local currentFrequency = frequency
	local amplitudeSum = 0

	for _ = 1, octaves do
		noiseValue += math.noise(
			unitDirection.X * currentFrequency + seed * 0.173,
			unitDirection.Y * currentFrequency + seed * 0.417,
			unitDirection.Z * currentFrequency + seed * 0.691
		) * currentAmplitude
		amplitudeSum += currentAmplitude
		currentAmplitude *= persistence
		currentFrequency *= lacunarity
	end

	if amplitudeSum == 0 then
		return 0
	end

	return noiseValue / amplitudeSum * amplitude
end

local function getDisplacedOffset(
	faceIndex: number,
	u: number,
	v: number,
	radius: number,
	terrainOptions: PlanetTerrainOptions?
): Vector3
	local sphereOffset = getSphereOffset(faceIndex, u, v, radius)
	local unitDirection = sphereOffset.Unit
	local terrainHeight = getTerrainHeight(unitDirection, terrainOptions)

	return unitDirection * (radius + terrainHeight)
end

local function getVertexNormalFromOffsets(gridOffsets: { Vector3 }, x: number, y: number, resolution: number): Vector3
	local centerIndex = getGridIndex(x, y, resolution)
	local centerOffset = gridOffsets[centerIndex]
	local leftOffset = gridOffsets[getGridIndex(math.max(x - 1, 0), y, resolution)]
	local rightOffset = gridOffsets[getGridIndex(math.min(x + 1, resolution), y, resolution)]
	local downOffset = gridOffsets[getGridIndex(x, math.max(y - 1, 0), resolution)]
	local upOffset = gridOffsets[getGridIndex(x, math.min(y + 1, resolution), resolution)]

	local tangentU = rightOffset - leftOffset
	local tangentV = upOffset - downOffset
	local normal = tangentU:Cross(tangentV)

	if normal.Magnitude <= 1e-5 then
		return centerOffset.Unit
	end

	normal = normal.Unit

	if normal:Dot(centerOffset.Unit) < 0 then
		normal = -normal
	end

	return normal
end

local function createPatchDescriptors(radius: number, faceSubdivisions: number): { PlanetPatchDescriptor }
	local descriptors = {}
	local patchSize = 2 / faceSubdivisions

	for faceIndex = 1, #FACE_AXES do
		for patchY = 0, faceSubdivisions - 1 do
			for patchX = 0, faceSubdivisions - 1 do
				local minU = -1 + patchX * patchSize
				local maxU = minU + patchSize
				local minV = -1 + patchY * patchSize
				local maxV = minV + patchSize
				local centerU = (minU + maxU) * 0.5
				local centerV = (minV + maxV) * 0.5

				table.insert(descriptors, {
					faceIndex = faceIndex,
					patchX = patchX,
					patchY = patchY,
					minU = minU,
					maxU = maxU,
					minV = minV,
					maxV = maxV,
					centerOffset = getSphereOffset(faceIndex, centerU, centerV, radius),
				})
			end
		end
	end

	return descriptors
end

local function applyCommonPartProperties(meshPart: MeshPart, options: PlanetBuildOptions)
	meshPart.Anchored = if options.anchored ~= nil then options.anchored else true
	meshPart.CanCollide = if options.canCollide ~= nil then options.canCollide else true
	meshPart.CanQuery = if options.canQuery ~= nil then options.canQuery else true
	meshPart.CanTouch = if options.canTouch ~= nil then options.canTouch else false
	meshPart.Material = if options.material ~= nil then options.material else Enum.Material.SmoothPlastic
	meshPart.Color = if options.color ~= nil then options.color else Color3.fromRGB(110, 132, 96)
	meshPart.Transparency = if options.transparency ~= nil then options.transparency else 0
	meshPart.CastShadow = if options.castShadow ~= nil then options.castShadow else true
	meshPart.Massless = true

	if options.doubleSided ~= nil then
		pcall(function()
			meshPart.DoubleSided = options.doubleSided :: boolean
		end)
	end

	meshPart:SetAttribute("PlanetSurfacePatch", true)
end

local function buildEditablePatchMesh(
	descriptor: PlanetPatchDescriptor,
	radius: number,
	resolution: number,
	terrainOptions: PlanetTerrainOptions?
): EditableMesh
	local editableMesh = AssetService:CreateEditableMesh()
	if editableMesh == nil then
		error("AssetService:CreateEditableMesh() returned nil")
	end

	local pointCount = (resolution + 1) * (resolution + 1)
	local vertexIds: { number } = table.create(pointCount)
	local gridOffsets: { Vector3 } = table.create(pointCount)
	local normalIds: { number } = table.create(pointCount)
	local uvIds: { number } = table.create(pointCount)

	for y = 0, resolution do
		local vAlpha = y / resolution
		local patchV = lerp(descriptor.minV, descriptor.maxV, vAlpha)

		for x = 0, resolution do
			local uAlpha = x / resolution
			local patchU = lerp(descriptor.minU, descriptor.maxU, uAlpha)
			local displacedOffset = getDisplacedOffset(descriptor.faceIndex, patchU, patchV, radius, terrainOptions)
			local localPosition = displacedOffset - descriptor.centerOffset
			local vertexIndex = getGridIndex(x, y, resolution)

			vertexIds[vertexIndex] = editableMesh:AddVertex(localPosition)
			gridOffsets[vertexIndex] = displacedOffset
			uvIds[vertexIndex] = editableMesh:AddUV(Vector2.new(uAlpha, vAlpha))
		end
	end

	for y = 0, resolution do
		for x = 0, resolution do
			local vertexIndex = getGridIndex(x, y, resolution)
			local normal = getVertexNormalFromOffsets(gridOffsets, x, y, resolution)
			normalIds[vertexIndex] = editableMesh:AddNormal(normal)
		end
	end

	for y = 0, resolution - 1 do
		for x = 0, resolution - 1 do
			local aIndex = getGridIndex(x, y, resolution)
			local bIndex = getGridIndex(x + 1, y, resolution)
			local cIndex = getGridIndex(x, y + 1, resolution)
			local dIndex = getGridIndex(x + 1, y + 1, resolution)

			local faceOne = editableMesh:AddTriangle(vertexIds[aIndex], vertexIds[bIndex], vertexIds[dIndex])
			editableMesh:SetFaceNormals(faceOne, { normalIds[aIndex], normalIds[bIndex], normalIds[dIndex] })
			editableMesh:SetFaceUVs(faceOne, { uvIds[aIndex], uvIds[bIndex], uvIds[dIndex] })

			local faceTwo = editableMesh:AddTriangle(vertexIds[aIndex], vertexIds[dIndex], vertexIds[cIndex])
			editableMesh:SetFaceNormals(faceTwo, { normalIds[aIndex], normalIds[dIndex], normalIds[cIndex] })
			editableMesh:SetFaceUVs(faceTwo, { uvIds[aIndex], uvIds[dIndex], uvIds[cIndex] })
		end
	end

	return editableMesh
end

local function createMeshPartFromEditableMesh(
	editableMesh: EditableMesh,
	descriptor: PlanetPatchDescriptor,
	options: PlanetBuildOptions
): MeshPart
	local newMeshPart = AssetService:CreateMeshPartAsync(Content.fromObject(editableMesh), {
		CollisionFidelity = if options.collisionFidelity ~= nil
			then options.collisionFidelity
			else Enum.CollisionFidelity.Hull,
		RenderFidelity = if options.renderFidelity ~= nil
			then options.renderFidelity
			else Enum.RenderFidelity.Automatic,
	})

	newMeshPart.Name = string.format("Patch_F%d_X%d_Y%d", descriptor.faceIndex, descriptor.patchX, descriptor.patchY)
	applyCommonPartProperties(newMeshPart, options)

	return newMeshPart
end

local function createFallbackPlanet(model: Model, options: PlanetBuildOptions, errors: { string })
	local fallbackSphere = Instance.new("Part")
	fallbackSphere.Name = "FallbackSphere"
	fallbackSphere.Shape = Enum.PartType.Ball
	fallbackSphere.Size = Vector3.one * options.radius * 2
	fallbackSphere.Position = options.center
	fallbackSphere.Anchored = if options.anchored ~= nil then options.anchored else true
	fallbackSphere.CanCollide = if options.canCollide ~= nil then options.canCollide else true
	fallbackSphere.CanQuery = if options.canQuery ~= nil then options.canQuery else true
	fallbackSphere.CanTouch = if options.canTouch ~= nil then options.canTouch else false
	fallbackSphere.Material = if options.fallbackMaterial ~= nil then options.fallbackMaterial else Enum.Material.Slate
	fallbackSphere.Color = if options.fallbackColor ~= nil then options.fallbackColor else Color3.fromRGB(82, 96, 73)
	fallbackSphere.Transparency = if options.fallbackTransparency ~= nil then options.fallbackTransparency else 0
	fallbackSphere.TopSurface = Enum.SurfaceType.Smooth
	fallbackSphere.BottomSurface = Enum.SurfaceType.Smooth
	fallbackSphere.Parent = model

	model.PrimaryPart = fallbackSphere
	model:SetAttribute("PlanetUsedEditableMeshes", false)
	model:SetAttribute("PlanetBuildErrors", table.concat(errors, "\n"))
end

function PlanetEditableMeshBuilder.isSupported(): boolean
	return AssetService.CreateEditableMesh ~= nil and AssetService.CreateMeshPartAsync ~= nil
end

function PlanetEditableMeshBuilder.createPlanet(options: PlanetBuildOptions): PlanetBuildResult
	assert(options.radius > 0, "PlanetBuildOptions.radius must be greater than zero")

	local patchResolution = if options.patchResolution ~= nil then options.patchResolution else DEFAULT_PATCH_RESOLUTION
	local faceSubdivisions = if options.faceSubdivisions ~= nil
		then options.faceSubdivisions
		else DEFAULT_FACE_SUBDIVISIONS

	assert(patchResolution >= 1, "PlanetBuildOptions.patchResolution must be at least 1")
	assert(
		patchResolution <= MAX_PATCH_RESOLUTION,
		string.format("PlanetBuildOptions.patchResolution must be <= %d", MAX_PATCH_RESOLUTION)
	)
	assert(faceSubdivisions >= 1, "PlanetBuildOptions.faceSubdivisions must be at least 1")

	local model = Instance.new("Model")
	model.Name = if options.name ~= nil then options.name else "Planet"
	model.Parent = if options.parent ~= nil then options.parent else workspace

	model:SetAttribute("PlanetCenterX", options.center.X)
	model:SetAttribute("PlanetCenterY", options.center.Y)
	model:SetAttribute("PlanetCenterZ", options.center.Z)
	model:SetAttribute("PlanetRadius", options.radius)
	model:SetAttribute("PlanetPatchResolution", patchResolution)
	model:SetAttribute("PlanetFaceSubdivisions", faceSubdivisions)

	if options.terrain ~= nil then
		model:SetAttribute(
			"PlanetTerrainAmplitude",
			if options.terrain.amplitude ~= nil then options.terrain.amplitude else 0
		)
		model:SetAttribute(
			"PlanetTerrainFrequency",
			if options.terrain.frequency ~= nil then options.terrain.frequency else DEFAULT_TERRAIN_FREQUENCY
		)
		model:SetAttribute(
			"PlanetTerrainOctaves",
			if options.terrain.octaves ~= nil then options.terrain.octaves else DEFAULT_TERRAIN_OCTAVES
		)
	end

	local errors = {}
	local patches = {}

	if not PlanetEditableMeshBuilder.isSupported() then
		table.insert(errors, "EditableMesh APIs are unavailable in this environment")
		createFallbackPlanet(model, options, errors)

		return {
			model = model,
			patches = patches,
			usedEditableMeshes = false,
			errors = errors,
		}
	end

	local descriptors = createPatchDescriptors(options.radius, faceSubdivisions)

	for _, descriptor in descriptors do
		local success, resultOrMessage = pcall(function()
			local editableMesh = buildEditablePatchMesh(descriptor, options.radius, patchResolution, options.terrain)
			local meshPart = createMeshPartFromEditableMesh(editableMesh, descriptor, options)

			meshPart.CFrame = CFrame.new(options.center + descriptor.centerOffset)
			meshPart.Parent = model

			meshPart:SetAttribute("PlanetFaceIndex", descriptor.faceIndex)
			meshPart:SetAttribute("PlanetPatchX", descriptor.patchX)
			meshPart:SetAttribute("PlanetPatchY", descriptor.patchY)

			return {
				meshPart = meshPart,
				editableMesh = editableMesh,
				faceIndex = descriptor.faceIndex,
				patchX = descriptor.patchX,
				patchY = descriptor.patchY,
			}
		end)

		if success then
			table.insert(patches, resultOrMessage :: PlanetPatch)
		else
			local errorMessage = string.format(
				"Patch F%d X%d Y%d failed: %s",
				descriptor.faceIndex,
				descriptor.patchX,
				descriptor.patchY,
				tostring(resultOrMessage)
			)
			table.insert(errors, errorMessage)

			if string.find(tostring(resultOrMessage), "CreateEditableMesh() returned nil", 1, true) ~= nil then
				break
			end
		end
	end

	if #patches == 0 then
		createFallbackPlanet(model, options, errors)

		return {
			model = model,
			patches = patches,
			usedEditableMeshes = false,
			errors = errors,
		}
	end

	model.PrimaryPart = patches[1].meshPart
	model:SetAttribute("PlanetUsedEditableMeshes", true)
	model:SetAttribute("PlanetPatchCount", #patches)

	if #errors > 0 then
		model:SetAttribute("PlanetBuildErrors", table.concat(errors, "\n"))
	end

	return {
		model = model,
		patches = patches,
		usedEditableMeshes = true,
		errors = errors,
	}
end

return PlanetEditableMeshBuilder
