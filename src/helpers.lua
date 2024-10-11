local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "helpers.all")
