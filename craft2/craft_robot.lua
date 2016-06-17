local rpc = require("libs/rpc3")
local robot = require("robot")
local component = require("component")
local crafting = component.crafting
local ic = component.inventory_controller
local sides = require("sides")

robot.select(16)

local slotMap = {1, 2, 3, 5, 6, 7, 9, 10, 11 }

local input_side = sides.up
local output_side = sides.front
local drop_slots_count = ic.getInventorySize(output_side)
local own_slots_count = robot.inventorySize()
local counter = 0

function craft(n)
  counter = counter + 1
  print(string.format("Craft #%d", counter))
  print("Sucking")
  for i=1,9 do
    if ic.getStackInSlot(input_side, i + 2) then
      robot.select(slotMap[i])
      ic.suckFromSlot(input_side, i + 2)
    end
  end
  robot.select(16)
  print("Crafting")
  local result = crafting.craft(n)
  if not result then
    print("Crafting error")
  end
  print("Dropping")
  for i=1,own_slots_count do
    if robot.count(i) > 0 then
      robot.select(i)
      for j = 1, drop_slots_count do
        ic.dropIntoSlot(output_side, j)
        if robot.count(i) == 0 then break end
      end
      if robot.count(i) ~= 0 then
        error("Crafter: drop failed")
      end
    end
  end
  print("Done")
  return result
end

rpc.bind({ craft = craft })
