local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "OnDriverLateInit")
require(dirRequire .. "OnPropertyChanged")
