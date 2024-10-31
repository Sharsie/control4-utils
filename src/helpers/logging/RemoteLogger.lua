---@alias LOG_LEVEL
---|"DEBUG"
---|"INFO"
---|"WARN"
---|"ERROR"

---@alias REMOTE_LOGGER_PAYLOAD table<string,string|boolean|number>

--- time_of_execution in milliseconds, use C4:GetTime()
---@alias LOGGER_PAYLOAD { level: LOG_LEVEL, message: string, service_identifier: string, time_of_execution: number, [string]: string|number|boolean }
---@alias METRIC_VALUE string|number|boolean
---@alias METRIC_PAYLOAD { metric: string, service_identifier: string, time_of_execution: number, [string]: METRIC_VALUE }

---@alias LOG_FN fun(class: RemoteLogger, message: string, context: REMOTE_LOGGER_PAYLOAD): boolean
---@alias METRIC_FN fun(class: RemoteLogger, metric: string, context: REMOTE_LOGGER_PAYLOAD): boolean

REMOTE_LOGGER_CAST_KEY_PREFIX = "_cast_"
REMOTE_LOGGER_TAG_KEY_PREFIX = "_tag_"
REMOTE_LOGGER_FIELD_KEY_PREFIX = "_field_"

do
	local LOGGER_CONNECTION_BINDING_ID = 100

	---@class RemoteLogger
	---@field Setup fun(class: RemoteLogger, service_identifier: string): nil
	---@field DecodeUntypedPayload fun(class: RemoteLogger, payload: table<string,string>): REMOTE_LOGGER_PAYLOAD
	---@field DecodeMetrics fun(class: RemoteLogger, payload: table<string,string>): {fields: table<string,METRIC_VALUE>, tags: table<string,METRIC_VALUE>}
	---@field Debug LOG_FN
	---@field Info LOG_FN
	---@field Warn LOG_FN
	---@field Error LOG_FN
	---@field AddMetric METRIC_FN
	C3C.RemoteLogger = (function()
		local class = {}

		-- service identifier
		---@type string|nil
		local SI = nil

		---@param payload REMOTE_LOGGER_PAYLOAD
		---@return table<string,string>
		local encodeTypedPayload = function(payload)
			---@type table<string,string>
			local output = {}
			local errorCtx = {
				level = "ERROR",
				message = "Service tried to encode data for remote logger",
			}
			local error = false

			for k, v in pairs(payload) do
				if k:sub(1, REMOTE_LOGGER_CAST_KEY_PREFIX:len()) == REMOTE_LOGGER_CAST_KEY_PREFIX then
					error = true
					errorCtx["offending_key_" .. k] = k
				end

				local vType = type(v)
				if vType ~= "nil" and vType ~= "number" and vType ~= "string" and vType ~= "boolean" then
					output[k] = "invalid field value type " .. vType
				else
					output[k] = tostring(v)
					if vType ~= "string" then
						output[REMOTE_LOGGER_CAST_KEY_PREFIX .. k] = vType
					end
				end
			end

			if error then
				Logger.Error("Tried to remote log data with reserved context keys", errorCtx)
			end

			return output
		end

		---@param tags table<string,METRIC_VALUE>
		---@param fields table<string,METRIC_VALUE>
		---@return table<string,METRIC_VALUE>
		local encodeMetrics = function(tags, fields)
			---@type table<string,any>
			local output = {}

			for k, v in pairs(tags) do
				output[REMOTE_LOGGER_TAG_KEY_PREFIX .. k] = v
			end

			for k, v in pairs(fields) do
				output[REMOTE_LOGGER_FIELD_KEY_PREFIX .. k] = v
			end

			return output
		end

		---@param level LOG_LEVEL
		---@param message string
		---@param ctx REMOTE_LOGGER_PAYLOAD
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
				Logger.Error(
					"Tried to remote log data with reserved context keys",
					{ message = message, level = level, ctx = ctx }
				)

				payload.level = "ERROR"
				payload.message = "Service tried to remote log, but used reserved keyword in the context value"

				C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_LOG", payload, "NOTIFY")
				return false
			end

			payload.level = level
			payload.message = message

			for k, v in pairs(ctx) do
				payload[k] = v
			end

			C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_LOG", encodeTypedPayload(payload), "NOTIFY")

			return true
		end

		---@param metric string
		---@param tags table<string,METRIC_VALUE>
		---@param fields table<string,METRIC_VALUE>
		---@return boolean
		local sendMetric = function(metric, tags, fields)
			if SI == nil then
				Logger.Error(
					"Tried to add remote metric without setting up service identifier, call RemoteLogger:Setup first"
				)
				return false
			end

			---@type METRIC_PAYLOAD
			local payload = {
				metric = metric,
				service_identifier = SI,
				time_of_execution = C4:GetTime(),
			}

			if tags.service_identifier ~= nil or tags.time_of_execution ~= nil then
				Logger.Error("Tried to add remote metric data with reserved tag keywords", { metric = metric, tags = tags })

				payload.level = "ERROR"
				payload.message = "Service tried to add remote metric, but used reserved tag keywords"

				C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_LOG", payload, "NOTIFY")
				return false
			end

			payload.metric = metric

			for k, v in encodeMetrics(tags, fields) do
				payload[k] = v
			end

			C4:SendToProxy(LOGGER_CONNECTION_BINDING_ID, "INSERT_METRIC", encodeTypedPayload(payload), "NOTIFY")

			return true
		end

		---@param payload table<string,string>
		---@return REMOTE_LOGGER_PAYLOAD
		function class:DecodeUntypedPayload(payload)
			---@type REMOTE_LOGGER_PAYLOAD
			local output = {}

			for k, v in pairs(payload) do
				if k:sub(1, REMOTE_LOGGER_CAST_KEY_PREFIX:len()) ~= REMOTE_LOGGER_CAST_KEY_PREFIX then
					local castValue = payload[REMOTE_LOGGER_CAST_KEY_PREFIX .. k]
					if castValue == "" or castValue == nil then
						-- performance
						output[k] = v
					elseif castValue == "number" then
						local numVal = tonumber(v)
						if type(numVal) == "number" then
							output[k] = numVal
						else
							output[k] = v
						end
					elseif castValue == "boolean" then
						if v:lower() == "true" or v == "1" then
							output[k] = true
						else
							output[k] = false
						end
					else
						output[k] = v
					end
				end
			end

			return output
		end

		---@param payload table<string,METRIC_VALUE>
		---@return {fields: table<string,METRIC_VALUE>, tags: table<string,METRIC_VALUE>}
		function class:DecodeMetrics(payload)
			---@type {fields: table<string,METRIC_VALUE>, tags: table<string,METRIC_VALUE>}
			local output = {
				fields = {},
				tags = {},
			}

			for k, v in pairs(payload) do
				if k:sub(1, REMOTE_LOGGER_TAG_KEY_PREFIX:len()) == REMOTE_LOGGER_TAG_KEY_PREFIX then
					output.tags[k:sub(REMOTE_LOGGER_TAG_KEY_PREFIX:len() + 1)] = v
				elseif k:sub(1, REMOTE_LOGGER_FIELD_KEY_PREFIX:len()) == REMOTE_LOGGER_FIELD_KEY_PREFIX then
					output.fields[k:sub(REMOTE_LOGGER_FIELD_KEY_PREFIX:len() + 1)] = v
				end
			end

			return output
		end

		---@param service_identifier string
		function class:Setup(service_identifier)
			SI = service_identifier
			C4:AddDynamicBinding(LOGGER_CONNECTION_BINDING_ID, "CONTROL", false, "Logger", "c3c-remote-logger", false, true)
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

		-- Example fields: humidity, temperature, co2
		---@param sensorId string
		---@param location string
		---@param fields table<string,METRIC_VALUE>
		function class:AirSensorMetric(sensorId, location, fields)
			return sendMetric("air_sensor", {
				sensor_id = sensorId,
				location = location,
			}, fields)
		end

		-- Example kinds: water_level, door_open
		-- Example fields: below_threshold, open
		---@param sensorId string
		---@param kind string
		---@param fields table<string,METRIC_VALUE>
		function class:StatusMetric(sensorId, kind, fields)
			return sendMetric("air_sensor", {
				sensor_id = sensorId,
				kind = kind,
			}, fields)
		end

		-- Example fields: airflow, boost, setpoint
		---@param sensorId string
		---@param fields table<string,METRIC_VALUE>
		function class:VentilationMetric(sensorId, fields)
			return sendMetric("air_sensor", {
				sensor_id = sensorId,
			}, fields)
		end

		return class
	end)()
end
