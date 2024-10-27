---@alias OnDriverLateInitCallback fun(strDIT: string)
do
	-- Stores global hook if already defined
	local prevHook

    ---@type OnDriverLateInitCallback[]
    local hooks = {}

    ---@param callback OnDriverLateInitCallback
    HookIntoOnDriverLateInit = function(callback)
        table.insert(hooks, callback)
    end

	---@param strDIT string
	prevHook, OnDriverLateInit = OnDriverLateInit or function() end, function(strDIT)
        for _, callback in pairs(hooks) do
            callback(strDIT)
        end

        prevHook(strDIT)
    end
end
