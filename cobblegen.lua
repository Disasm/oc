local robot = require("robot")
local computer = require("computer")
local event = require("event")
local component = require("component")
local sides = require("sides")
local ic = component.inventory_controller
local crafting = component.crafting

local function move(str)
  for i = 1, #str do
    local arg = str:sub(i,i)
    if arg == "f" then
      while not robot.forward() do
        os.sleep(0.3)
      end
    elseif arg == "b" then
      while not robot.back() do
        os.sleep(0.3)
      end
    elseif arg == "u" then
      while not robot.up() do
        os.sleep(0.3)
      end
    elseif arg == "d" then
      while not robot.down() do
        os.sleep(0.3)
      end
    elseif arg == "l" then
      if rtl_mode then
        robot.turnRight()
      else
        robot.turnLeft()
      end
    elseif arg == "r" then
      if rtl_mode then
        robot.turnLeft()
      else
        robot.turnRight()
      end
    else
      error("unknown arg for move")
    end
  end
end

local function do_craft()
  move("dd")
  local down_inventory_size = ic.getInventorySize(sides.down)
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
          move("uu")
          return
        end
      end
    end
    robot.select(16)
    crafting.craft(64)
    move("ll")
    if not robot.drop() then
      print("drop failed")
    end
    move("ll")
  end
  move("uu")
end

local function charge()
  local mfe_charge_slot = 1
  robot.select(4)
  ic.equip()
  while not ic.dropIntoSlot(sides.up, mfe_charge_slot) do end
  local charge = ic.getStackInSlot(sides.up, mfe_charge_slot).charge
  do_craft()
  while true do
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
