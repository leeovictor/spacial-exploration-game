--!strict

local AssetService = game:GetService("AssetService")
local RunService = game:GetService("RunService")

export type PlanetBuildOptions = {
	name: string?,
	parent: Instance?,
	center: Vector3,
	radius: number,
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
	rotationAxis: Vector3?,
	angularSpeed: number?,
	debugShowRotationAxis: boolean?,
	debugShowEquator: boolean?,
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
local PLANET_PIVOT_PART_NAME = "PlanetPivot"
local ROTATION_AXIS_PART_NAME = "PlanetRotationAxis"
local ROTATION_AXIS_POSITIVE_CAP_NAME = "PlanetRotationAxisPositiveCap"
local EQUATOR_SEGMENT_NAME = "PlanetEquatorSegment"
local MIN_ROTATION_AXIS_MAGNITUDE = 0.0001
local EQUATOR_SEGMENT_COUNT = 36

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

local function getNormalizedRotationAxis(axis: Vector3?): Vector3
	if axis == nil or axis.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		return Vector3.yAxis
	end

	return axis.Unit
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

local function createModelPivot(model: Model, center: Vector3): BasePart
	local pivotPart = Instance.new("Part")
	pivotPart.Name = PLANET_PIVOT_PART_NAME
	pivotPart.Anchored = true
	pivotPart.CanCollide = false
	pivotPart.CanQuery = false
	pivotPart.CanTouch = false
	pivotPart.Transparency = 1
	pivotPart.CastShadow = false
	pivotPart.Locked = true
	pivotPart.Size = Vector3.new(1, 1, 1)
	pivotPart.CFrame = CFrame.new(center)
	pivotPart.Parent = model

	model.PrimaryPart = pivotPart

	return pivotPart
end

local function createRotationAxisDebug(model: Model, options: PlanetBuildOptions)
	if options.debugShowRotationAxis ~= true or not RunService:IsStudio() then
		return
	end

	local axis = getNormalizedRotationAxis(options.rotationAxis)
	local center = options.center
	local axisLength = options.radius * 2.4
	local thickness = math.max(options.radius * 0.04, 0.6)
	local positiveCapOffset = axis * (axisLength * 0.5)
	local upVector = if math.abs(axis:Dot(Vector3.yAxis)) > 0.98 then Vector3.xAxis else Vector3.yAxis

	local axisPart = Instance.new("Part")
	axisPart.Name = ROTATION_AXIS_PART_NAME
	axisPart.Anchored = true
	axisPart.CanCollide = false
	axisPart.CanQuery = false
	axisPart.CanTouch = false
	axisPart.CastShadow = false
	axisPart.Locked = true
	axisPart.Material = Enum.Material.Neon
	axisPart.Color = Color3.fromRGB(255, 196, 64)
	axisPart.Transparency = 0.1
	axisPart.Size = Vector3.new(thickness, thickness, axisLength)
	axisPart.CFrame = CFrame.lookAt(center, center + axis, upVector)
	axisPart.Parent = model

	local positiveCap = Instance.new("Part")
	positiveCap.Name = ROTATION_AXIS_POSITIVE_CAP_NAME
	positiveCap.Shape = Enum.PartType.Ball
	positiveCap.Anchored = true
	positiveCap.CanCollide = false
	positiveCap.CanQuery = false
	positiveCap.CanTouch = false
	positiveCap.CastShadow = false
	positiveCap.Locked = true
	positiveCap.Material = Enum.Material.Neon
	positiveCap.Color = Color3.fromRGB(255, 92, 92)
	positiveCap.Transparency = 0
	positiveCap.Size = Vector3.one * math.max(options.radius * 0.12, 1.2)
	positiveCap.CFrame = CFrame.new(center + positiveCapOffset)
	positiveCap.Parent = model
end

local function createEquatorDebug(model: Model, options: PlanetBuildOptions)
	if options.debugShowEquator ~= true then
		return
	end

	local axis = getNormalizedRotationAxis(options.rotationAxis)
	local center = options.center
	local thickness = math.max(options.radius * 0.02, 0.35)
	local equatorRadius = options.radius * 1.01
	local basisX = axis:Cross(Vector3.yAxis)
	if basisX.Magnitude <= MIN_ROTATION_AXIS_MAGNITUDE then
		basisX = axis:Cross(Vector3.xAxis)
	end
	basisX = basisX.Unit
	local basisZ = axis:Cross(basisX).Unit

	for segmentIndex = 0, EQUATOR_SEGMENT_COUNT - 1 do
		local alpha0 = (segmentIndex / EQUATOR_SEGMENT_COUNT) * math.pi * 2
		local alpha1 = ((segmentIndex + 1) / EQUATOR_SEGMENT_COUNT) * math.pi * 2
		local point0 = center + (basisX * math.cos(alpha0) + basisZ * math.sin(alpha0)) * equatorRadius
		local point1 = center + (basisX * math.cos(alpha1) + basisZ * math.sin(alpha1)) * equatorRadius
		local midpoint = (point0 + point1) * 0.5
		local tangent = point1 - point0

		local segment = Instance.new("Part")
		segment.Name = EQUATOR_SEGMENT_NAME
		segment.Anchored = true
		segment.CanCollide = false
		segment.CanQuery = false
		segment.CanTouch = false
		segment.CastShadow = false
		segment.Locked = true
		segment.Material = Enum.Material.Neon
		segment.Color = Color3.fromRGB(64, 214, 255)
		segment.Transparency = 0.2
		segment.Size = Vector3.new(thickness, thickness, tangent.Magnitude)
		segment.CFrame = CFrame.lookAt(midpoint, midpoint + tangent.Unit, (midpoint - center).Unit)
		segment.Parent = model
	end
end

local function buildEditablePatchMesh(
	descriptor: PlanetPatchDescriptor,
	radius: number,
	resolution: number
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
			local displacedOffset = getSphereOffset(descriptor.faceIndex, patchU, patchV, radius)
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
	fallbackSphere.Color = if options.fallbackColor ~= nil then options.fallbackColor else Color3.fromRGB(245, 186, 208)
	fallbackSphere.Transparency = if options.fallbackTransparency ~= nil then options.fallbackTransparency else 0
	fallbackSphere.TopSurface = Enum.SurfaceType.Smooth
	fallbackSphere.BottomSurface = Enum.SurfaceType.Smooth
	fallbackSphere.Parent = model

	model:SetAttribute("PlanetUsedEditableMeshes", false)
	model:SetAttribute("PlanetBuildErrors", table.concat(errors, "\n"))
end

local function cleanupGeneratedPatches(patches: { PlanetPatch })
	for _, patch in patches do
		patch.meshPart:Destroy()

		pcall(function()
			patch.editableMesh:Destroy()
		end)
	end

	table.clear(patches)
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
	createModelPivot(model, options.center)
	createRotationAxisDebug(model, options)
	createEquatorDebug(model, options)

	model:SetAttribute("PlanetCenterX", options.center.X)
	model:SetAttribute("PlanetCenterY", options.center.Y)
	model:SetAttribute("PlanetCenterZ", options.center.Z)
	model:SetAttribute("PlanetRadius", options.radius)
	model:SetAttribute("PlanetPatchResolution", patchResolution)
	model:SetAttribute("PlanetFaceSubdivisions", faceSubdivisions)
	model:SetAttribute("PlanetRotationAxisX", getNormalizedRotationAxis(options.rotationAxis).X)
	model:SetAttribute("PlanetRotationAxisY", getNormalizedRotationAxis(options.rotationAxis).Y)
	model:SetAttribute("PlanetRotationAxisZ", getNormalizedRotationAxis(options.rotationAxis).Z)
	model:SetAttribute("PlanetAngularSpeed", if options.angularSpeed ~= nil then options.angularSpeed else 0)

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
			local editableMesh = buildEditablePatchMesh(descriptor, options.radius, patchResolution)
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

	if #errors > 0 then
		cleanupGeneratedPatches(patches)
		createFallbackPlanet(model, options, errors)

		return {
			model = model,
			patches = patches,
			usedEditableMeshes = false,
			errors = errors,
		}
	end

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
