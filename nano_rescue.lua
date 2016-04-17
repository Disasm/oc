local nanomachine = require("nanomachine")
local machines = nanomachine.getList()

while true do
  for _, machine in pairs(machines) do
    print("Machine: "..machine.address)
    local count = machine.getTotalInputCount()
    for i = 1, count do
      machine.setInputFast(i, false)
    end
  end
end
