local component = require("component")
local computer = component.computer

return { isEmulator = (computer.isEmulator == true) }
