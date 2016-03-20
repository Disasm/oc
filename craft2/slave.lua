
local rpc = require("libs/rpc")
local transposers_interface = require("craft2/transposers_interface")

return { run = function() 
  rpc.bind(transposers_interface)
  print("Craft 2 Slave RPC interface is now available.")
  return
end }
