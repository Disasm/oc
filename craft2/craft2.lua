print("Welcome to Craft 2")
print("")

local config = require("craft2/config")
local rpc = require("libs/rpc")
local hosts = require("hosts")

local transposers_interface = require("craft2/transposers_interface")


if config.role == "slave" then 
  rpc.bind(transposers_interface)
  print("Craft 2 Slave RPC interface is now available.")
  return
elseif config.role == "master" then 
  local transposers_interfaces = {}
  table.insert(transposers_interfaces, transposers_interface)
  for i, host in ipairs(config.slaves) do 
    local v = rpc.connect(hosts[host])
    table.insert(transposers_interfaces, v)
  end
   
  cmd_args = {...}
  if #cmd_args > 0 then
    local command = cmd_args[1]
    if command == "rebuild" then 
      print("Rebuilding topology...")
      print("Found transposers: ")
      for i, trans in ipairs(transposers_interfaces) do 
        for j, t in ipairs(trans.get_transposers()) do 
          print(string.format("%s (host: %d)", t, i))
        end
      end
    else 
      error("Unknown command")
    end 
    return
  end
  print("Nothing to do here yet!")
  return
else 
  error("Invalid role in config")
end




