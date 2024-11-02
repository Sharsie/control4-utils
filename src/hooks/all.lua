local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "ExecuteCommand")
require(dirRequire .. "OnDriverLateInit")
require(dirRequire .. "OnPropertyChanged")
require(dirRequire .. "ReceivedFromProxy")
