---@alias LoggingFn fun(s: string): nil

do
	-- Store locally, overridden at the end of the script
	local globalOverrides = {
		OnPropertyChanged = OnPropertyChanged or function() end,
		OnDriverLateInit = OnDriverLateInit or function() end,
	}

	Logger = (function()
		local class = {}
		class.__index = class

		local logLevelPropName = "Log Level"
		local logModePropName = "Log Mode"
		local logLevels = ""
		local logModes = ""
		local defaultLogLevel = "Error"
		local defaultLogMode = "Off"

		class.Levels = {
			["Debug"] = "debug",
			["Error"] = "error",
			["Info"] = "info",
		}

		for _, k in pairs(class.Levels) do
			logLevels = logLevels .. k .. ","
		end

		logLevels = logLevels:sub(1, -2)

		class.Mode = {
			["Print"] = "print",
			["Log"] = "log",
			["Print and Log"] = "printlog",
			["Off"] = "off",
		}

		for _, k in pairs(class.Mode) do
			logModes = logModes .. k .. ","
		end

		logModes = logModes:sub(1, -2)

		-- The following functions are helpers for disabling
		-- and enabling logging based on mode and log level
		local noop = function(s) end

		-- Log function is set using the logging mode, to either print
		-- or error log into the director
		local logFn = noop

		-- Print function is set when log leve changes, it internally uses the logFn set by logging mode
		local printFn = function(s)
			logFn(s)
		end

		---@type {debug: LoggingFn, error: LoggingFn, info: LoggingFn}
		local log = {
			debug = noop,
			error = noop,
			info = noop,
		}

		--- Sets the logging verbosity
		---@param level "Debug"|"Info"
		function class.SetLogLevel(level)
			if class.Levels[level] == nil then
				print(string.format("Invalid logging level requested: %s", level))
				return
			end

			print("Setting log level:" .. level)
			if level == "Debug" then
				log.debug = printFn
				log.info = printFn
				log.error = printFn
			elseif level == "Error" then
				log.debug = noop
				log.info = noop
				log.error = printFn
			elseif level == "Info" then
				log.debug = noop
				log.info = printFn
				log.error = printFn
			end
		end

		--- Sets the target where logging will be sent
		---@param mode "Print"|"Log"|"Print and Log"|"Off"
		function class.SetLoggingMode(mode)
			if class.Mode[mode] == nil then
				print(string.format("Invalid logging mode requested: %s", mode))
				return
			end
			print("Setting log mode:" .. mode)
			if mode == "Off" then
				logFn = noop
			elseif mode == "Print" then
				logFn = function(s)
					print(s)
				end
			elseif mode == "Log" then
				logFn = function(s)
					C4:ErrorLog(s)
				end
			elseif mode == "Print and Log" then
				logFn = function(s)
					print(s)
					C4:ErrorLog(s)
				end
			end
		end

		---Sends the message to a debug channel
		---@param s string
		---@param ctx table|nil
		function class.Debug(s, ctx)
			if ctx ~= nil then
				log.debug("[DEBUG] > " .. s .. " | CTX: " .. Logger.FormatParams(ctx))
			else
				log.debug("[DEBUG] > " .. s)
			end

			if RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				RemoteLogger:Debug(s, remoteCtx)
			end
		end

		---Sends the message to an error channel
		---@param s string
		---@param ctx table|nil
		function class.Error(s, ctx)
			if ctx ~= nil then
				log.error("[ERROR] > " .. s .. " | CTX: " .. Logger.FormatParams(ctx))
			else
				log.error("[ERROR] > " .. s)
			end

			if RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				RemoteLogger:Error(s, remoteCtx)
			end
		end

		---Sends the message to an info channel
		---@param s string
		---@param ctx table|nil
		function class.Info(s, ctx)
			if ctx ~= nil then
				log.info("[ INFO] > " .. s .. " | CTX: " .. Logger.FormatParams(ctx))
			else
				log.info("[ INFO] > " .. s)
			end

			if RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				RemoteLogger:Info(s, remoteCtx)
			end
		end

		---Formats a table into a string
		---@param tParams table
		---@return string
		function class.FormatParams(tParams)
			tParams = tParams or {}
			local out = {}
			for k, v in pairs(tParams) do
				if type(v) == "string" then
					local vString = tostring(v)
					if vString:len() > 1000 then
						table.insert(out, k .. ': "' .. vString:sub(1, 1000) .. ' [...]"')
					else
						table.insert(out, k .. ': "' .. vString .. '"')
					end
				elseif type(v) == "table" then
					table.insert(out, k .. ": [" .. class.FormatParams(v) .. "]")
				else
					table.insert(out, k .. ": " .. tostring(v):sub(1, 100))
				end
			end
			return table.concat(out, ", ")
		end

		---@param propName string
		function class:OnPropertyChanged(propName)
			if propName == logLevelPropName then
				Logger.SetLogLevel(Properties[logLevelPropName])
			elseif propName == logModePropName then
				Logger.SetLoggingMode(Properties[logModePropName])
			end
		end

		function class:OnDriverLateInit()
			Logger.SetLogLevel(Properties[logLevelPropName])
			Logger.SetLoggingMode(Properties[logModePropName])
			C4:UpdatePropertyList("Log Level", logLevels, defaultLogLevel)
			C4:UpdatePropertyList("Log Mode", logModes, defaultLogMode)
		end

		return class
	end)()

	OnDriverLateInit = function()
		Logger:OnDriverLateInit()
		globalOverrides.OnDriverLateInit()
	end

	OnPropertyChanged = function(propName)
		Logger:OnPropertyChanged(propName)
		globalOverrides.OnPropertyChanged(propName)
	end
end