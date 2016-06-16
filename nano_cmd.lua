
function usage()
  print("Usage:")
  print("  nano_cmd info")
  print("  nano_cmd clear (all off)")
  print("  nano_cmd get [X]")
  print("  nano_cmd on X,Y,Z (set to on)")
  print("  nano_cmd off X,Y,Z (set to off)")
  print("  nano_cmd con X,Y,Z (clear and set)")
  print("  nano_cmd sw X,Y,Z A,B,C (unset X,Y,Z and set A,B,C)")
end


args = {...}
if #args == 0 then
  usage()
  return
end


local nanomachine = require("nanomachine")
local machine = nanomachine.find()
if machine == nil then
  print("nanomachine is not found")
  return
end
local input_count = machine.getTotalInputCount()


function clear()
  for i = 1, input_count do
    print(machine.setInput(i, false))
  end
end
function set(cmd, val)
  for i in string.gmatch(cmd, "%d+") do
    print(machine.setInput(tonumber(i), val))
  end
end

if args[1] == "info" then
  print("Player name is " .. machine.getName())
  print("TotalInputCount: " .. input_count)
  print("SafeActiveInputs: " .. machine.getSafeActiveInputs())
  print("MaxActiveInputs: " .. machine.getMaxActiveInputs())
elseif args[1] == "get" then
  if args[2] then
    print(machine.getInput(tonumber(args[2])))
  else
    for i = 1, input_count do
      print(machine.getInput(i))
    end
  end
elseif args[1] == "on" then
  set(args[2], true)
elseif args[1] == "off" then
  set(args[2], false)
elseif args[1] == "clear" then
  clear()
elseif args[1] == "con" then
  clear()
  set(args[2], true)
elseif args[1] == "sw" then
  set(args[2], false)
  set(args[3], true)
else
  usage()
end
