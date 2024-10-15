local dirRequire = (...):match("(.-)[^%.%/]+$")

require(dirRequire .. "DPT")
require(dirRequire .. "gen.ADDRESSES")
require(dirRequire .. "gen.createGroupAddresses")
require(dirRequire .. "GroupAddress")
require(dirRequire .. "Proxy")
