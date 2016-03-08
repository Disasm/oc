local emulator = require("emulator")

local api = {}
if not emulator then
  local rpc = require("rpc")
  local hosts = require("hosts")

  api = rpc.connect(hosts.robot, 5, 1)
else
  local file_serialization = require("file_serialization")

  function api.startGathering()
  end

  function api.stopGathering()
  end

  function api.dropAll()
  end

  function api.getSample()
    local d = file_serialization.load("/sample.txt")
    if type(d) == "table" then
      return d
    end
  end
end

return api
