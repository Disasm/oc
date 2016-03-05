local event = require("event")
local computer = require("computer")

function on_motion(e, addr, x, y, z, name)
  print("Detected: " .. name)
end


event.listen("motion", on_motion)
