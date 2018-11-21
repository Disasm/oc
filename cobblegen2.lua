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


local function charge()
  move("ulf")
  local mfe_charge_slot = 1
  local mfe_side = sides.front
  robot.select(4)
  ic.equip()
  while not ic.dropIntoSlot(mfe_side, mfe_charge_slot) do end
  local charge = ic.getStackInSlot(mfe_side, mfe_charge_slot).charge
  while true do
    local new_charge = ic.getStackInSlot(mfe_side, mfe_charge_slot).charge
    if new_charge == charge then
      break
    end
    charge = new_charge
  end
  robot.select(4)
  ic.suckFromSlot(mfe_side, mfe_charge_slot)
  ic.equip()
  move("brd")
end

while true do
  if not robot.use() then
    charge()
  end
  while not robot.detect() do
  end
end
