local event = require("event")
local computer = require("computer")
local real_time = require("real_time")
local filesystem = require("filesystem")

function on_motion(e, addr, x, y, z, name)
  if name == "Riateche" or name == "disasm" then 
    return 
  end
  local f = filesystem.open("/visits.log", "a")
  if f then
    f:write(string.format("[%s] Detected: %s\n", real_time.get_string(), name))
    f:close()
  end
end

event.listen("motion", on_motion)
