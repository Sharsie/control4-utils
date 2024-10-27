---@alias OnPropertyChangedCallback fun(strProperty: string)
do
	-- Stores global hook if already defined
	local prevHook

    ---@type OnPropertyChangedCallback[]
    local hooks = {}

    ---@param callback OnPropertyChangedCallback
    HookIntoOnPropertyChanged = function(callback)
        table.insert(hooks, callback)
    end

	---@param strProperty string
	prevHook, OnPropertyChanged = OnPropertyChanged or function() end, function(strProperty)
        for _, callback in pairs(hooks) do
            callback(strProperty)
        end

        prevHook(strProperty)
    end
end
