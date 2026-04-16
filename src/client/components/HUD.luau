local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CruiseState = require(ReplicatedStorage.Shared.Prototype.CruiseState)
local MovementMode = require(ReplicatedStorage.Shared.Prototype.MovementMode)
local React = require(ReplicatedStorage.Packages.react)

local function getCharacterCruiseData(character: Model?): (string, number)
	if character == nil then
		return MovementMode.Planet, 0
	end

	local movementMode = character:GetAttribute(MovementMode.attributeName)
	local currentSpeed = character:GetAttribute(CruiseState.currentSpeedAttributeName)

	local resolvedMovementMode = if type(movementMode) == "string" then movementMode else MovementMode.Planet
	local resolvedCurrentSpeed = if type(currentSpeed) == "number" then currentSpeed else 0
	return resolvedMovementMode, resolvedCurrentSpeed
end

local function HUD()
	local player = Players.LocalPlayer
	local character, setCharacter = React.useState(player.Character)
	local movementMode, setMovementMode = React.useState(MovementMode.Planet)
	local currentCruiseSpeed, setCurrentCruiseSpeed = React.useState(0)

	React.useEffect(function()
		local function syncCharacter(nextCharacter: Model?)
			setCharacter(nextCharacter)
			local nextMode, nextSpeed = getCharacterCruiseData(nextCharacter)
			setMovementMode(nextMode)
			setCurrentCruiseSpeed(nextSpeed)
		end

		syncCharacter(player.Character)

		local characterAddedConnection = player.CharacterAdded:Connect(function(nextCharacter)
			syncCharacter(nextCharacter)
		end)
		local characterRemovingConnection = player.CharacterRemoving:Connect(function()
			syncCharacter(nil)
		end)

		return function()
			characterAddedConnection:Disconnect()
			characterRemovingConnection:Disconnect()
		end
	end, { player })

	React.useEffect(function()
		if character == nil then
			setMovementMode(MovementMode.Planet)
			setCurrentCruiseSpeed(0)
			return
		end

		local function syncAttributes()
			local nextMode, nextSpeed = getCharacterCruiseData(character)
			setMovementMode(nextMode)
			setCurrentCruiseSpeed(nextSpeed)
		end

		syncAttributes()
		local modeConnection = character:GetAttributeChangedSignal(MovementMode.attributeName):Connect(syncAttributes)
		local speedConnection =
			character:GetAttributeChangedSignal(CruiseState.currentSpeedAttributeName):Connect(syncAttributes)

		return function()
			modeConnection:Disconnect()
			speedConnection:Disconnect()
		end
	end, { character })

	local statusText = if movementMode == MovementMode.Cruise
		then string.format("Cruise speed %.0f", currentCruiseSpeed)
		else "React Lua wired into PlayerGui"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, {
		StatusCard = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundColor3 = Color3.fromRGB(20, 23, 31),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.fromOffset(0, 0),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(0, 14),
			}),
			Stroke = React.createElement("UIStroke", {
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.8,
			}),
			Padding = React.createElement("UIPadding", {
				PaddingBottom = UDim.new(0, 14),
				PaddingLeft = UDim.new(0, 18),
				PaddingRight = UDim.new(0, 18),
				PaddingTop = UDim.new(0, 14),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Title = React.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				LayoutOrder = 1,
				Size = UDim2.fromOffset(0, 0),
				Text = "Spacial Factory",
				TextColor3 = Color3.fromRGB(242, 244, 248),
				TextSize = 20,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Status = React.createElement("TextLabel", {
				AutomaticSize = Enum.AutomaticSize.XY,
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				LayoutOrder = 2,
				Size = UDim2.fromOffset(0, 0),
				Text = statusText,
				TextColor3 = Color3.fromRGB(181, 189, 206),
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			CruisePanel = if movementMode == MovementMode.Cruise
				then React.createElement("Frame", {
					AutomaticSize = Enum.AutomaticSize.XY,
					BackgroundColor3 = Color3.fromRGB(31, 37, 50),
					BackgroundTransparency = 0.1,
					BorderSizePixel = 0,
					LayoutOrder = 3,
					Size = UDim2.fromOffset(0, 0),
				}, {
					Corner = React.createElement("UICorner", {
						CornerRadius = UDim.new(0, 10),
					}),
					Padding = React.createElement("UIPadding", {
						PaddingBottom = UDim.new(0, 10),
						PaddingLeft = UDim.new(0, 12),
						PaddingRight = UDim.new(0, 12),
						PaddingTop = UDim.new(0, 10),
					}),
					Layout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						Padding = UDim.new(0, 4),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
					Label = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamMedium,
						LayoutOrder = 1,
						Size = UDim2.fromOffset(0, 0),
						Text = "Cruise Monitor",
						TextColor3 = Color3.fromRGB(222, 228, 240),
						TextSize = 13,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Value = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						LayoutOrder = 2,
						Size = UDim2.fromOffset(0, 0),
						Text = string.format("%.0f u/s", currentCruiseSpeed),
						TextColor3 = Color3.fromRGB(129, 225, 255),
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
					Hint = React.createElement("TextLabel", {
						AutomaticSize = Enum.AutomaticSize.XY,
						BackgroundTransparency = 1,
						Font = Enum.Font.Gotham,
						LayoutOrder = 3,
						Size = UDim2.fromOffset(0, 0),
						Text = "W accelera  S reduz  Shift acelera forte",
						TextColor3 = Color3.fromRGB(181, 189, 206),
						TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Left,
					}),
				})
				else nil,
		}),
		CruiseReticle = if movementMode == MovementMode.Cruise
			then React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(28, 28),
				ZIndex = 20,
			}, {
				CenterDot = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(129, 225, 255),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(4, 4),
					ZIndex = 22,
				}, {
					Corner = React.createElement("UICorner", {
						CornerRadius = UDim.new(1, 0),
					}),
				}),
				Horizontal = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(190, 245, 255),
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(28, 2),
					ZIndex = 21,
				}),
				Vertical = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(190, 245, 255),
					BackgroundTransparency = 0.15,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(2, 28),
					ZIndex = 21,
				}),
			})
			else nil,
	})
end

return HUD
