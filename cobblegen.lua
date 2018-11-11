local robot = require("robot")
local computer = require("computer")
local event = require("event")
local component = require("component")
local sides = require("sides")
local ic = component.inventory_controller
local crafting = component.crafting

local down_inventory_size = ic.getInventorySize(sides.down)
local function do_craft()
  while true do
    for i = 1, 11 do
      if i ~= 4 and i ~= 8 then
        for j = 1, down_inventory_size do
          if robot.count(i) == 64 then
            break
          end
          robot.select(i)
          ic.suckFromSlot(sides.down, j, 64 - robot.count(i))
        end
        if robot.count(i) < 64 then
          return
        end
      end
    end
    robot.select(16)
    crafting.craft(64)
    robot.turnLeft()
    if not robot.drop() then
      print("drop failed")
      return
    end
    robot.turnRight()
  end
end

local function charge()
  local mfe_charge_slot = 1
  robot.select(4)
  ic.equip()
  ic.dropIntoSlot(sides.up, mfe_charge_slot)
  local charge = ic.getStackInSlot(sides.up, mfe_charge_slot).charge
  while true do
    do_craft()
    local new_charge = ic.getStackInSlot(sides.up, mfe_charge_slot).charge
    if new_charge == charge then
      break
    end
    charge = new_charge
  end
  robot.select(4)
  ic.suckFromSlot(sides.up, mfe_charge_slot)
  ic.equip()
end

do_craft()
while true do
  if not robot.use() then
    charge()
  end
  while not robot.detect() do
  end
end
