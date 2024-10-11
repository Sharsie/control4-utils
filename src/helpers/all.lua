local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "logging.all")
require(dirRequire .. "timers.all")
