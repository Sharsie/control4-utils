---@alias C3CExecuteCommandCallback fun(strCommand: string, tParams: table)
do
    if not C3C then
		print("Control4Utils: ERROR LOADING src.hooks.ExecuteCommand, src/base.lua must be required first")
		return
	end

	-- Stores global hook if already defined
	local prevHook

    ---@type C3CExecuteCommandCallback[]
    local hooks = {}

    ---@param callback C3CExecuteCommandCallback
    C3C.HookIntoExecuteCommand = function(callback)
        table.insert(hooks, callback)
    end

	---@param strCommand string
    ---@param tParams table
	prevHook, ExecuteCommand = ExecuteCommand or function() end, function(strCommand, tParams)
        for _, callback in pairs(hooks) do
            callback(strCommand, tParams)
        end

        prevHook(strCommand, tParams)
    end
end
