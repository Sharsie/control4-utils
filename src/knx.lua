local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "knx.all")
