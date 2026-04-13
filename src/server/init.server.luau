--!strict

-- Disable Roblox default gravity. All gravity is handled per-planet on the client
-- via GravityController using VectorForce constraints.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

Workspace.Gravity = 0

local function configureCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
	if humanoid ~= nil and humanoid:IsA("Humanoid") then
		humanoid.BreakJointsOnDeath = false
		humanoid.RequiresNeck = false
	end
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
