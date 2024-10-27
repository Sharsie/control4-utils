local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "hooks.all")
