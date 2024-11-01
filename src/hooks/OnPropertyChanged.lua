---@alias C3COnPropertyChangedCallback fun(strProperty: string)
do
    if not C3C then
		print("Control4Utils: ERROR LOADING src.hooks.OnPropertyChanged, src/base.lua must be required first")
		return
	end

	-- Stores global hook if already defined
	local prevHook

    ---@type C3COnPropertyChangedCallback[]
    local hooks = {}

    ---@param callback C3COnPropertyChangedCallback
    C3C.HookIntoOnPropertyChanged = function(callback)
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
