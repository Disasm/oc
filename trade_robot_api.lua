local emulator = require("emulator")

local api = {}
if not emulator then
  local rpc = require("rpc")
  local hosts = require("hosts")

  api = rpc.connect(hosts.robot, 5, 1)
else
  function api.startGathering()
  end

  function api.stopGathering()
  end

  function api.dropAll()
  end

  function api.getSample()
  end
end

return api
