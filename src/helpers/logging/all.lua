local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "Logger")
require(dirRequire .. "RemoteLogger")
