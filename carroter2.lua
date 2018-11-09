local event = require('event')
local robot = require("robot")
local computer = require("computer")

local component = require("component")
local tractor_beam = component.tractor_beam
local crafting = component.crafting

local w = 18
local h = 48
local rtl_mode = true

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


local function work()
  robot.useDown()
  while tractor_beam.suck() do
  end
end

local slots_count = robot.inventorySize()
local function do_craft()
  move("r")
  for i = 1, slots_count do
    if robot.count(i) > 0 then
      robot.select(i)
      robot.drop()
    end
  end
  move("l")
  robot.select(1)
end

robot.select(1)
if event.pull(1, "interrupted") then
  return
end

while true do
  for y = 1, h do
    for x = 1, w do
      move("f")
      work()
    end
    if y % 2 == 1 then
      move("rfr")
    else
      move("lfl")
    end
    work()
  end
  move("l")
  for y = 1, h do
    move("f")
  end
  move("r")
  do_craft()
  while computer.energy() < 20000 do
    if event.pull(1, "interrupted") then
      break
    end
  end
end
