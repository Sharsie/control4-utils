---@alias C3COnDriverLateInitCallback fun(strDIT: string)
do
	if not C3C then
		print("Control4Utils: ERROR LOADING src.hooks.OnDriverLateInit, src/base.lua must be required first")
		return
	end
	-- Stores global hook if already defined
	local prevHook

	---@type C3COnDriverLateInitCallback[]
	local hooks = {}

	---@param callback C3COnDriverLateInitCallback
	C3C.HookIntoOnDriverLateInit = function(callback)
		table.insert(hooks, callback)
	end

	prevHook, OnDriverLateInit =
		OnDriverLateInit or function() end,
		---@param strDIT string
		function(strDIT)
			for _, callback in pairs(hooks) do
				callback(strDIT)
			end

			prevHook(strDIT)
		end
end
