---@alias C3CKnxGenericGroupAddressShape<T> { DPT: C3CKnxDPT, GA: string, Name: T, Value: number | nil }

do
	if not C3C then
		print("Control4Utils: ERROR LOADING src.knx.GroupAddress, src/base.lua must be required first")
		return
	end

	---@param name C3CKnxGroupAddressName
	---@param ga string
	---@param dpt C3CKnxDPT
	C3C.KnxGroupAddress = function(name, ga, dpt)
		---@class GroupAddress
		---@field DPT C3CKnxDPT
		---@field GA string
		---@field Name C3CKnxGroupAddressName
		---@field Value number|nil
		local class = {
			DPT = dpt,
			GA = ga,
			Name = name,
			Value = nil,
		}

		local responding = false

		---@param v number
		function class:Send(v)
			class.Value = v
			C3C.KnxProxy.Send(class.DPT, class.GA, class.Value)
		end

		function class:RespondToRead()
			responding = true
		end

		function class:isResponding()
			return responding
		end

		return class
	end

	---@type {[C3CKnxGroupAddressName]: GroupAddress}
	local namedRegistry = {}
	---@type {[string]: GroupAddress|nil}
	local addressedRegistry = {}

	---@type {[string]: GroupAddress}
	local watchedRegistry = {}

	---@type {[C3CKnxGroupAddressName]: nil|fun(current: GroupAddress, ctx: { newVal: number, prevVal: number?})[]}
	local onChangedRegistry = {}

	---@type {[C3CKnxGroupAddressName]: nil|fun(current: GroupAddress, ctx: { newVal: number, prevVal: number?})[]}
	local onReceiveRegistry = {}

	for _, v in pairs(C3CKnxCreateGroupAddresses()) do
		addressedRegistry[v.GA] = v
		namedRegistry[v.Name] = v
	end

	C3C.KnxAddresses = {
		---Get GroupAddress by name
		---@param n C3CKnxGroupAddressName
		---@return GroupAddress
		Get = function(n)
			if namedRegistry[n] == nil then
				C3C.Logger.Error(
					"error accessing non existing group address name, this should never happen...never",
					{ name = n }
				)
			end
			return namedRegistry[n]
		end,

		---Get GroupAddress by address if defined
		---@param ga string
		---@return GroupAddress|nil
		GetByGA = function(ga)
			return addressedRegistry[ga]
		end,

		---@param n C3CKnxGroupAddressName
		---@param onValueReceive nil|fun(current: GroupAddress, newVal: number, prevVal: number?)
		---@param onValueChange nil|fun(current: GroupAddress, newVal: number, prevVal: number?)
		Watch = function(n, onValueReceive, onValueChange)
			if namedRegistry[n] == nil then
				C3C.Logger.Error(
					"error accessing non existing group address name to Listen, this should never happen...never",
					{ name = n }
				)
			end

			local addr = namedRegistry[n]
			watchedRegistry[addr.GA] = addr

			if onValueReceive ~= nil then
				if onReceiveRegistry[addr.GA] == nil then
					onReceiveRegistry[addr.GA] = {}
				end

				table.insert(onReceiveRegistry[addr.GA], onValueReceive)
			end

			if onValueChange ~= nil then
				if onChangedRegistry[addr.GA] == nil then
					onChangedRegistry[addr.GA] = {}
				end

				table.insert(onChangedRegistry[addr.GA], onValueChange)
			end
		end,
	}

	C3C.HookIntoOnDriverLateInit(function()
		if not C3C.KnxProxy or not C3C.OneShotTimer then
			C3C.Logger.Error(
				"C3C.KnxProxy or C3C.OneShotTimer is not defined",
				{ fn = "control4-utils.knx.GroupADdress HookIntoOnDriverLateInit" }
			)
			return
		end

		C3C.KnxProxy.ClearGroupAddresses()

		C3C.OneShotTimer.Add(3000, function()
			for _, g in pairs(watchedRegistry) do
				C3C.KnxProxy.AddGroupAddress(g)
			end
		end, "GroupAddressAddGroupItemsToKnx")
	end)

	C3C.HookIntoExecuteCommand(function(strCommand, tParams)
		if not Trim then
			C3C.Logger.Error(
				"Trim function is not defined",
				{ fn = "control4-utils.knx.GroupADdress HookIntoExecuteCommand" }
			)
			return
		end

		if strCommand == "KNX_READ_REQUEST" then
			local ga = Trim(tParams["GROUP_ADDRESS"])
			if ga == "" then
				C3C.Logger.Error("received invalid group address from KNX_READ_REQUEST", {
					groupAddress = ga,
				})
				return
			end

			local addr = C3C.KnxAddresses.GetByGA(ga)
			if addr ~= nil and addr.Value ~= nil and addr:isResponding() then
				addr:Send(addr.Value)
			end
		end

		if strCommand ~= "DATA_FROM_KNX" then
			return
		end

		local groupAddress = Trim(tParams["GROUP_ADDRESS"])

		if groupAddress == "" then
			C3C.Logger.Error("received empty group address from DATA_FROM_KNX", {
				params = tParams
			})
			return
		end

		local addr = C3C.KnxAddresses.GetByGA(groupAddress)

		if addr == nil then
			C3C.Logger.Error("received unknown group address from DATA_FROM_KNX", {
				groupAddress = groupAddress,
			})
			return
		end

		local value = nil

		if addr.DPT == "DPT_3" then
			local value = tonumber(tParams["DIRECTION"])
		else
			value = tonumber(tParams["VALUE"])
		end

		if value == nil then
			C3C.Logger.Error("received invalid data from DATA_FROM_KNX, value is nil", {
				groupAddress = groupAddress,
				params = tParams,
			})
			return
		end

		local prevValue = addr.Value
		addr.Value = value

		if onReceiveRegistry[addr.GA] then
			for _, callback in pairs(onReceiveRegistry[addr.GA]) do
				callback(addr, { newVal = value, prevVal = prevValue })
			end
		end

		if onChangedRegistry[addr.GA] and prevValue ~= value then
			for _, callback in pairs(onChangedRegistry[addr.GA]) do
				callback(addr, { newVal = value, prevVal = prevValue })
			end
		end
	end)
end
