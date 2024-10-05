do
	-- Store locally, overridden at the end of the script
	local OneShotTimerOriginalOnDriverDestroyed = OnDriverDestroyed or function() end

	---@type table<string,C4LuaTimer>
	local timers = {}

	OneShotTimer = {
		ClearAll = function()
			for _, timer in pairs(timers) do
				timer:Cancel()
			end
			timers = {}
		end,

		OnDriverDestroyed = function()
			OneShotTimer.ClearAll()
			OneShotTimerOriginalOnDriverDestroyed()
		end,

		---@param nDelay number Numeric value in milliseconds which is the desired timer delay. This value must be greater than 0.
		---@param fCallback fun(self: C4LuaTimer, skips: number) The function to be called when the timer fires. The function signature for non-repeating timers is: function(timer)
		---@param Name string?
		Add = function(nDelay, fCallback, Name)
			local timer = C4:SetTimer(nDelay, fCallback, false)

			-- Look for name if not nil, if found, remove existing timer callback...
			if Name ~= nil then
				for k, v in pairs(timers) do
					if k == Name then
						v:Cancel()
						timers[k] = nil
					end
				end

				timers[Name] = timer
			end

		end,
	}

	OnDriverDestroyed = OneShotTimer.OnDriverDestroyed
end
