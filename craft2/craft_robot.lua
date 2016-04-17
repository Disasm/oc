local rpc = require("libs/rpc3")
local robot = require("robot")
local component = require("component")
local craft = component.crafting.craft
local ic = component.inventory_controller
local sides = require("sides")

robot.select(16)

local slotMap = {1, 2, 3, 5, 6, 7, 9, 10, 11 }

function craft(n)
  for i=1,9 do
    if ic.getStackInSlot(sides.down, i + 2) then
      robot.select(slotMap[i])
      ic.suckFromSlot(sides.down, i + 2)
    end
  end
  robot.select(16)
  local r = table.pack(craft(n))
  for i=1,16 do
    if robot.count(i) > 0 then
      robot.select(i)
      robot.drop()
    end
  end
  return table.unpack(r)
end

rpc.bind({ craft = craft })
