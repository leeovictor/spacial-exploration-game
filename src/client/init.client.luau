local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReactModule = Packages:WaitForChild("react")
local ReactRobloxModule = Packages:WaitForChild("react-roblox")
local PlanetManualTestBootstrapModule = script:WaitForChild("PlanetManualTestBootstrap")
local UIRoot = script:WaitForChild("UI")
local AppModule = UIRoot:WaitForChild("App")

local React = require(ReactModule :: any)
local ReactRoblox = require(ReactRobloxModule :: any)
local PlanetManualTestBootstrap = require(PlanetManualTestBootstrapModule :: any)
local App = require(AppModule :: any)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(playerGui) -- Create root for rendering

PlanetManualTestBootstrap.run()

root:render(React.createElement(App))
