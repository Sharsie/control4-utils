---@alias GenericGroupAddressShape<T> { DPT: DPT, GA: string, Name: T, Value: number | nil }

---@param name GROUP_ADDRESS_NAME
---@param ga string
---@param dpt DPT
GroupAddress = function(name, ga, dpt)
	---@class GroupAddress
	---@field DPT DPT
	---@field GA string
	---@field Name GROUP_ADDRESS_NAME
	---@field Value number|nil
	local class = {
		DPT = dpt,
		GA = ga,
		Name = name,
		Value = nil,
	}

	---@param v number
	function class:Send(v)
		class.Value = v
		KNXProxy:SendToKNX(class.DPT, class.GA, class.Value)
	end

	return class
end

Addresses = (function()
	---@class Addresses
	local class = {}

	---@type {[GROUP_ADDRESS_NAME]: GroupAddress}
	local namedRegistry = {}
	---@type {[string]: GroupAddress|nil}
	local addressedRegistry = {}

	---@type {[string]: GroupAddress}
	local watchedRegistry = {}

	---@type {[GROUP_ADDRESS_NAME]: nil|fun(current: GroupAddress, newVal: number, prevVal: number?)}
	local changedRegistry = {}

	for _, v in pairs(CreateGroupAddresses()) do
		addressedRegistry[v.GA] = v
		namedRegistry[v.Name] = v
	end

	---Get GroupAddress by name
	---@param n GROUP_ADDRESS_NAME
	---@return GroupAddress
	function class:Get(n)
		if namedRegistry[n] == nil then
			Logger.Error(
				"error accessing non existing group address name, this should never happen...never",
				{ name = n }
			)
		end
		return namedRegistry[n]
	end

	---Get GroupAddress by address if defined
	---@param ga string
	---@return GroupAddress|nil
	function class:GetByGA(ga)
		return addressedRegistry[ga]
	end

	---@param n GROUP_ADDRESS_NAME
	---@param onValueChange nil|fun(current: GroupAddress, newVal: number, prevVal: number?)
	function class:Watch(n, onValueChange)
		if namedRegistry[n] == nil then
			Logger.Error(
				"error accessing non existing group address name to Listen, this should never happen...never",
				{ name = n }
			)
		end
		local g = namedRegistry[n]
		watchedRegistry[g.GA] = g

		if onValueChange ~= nil then
			changedRegistry[g.GA] = onValueChange
		end
	end

	HookIntoOnDriverLateInit(function()
		if not KNXProxy or not OneShotTimer then
			Logger.Error(
				"KNXProxy or OneShotTimer is not defined",
				{ fn = "control4-utils.knx.GroupADdress HookIntoOnDriverLateInit" }
			)
			return
		end

		KNXProxy:SendToProxy("CLEAR_GROUP_ITEMS", { DEVICE_ID = C4:GetDeviceID() })

		OneShotTimer.Add(3000, function()
			for _, g in pairs(watchedRegistry) do
				KNXProxy:SendToProxy("ADD_GROUP_ITEM", {
					GROUP_ADDRESS = g.GA,
					DEVICE_ID = C4:GetDeviceID(),
					PROPERTY = g.Name,
					DATA_POINT_TYPE = g.DPT,
				})
			end
		end, "GroupAddressAddGroupItemsToKnx")
	end)

	HookIntoExecuteCommand(function(strCommand, tParams)
		if not Trim then
			Logger.Error(
				"Trim function is not defined",
				{ fn = "control4-utils.knx.GroupADdress HookIntoExecuteCommand" }
			)
			return
		end

		if strCommand ~= "DATA_FROM_KNX" then
			return
		end

		local groupAddress = Trim(tParams["GROUP_ADDRESS"])
		local value = tonumber(tParams["VALUE"])

		if groupAddress == "" or not value then
			---@type string|number?
			local val = value
			if not val then
				val = "<NIL>"
			end

			RemoteLogger:Error(
				"received invalid data from DATA_FROM_KNX, missing either group address or value is nil",
				{
					groupAddress = groupAddress,
					value = val,
				}
			)
			return
		end

		local ga = Addresses:GetByGA(groupAddress)

		if ga == nil then
			RemoteLogger:Error("received unknown group address from DATA_FROM_KNX", {
				groupAddress = groupAddress,
			})
			return
		end

		local prevValue = ga.Value
		ga.Value = value

		if changedRegistry[ga.GA] and prevValue ~= value then
			changedRegistry[ga.GA](ga, value, prevValue)
		end
	end)

	return class
end)()
