---@alias ExecuteCommandCallback fun(strCommand: string, tParams: table)
do
	-- Stores global hook if already defined
	local prevHook

    ---@type ExecuteCommandCallback[]
    local hooks = {}

    ---@param callback ExecuteCommandCallback
    HookIntoExecuteCommand = function(callback)
        table.insert(hooks, callback)
    end

	---@param strCommand string
    ---@table
	prevHook, ExecuteCommand = ExecuteCommand or function() end, function(strCommand, tParams)
        for _, callback in pairs(hooks) do
            callback(strCommand, tParams)
        end

        prevHook(strCommand, tParams)
    end
end
