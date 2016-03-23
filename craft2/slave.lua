
local rpc = require("libs/rpc2")

return { run = function() 
  rpc.bind({
    transposers_interface = require("craft2/transposers_interface"),
    item_database = require("craft2/item_database")
  })
  print("Craft 2 Slave RPC interface is now available.")
end }
