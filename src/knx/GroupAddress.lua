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

	for _, v in pairs(CreateGroupAddresses()) do
		addressedRegistry[v.GA] = v
		namedRegistry[v.Name] = v
	end

	---Get GroupAddress by name
	---@param n GROUP_ADDRESS_NAME
	---@return GroupAddress
	function class:Get(n)
		if namedRegistry[n] == nil then
			Logger.Error("error accessing non existing group address name, this should never happen...never", { name = n })
		end
		return namedRegistry[n]
	end

	---Get GroupAddress by address if defined
	---@param ga string
	---@return GroupAddress|nil
	function class:GetByGA(ga)
		return addressedRegistry[ga]
	end

	return class
end)()
