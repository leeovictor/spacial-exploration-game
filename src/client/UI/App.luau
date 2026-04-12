local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReactModule = Packages:WaitForChild("react")
local Components = script.Parent.Parent:WaitForChild("components")
local HUDModule = Components:WaitForChild("HUD")

local React = require(ReactModule)
local HUD = require(HUDModule)

local function App()
	return React.createElement("ScreenGui", {
		DisplayOrder = 10,
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, {
		HUD = React.createElement(HUD),
	})
end

return App