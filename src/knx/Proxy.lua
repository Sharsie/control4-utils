do
	if not C3C then
		print("Control4Utils: ERROR LOADING src.knx.Proxy, src/base.lua must be required first")
		return
	end

	local binding = nil

	local send = function(strCommand, tParams)
		if not binding then
			C3C.Logger.Error(
				"tried to send data to knx proxy without setting up binding, call C3C.KnxProxy.Setup first",
				{
					stack = "KnxProxy.send",
				}
			)
			return false
		end

		local ctx = tParams
		ctx.knxCommand = strCommand

		C3C.Logger.Debug("sending data to KNX", ctx)

		C4:SendToProxy(binding, strCommand, tParams)
	end

	C3C.KnxProxy = {
		---@param bindingId number
		Setup = function(bindingId)
			binding = bindingId
		end,

		---@param ga GroupAddress
		AddGroupAddress = function(ga)
			send("ADD_GROUP_ITEM", {
				GROUP_ADDRESS = ga.GA,
				DEVICE_ID = C4:GetDeviceID(),
				PROPERTY = ga.Name,
				DATA_POINT_TYPE = ga.DPT,
			})
		end,

		ClearGroupAddresses = function()
			send("CLEAR_GROUP_ITEMS", { DEVICE_ID = C4:GetDeviceID() })
		end,

		---@param dpt C3CKnxDPT
		---@param groupAddress string
		---@param value number
		Send = function(dpt, groupAddress, value)
			local tParams = {}
			tParams.DATA_POINT_TYPE = dpt
			tParams.GROUP_ADDRESS = groupAddress
			tParams.VALUE = value

			send("SEND_TO_KNX", tParams)
		end,

		---@param groupAddress string
		Read = function(groupAddress)
			local tParams = {}
			tParams.GROUP_ADDRESS = groupAddress

			send("REQUEST_STATUS", tParams)
		end,
	}
end
