local event = require('event')
local robot = require("robot")
local component = require("component")
local tractor_beam = component.tractor_beam
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
    elseif arg == "l" then
      robot.turnLeft()
    elseif arg == "r" then
      robot.turnRight()
    else
      error("unknown arg for move")
    end
  end
end

local w = 9
local h = 16

local function do_craft()
  for i = 1, 11 do
    if robot.count(i) ~= 64 then
      return
    end
  end
  robot.select(13)
  crafting.craft(64)
  robot.select(12)
  robot.transferTo(1)
  robot.select(1)
end

local function work()
  robot.useDown()
  while tractor_beam.suck() do
  end
  do_craft()
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
  for i = 13, 16 do
    while robot.count(i) > 0 do
      robot.select(i)
      robot.dropUp()
    end
  end
  robot.select(1)
  if event.pull(20, "interrupted") then
    break
  end
end
