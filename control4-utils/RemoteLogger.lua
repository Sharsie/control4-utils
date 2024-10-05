---@alias LOG_LEVEL
---|"DEBUG"
---|"INFO"
---|"WARN"
---|"ERROR"

---@alias LOG_CONTEXT table<string,string|boolean|number>

--- time_of_execution in milliseconds, use C4:GetTime()
---@alias LOGGER_PAYLOAD { level: LOG_LEVEL, message: string, service_identifier: string, time_of_execution: number, [string]: string|number|boolean }

---@alias LOG_FN fun(class: RemoteLogger, message: string, context: LOG_CONTEXT): boolean

local LOGGER_CONNECTION_BINDING_ID = 100

C4:AddDynamicBinding(LOGGER_CONNECTION_BINDING_ID, "CONTROL", false, "Logger", "c3c-remote-logger", false, true)

---@class RemoteLogger
---@field Setup fun(class: RemoteLogger, service_identifier: string): nil
---@field Debug LOG_FN
---@field Info LOG_FN
---@field Warn LOG_FN
---@field Error LOG_FN
RemoteLogger = (function()
	local class = {}

	-- service identifier
	---@type string|nil
	local SI = nil

	---@param level LOG_LEVEL
	---@param message string
	---@param ctx LOG_CONTEXT
	---@return boolean
	local sendLog = function(level, message, ctx)
		if SI == nil then
			Logger.Error("Tried to remote log without setting up service identifier, call RemoteLogger:Setup first")
			return false
		end

		---@type LOGGER_PAYLOAD
		local payload = {
            level = "ERROR",
            message = "",
			service_identifier = SI,
			time_of_execution = C4:GetTime(),
		}

        if ctx.level ~= nil or ctx.message ~= nil or ctx.service_identifier ~= nil or ctx.time_of_execution ~= nil then
            Logger.Error("Tried to remote log data with reserved context keys", { message = message, level = level, ctx = ctx })

            payload.level = "ERROR"
            payload.message = "Service tried to remote log, but used reserved keyword in the context value"

		    C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_LOG", payload, "NOTIFY")
            return false
        end

        payload.level = level
        payload.message = message

        for k, v in pairs(ctx) do
            local vType = type(v);
            if vType ~= "nil" and vType ~= "number" and vType ~= "string" and vType ~= "boolean" then
                payload[k] = "invalid field value type " .. vType
            else
                payload[k] = v
            end
        end

		C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_LOG", payload, "NOTIFY")

		return true
	end

	---@param service_identifier string
	function class:Setup(service_identifier)
		SI = service_identifier
	end

	---@type LOG_FN
	function class:Debug(message, ctx)
		return sendLog("DEBUG", message, ctx)
	end

	---@type LOG_FN
	function class:Info(message, ctx)
		return sendLog("INFO", message, ctx)
	end

	---@type LOG_FN
	function class:Warn(message, ctx)
		return sendLog("WARN", message, ctx)
	end

	---@type LOG_FN
	function class:Error(message, ctx)
		return sendLog("ERROR", message, ctx)
	end

	return class
end)()
