KNXProxy = (function()
	local class = {
        -- TODO Binding  + autobinding
		binding = 0,
	}

	--- @param strCommand string
	--- @param tParams table
	function class:SendToProxy(strCommand, tParams)
        local ctx = tParams
        ctx.knxCommand = strCommand

		Logger.Debug("Sending data to KNX", ctx)

		C4:SendToProxy(self.binding, strCommand, tParams)
	end

	--- @param dpt DPT
	--- @param groupAddress string
	--- @param value number
	function class:SendToKNX(dpt, groupAddress, value)
		local tParams = {}
		tParams.DATA_POINT_TYPE = dpt
		tParams.GROUP_ADDRESS = groupAddress
		tParams.VALUE = value

		self:SendToProxy("SEND_TO_KNX", tParams)
	end

	return class
end)()
