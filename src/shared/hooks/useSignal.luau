local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

type ConnectionLike = {
	Disconnect: (self: ConnectionLike) -> (),
}

type SignalLike = {
	Connect: (self: SignalLike, callback: (...any) -> ()) -> ConnectionLike,
}

local function useSignal(signal: SignalLike, initialValue: any, mapValue: ((...any) -> any)?)
	local value, setValue = React.useState(initialValue)

	React.useEffect(function()
		local connection = signal:Connect(function(...)
			if mapValue ~= nil then
				setValue(mapValue(...))
				return
			end

			setValue(... :: any)
		end)

		return function()
			connection:Disconnect()
		end
	end, { signal, mapValue })

	return value
end

return useSignal
