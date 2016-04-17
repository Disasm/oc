
local rpc = require("libs/rpc3")

return function()
  rpc.bind({
    transposers_interface = require("craft2/transposers_interface"),
    item_database = require("craft2/item_db")()
  })
  print("Craft 2 Slave RPC interface is now available.")
end
