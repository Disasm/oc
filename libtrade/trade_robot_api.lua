local emulator = require("emulator").isEmulator

local api = {}
if not emulator then
  local rpc = require("rpc3")
  local hosts = require("hosts")

  api = rpc.connect(hosts.robot, {timeout=5, retries=1})
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
