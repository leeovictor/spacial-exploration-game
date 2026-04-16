--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OrePatchGenerator = require(ReplicatedStorage.Shared.Prototype.OrePatchGenerator)

type OrePatch = OrePatchGenerator.OrePatch
type OreNode = OrePatchGenerator.OreNode

local PATCH_CONTAINER_NAME = "DebugOrePatch"
local NODE_NAME_PREFIX = "OreNode"

local OrePatchRenderer = {}

local function destroyExistingContainer(parent: Instance)
	local existingContainer = parent:FindFirstChild(PATCH_CONTAINER_NAME)
	if existingContainer ~= nil then
		existingContainer:Destroy()
	end
end

local function createOreNodePart(node: OreNode, patchRadius: number): Part
	local radius = math.max(1.6, patchRadius * 0.065)
	local height = math.max(2.25, patchRadius * 0.09)
	local centerPosition = node.position + node.normal * (height * 0.5)
	local tangent = node.normal:Cross(Vector3.yAxis)
	if tangent.Magnitude <= 0.001 then
		tangent = node.normal:Cross(Vector3.xAxis)
	end
	tangent = tangent.Unit
	local bitangent = node.normal:Cross(tangent).Unit

	local oreNodePart = Instance.new("Part")
	oreNodePart.Name = string.format("%s%02d", NODE_NAME_PREFIX, node.index)
	oreNodePart.Shape = Enum.PartType.Cylinder
	oreNodePart.Anchored = true
	oreNodePart.CanCollide = false
	oreNodePart.CanQuery = false
	oreNodePart.CanTouch = false
	oreNodePart.CastShadow = false
	oreNodePart.Locked = true
	oreNodePart.Material = Enum.Material.Metal
	oreNodePart.Color = Color3.fromRGB(212, 170, 72)
	oreNodePart.Transparency = 0.05
	oreNodePart.Size = Vector3.new(height, radius * 2, radius * 2)
	oreNodePart.CFrame = CFrame.fromMatrix(centerPosition, node.normal, tangent, bitangent)
	return oreNodePart
end

function OrePatchRenderer.render(parent: Instance, patch: OrePatch): Model
	destroyExistingContainer(parent)

	local container = Instance.new("Model")
	container.Name = PATCH_CONTAINER_NAME
	container.Parent = parent

	for _, node in patch.nodes do
		local oreNodePart = createOreNodePart(node, patch.patchRadius)
		oreNodePart.Parent = container
	end

	return container
end

return OrePatchRenderer
