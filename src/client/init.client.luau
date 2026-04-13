local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReactModule = Packages:WaitForChild("react")
local ReactRobloxModule = Packages:WaitForChild("react-roblox")
local PlanetManualTestBootstrapModule = script:WaitForChild("PlanetManualTestBootstrap")
local CameraControllerModule = script:WaitForChild("Prototype"):WaitForChild("CameraController")
local PlayerControllerModule = script:WaitForChild("Prototype"):WaitForChild("PlayerController")
local UIRoot = script:WaitForChild("UI")
local AppModule = UIRoot:WaitForChild("App")

local React = require(ReactModule :: any)
local ReactRoblox = require(ReactRobloxModule :: any)
local PlanetManualTestBootstrap = require(PlanetManualTestBootstrapModule :: any)
local CameraController = require(CameraControllerModule :: any)
local PlayerController = require(PlayerControllerModule :: any)
local App = require(AppModule :: any)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(playerGui) -- Create root for rendering

PlanetManualTestBootstrap.run()
CameraController.start()
PlayerController.start()

root:render(React.createElement(App))
