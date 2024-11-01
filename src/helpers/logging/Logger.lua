---@alias LoggingFn fun(s: string): nil

do
	if not C3C then
		print("Control4Utils: ERROR LOADING src.helpers.logging.Logger, src/base.lua must be required first")
		return
	end

	local logLevelPropName = "Log Level"
	local logModePropName = "Log Mode"
	local logLevels = ""
	local logModes = ""
	local defaultLogLevel = "Error"
	local defaultLogMode = "Off"

	local disableRemotelogging = false

	local availableLevels = {
		["Debug"] = "debug",
		["Error"] = "error",
		["Info"] = "info",
	}

	for k, _ in pairs(availableLevels) do
		logLevels = logLevels .. k .. ","
	end

	logLevels = logLevels:sub(1, -2)

	local availableModes = {
		["Print"] = "print",
		["Log"] = "log",
		["Print and Log"] = "printlog",
		["Off"] = "off",
	}

	for k, _ in pairs(availableModes) do
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
	---@param level "Debug"|"Info"|"Error"
	local function setLogLevel(level)
		if availableLevels[level] == nil then
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
	local function setLoggingMode(mode)
		if availableModes[mode] == nil then
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

	---Formats a table into a string
	---@param tParams table
	---@return string
	local function formatParams(tParams)
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
				table.insert(out, k .. ": [" .. formatParams(v) .. "]")
			else
				table.insert(out, k .. ": " .. tostring(v):sub(1, 100))
			end
		end
		return table.concat(out, ", ")
	end

	if C3C.HookIntoOnDriverLateInit then
		C3C.HookIntoOnDriverLateInit(function()
			local logLevel = Properties[logLevelPropName]
			local logMode = Properties[logModePropName]

			if not logLevel or logLevel == "" then
				logLevel = defaultLogLevel
			end
			if not logMode or logMode == "" then
				logMode = defaultLogMode
			end

			C4:UpdatePropertyList(logLevelPropName, logLevels, logLevel)
			C4:UpdatePropertyList(logModePropName, logModes, logMode)

			setLogLevel(logLevel)
			setLoggingMode(logMode)
		end)
	else
		print("ERROR: HookIntoOnDriverLateInit is not loaded")
	end

	if C3C.HookIntoOnPropertyChanged then
		C3C.HookIntoOnPropertyChanged(function(strProperty)
			if strProperty == logLevelPropName then
				setLogLevel(Properties[logLevelPropName])
			elseif strProperty == logModePropName then
				setLoggingMode(Properties[logModePropName])
			end
		end)
	else
		print("ERROR: HookIntoOnPropertyChanged is not loaded")
	end

	C3C.Logger = {
		DisableRemoteLogging = function()
			disableRemotelogging = true
		end,

		---Sends the message to a debug channel
		---@param s string
		---@param ctx table|nil
		Debug = function(s, ctx)
			if ctx ~= nil then
				log.debug("[DEBUG] > " .. s .. " | CTX: " .. formatParams(ctx))
			else
				log.debug("[DEBUG] > " .. s)
			end

			if not disableRemotelogging and C3C.RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				C3C.RemoteLogger.Debug(s, remoteCtx)
			end
		end,

		---Sends the message to an error channel
		---@param s string
		---@param ctx table|nil
		Error = function(s, ctx)
			if ctx ~= nil then
				log.error("[ERROR] > " .. s .. " | CTX: " .. formatParams(ctx))
			else
				log.error("[ERROR] > " .. s)
			end

			if not disableRemotelogging and C3C.RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				C3C.RemoteLogger.Error(s, remoteCtx)
			end
		end,

		---Sends the message to an info channel
		---@param s string
		---@param ctx table|nil
		Info = function(s, ctx)
			if ctx ~= nil then
				log.info("[ INFO] > " .. s .. " | CTX: " .. formatParams(ctx))
			else
				log.info("[ INFO] > " .. s)
			end

			if not disableRemotelogging and C3C.RemoteLogger then
				local remoteCtx = ctx or {}
				remoteCtx.source = "Logger"
				C3C.RemoteLogger.Info(s, remoteCtx)
			end
		end,
	}
end
