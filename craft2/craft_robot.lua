local rpc2 = require("libs/rpc2")
local robot = require("robot")
local component = require("component")
local craft = component.crafting.craft
local ic = component.inventory_controller
local sides = require("sides")

robot.select(16)

api = {}

local slotMap = {1, 2, 3, 5, 6, 7, 9, 10, 11}
function api.craft(n)
  for i=1,9 do
    robot.select(slotMap[i])
    ic.suckFromSlot(sides.down, i + 2)
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

local objects = { crafter = api }

rpc2.bind(objects)
