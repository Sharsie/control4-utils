---@alias Context table<string,string|number|boolean>
do
	C3C.Context = {
		---@param parentCtx Context
		---@param stack string?
		---@return Context
		Attach = function(parentCtx, stack)
            local ctx = {}
            for k, v in pairs(parentCtx) do
                if type(k) == "string" then
                    local vt = type(v)
                    if vt == "string" or vt == "number" or vt == "boolean" then
                        ctx[k] = v
                    end
                end
            end

			if not ctx.start then
				ctx.start = C4:GetTime()
			end

			if not ctx.stack then
				ctx.stack = ""
			elseif stack and stack ~= "" and type(ctx.stack) == "string" then
				ctx.stack = ctx.stack .. " -> " .. stack
			end

            return ctx
		end,
	}
end
