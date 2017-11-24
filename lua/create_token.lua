local redis = require "resty.redis"
local red = redis:new()

red:set_timeout(1000)

local string.random = require "string.random"
