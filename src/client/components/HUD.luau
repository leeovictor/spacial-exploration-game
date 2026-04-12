local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ReactModule = Packages:WaitForChild("react")

local React = require(ReactModule)

local function HUD()
	return React.createElement("Frame", {
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
			Text = "React Lua wired into PlayerGui",
			TextColor3 = Color3.fromRGB(181, 189, 206),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return HUD