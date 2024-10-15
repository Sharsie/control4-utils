local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "logging.all")
require(dirRequire .. "strings.all")
require(dirRequire .. "timers.all")
