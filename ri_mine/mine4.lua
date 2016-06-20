local robot = require('robot')
local computer = require('computer')
local component = require('component')

function move_smart(dir, restless)
  local ok, error = false, nil
  while not ok do
    if dir == "up" then
      ok, error = robot.up()
    elseif dir == "forward" then
      ok, error = robot.forward()
    elseif dir == "down" then
      ok, error = robot.down()
    else
      print("move_smart: invalid direction", dir);
      return false, 'invalid direction'
    end
    if not ok then
      if not restless and  error ~= "already moving" then
        print("move failed: ", dir, error)
        break
      else
        print("move failed, retrying: ", dir, error)
      end
    end
  end
  return ok, error
end

function swing_sensibly(dir)
  local detection, cause
  if dir == "forward" then
    detection, cause = robot.detect();
  elseif dir == "down" then
    detection, cause = robot.detectDown();
  elseif dir == "up" then
    detection, cause = robot.detectUp();
  end
  if not detection then return true, '' end
  if cause == "entity" then return false, 'entity in the way' end
  if dir == "forward" then
    return robot.swing()
  elseif dir == "down" then
    return robot.swingDown()
  elseif dir == "up" then
    return robot.swingUp()
  end
end


local slots_count = robot.inventorySize()
local good_slots = {}
local bad_slots = {}
local ic = component.inventory_controller
local tbeam = component.tractor_beam

local bad_names = {}
--local good_names = {}

for _, x in pairs({"minecraft:dirt", "minecraft:cobblestone", "minecraft:gravel", "chisel:granite"}) do
  bad_names[x] = true
end
--for _, x in pairs({}) do
--  good_names[x] = true
--end


while true do
  --swing_sensibly("up")
  --swing_sensibly("down")
  --swing_sensibly("forward")
  robot.useUp()
  while not robot.forward() do
    robot.use()
  end
  tbeam.suck()
  for i = 1, slots_count do
    if not good_slots[i] and not bad_slots[i] and robot.count(i) > 0 then
      -- new slot
      local name = ic.getStackInInternalSlot(i).name
      if bad_names[name] then
        bad_slots[i] = true
      else --if good_names[name] then
        good_slots[i] = true
      --else
      --  print("Unknown item: \"" .. name .. "\"")
      --  computer.beep(500, 3)
      end
    end
    if bad_slots[i] and robot.count(i) > 47 then
      robot.select(i)
      robot.drop()
      bad_slots[i] = nil
    end
  end
end


