--!strict

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PlanetMath = require(ReplicatedStorage.Shared.Prototype.Math.PlanetMath)

local UPDATE_EPSILON = 0.001

local heartbeatConnection: RBXScriptConnection? = nil

local LightingController = {}

local function approximatelyEqual(left: number, right: number): boolean
	return math.abs(left - right) <= UPDATE_EPSILON
end

function LightingController.start()
	if heartbeatConnection ~= nil then
		return
	end

	local defaultClockTime = Lighting.ClockTime
	local defaultGeographicLatitude = Lighting.GeographicLatitude
	local appliedClockTime: number? = nil
	local appliedGeographicLatitude: number? = nil
	local player = Players.LocalPlayer

	local function applyLighting(clockTime: number, geographicLatitude: number)
		if appliedClockTime ~= nil and appliedGeographicLatitude ~= nil then
			if
				approximatelyEqual(appliedClockTime, clockTime)
				and approximatelyEqual(appliedGeographicLatitude, geographicLatitude)
			then
				return
			end
		end

		Lighting.ClockTime = clockTime
		Lighting.GeographicLatitude = geographicLatitude
		appliedClockTime = clockTime
		appliedGeographicLatitude = geographicLatitude
	end

	local function restoreDefaultLighting()
		applyLighting(defaultClockTime, defaultGeographicLatitude)
	end

	heartbeatConnection = RunService.Heartbeat:Connect(function()
		local character = player.Character
		if character == nil then
			restoreDefaultLighting()
			return
		end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart == nil or not rootPart:IsA("BasePart") then
			restoreDefaultLighting()
			return
		end

		local currentTime = PlanetMath.getMotionTime()
		local activePlanet = PlanetMath.getActivePlanet(rootPart.Position, currentTime)
		if activePlanet == nil then
			return
		end

		local clockTime, geographicLatitude = PlanetMath.getLightingClockTimeAndGeographicLatitude(
			PlanetMath.getPlanetCenter(activePlanet, currentTime),
			PlanetMath.getStarPosition()
		)
		applyLighting(clockTime, geographicLatitude)
	end)
end

return LightingController
