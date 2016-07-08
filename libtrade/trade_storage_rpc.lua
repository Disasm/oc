local rpc = require("libs/rpc3")
local hosts = require("hosts")
local connection = rpc.connect(hosts.storage)

local storage = connection.trade_api

return storage
