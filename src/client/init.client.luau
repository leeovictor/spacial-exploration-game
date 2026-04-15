local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages["react-roblox"])
local PlanetManualTestBootstrap = require(script.PlanetManualTestBootstrap)
local CameraController = require(script.Prototype.CameraController)
local PlanetRotationController = require(script.Prototype.PlanetRotationController)
local PlayerController = require(script.Prototype.PlayerController)
local App = require(script.UI.App)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local root = ReactRoblox.createRoot(playerGui) -- Create root for rendering

PlanetManualTestBootstrap.run()
PlanetRotationController.start()
CameraController.start()
PlayerController.start()

root:render(React.createElement(App))
