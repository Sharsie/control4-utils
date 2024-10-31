local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "context")
