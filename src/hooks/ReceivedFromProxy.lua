---@alias C3CReceivedFromProxyCallback fun(idBinding: number, strCommand: string, tParams: table)
do
    if not C3C then
		print("Control4Utils: ERROR LOADING src.hooks.ReceivedFromProxy, src/base.lua must be required first")
		return
	end

	-- Stores global hook if already defined
	local prevHook

    ---@type C3CReceivedFromProxyCallback[]
    local hooks = {}

    ---@param callback C3CReceivedFromProxyCallback
    C3C.HookIntoReceivedFromProxy = function(callback)
        table.insert(hooks, callback)
    end

	---@param idBinding number
	---@param strCommand string
    ---@param tParams table
	prevHook, ReceivedFromProxy = ReceivedFromProxy or function() end, function(idBinding, strCommand, tParams)
        for _, callback in pairs(hooks) do
            callback(idBinding, strCommand, tParams)
        end

        prevHook(idBinding, strCommand, tParams)
    end
end
