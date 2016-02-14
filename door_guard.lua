local filesystem = require("filesystem")
local event = require("event")
local component = require("component")
local redstone = component.redstone
local sides = require("sides")
local os = require("os")
local computer = require("computer")

local logFile = filesystem.open("/log.txt", "a");

local debug = function(s)
    print(s)
    logFile:write(s)
    logFile:write("\n")
end


while true do
  _, _, _, _, _, player = event.pull("motion")
  if player == "disasm" or player == "Riateche" then 
    print("Welcome, "..player.."!")    
    redstone.setOutput(sides.up, 0)
    computer.beep(400, 0.2)
    os.sleep(1)
    redstone.setOutput(sides.up, 15)
  else 
    if player ~= nil then 
        debug("Detected: "..player)
        computer.beep(100, 1)
    end
  end
end
