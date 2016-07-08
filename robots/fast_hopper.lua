local component = require("component")
local robot = component.robot
local sides = require("sides")

local sourceSide = sides.front
local sinkSide = sides.down

local n = 0

for i=1,16 do
  if robot.count(i) > 0 then
    robot.select(i)
    while robot.count(i) > 0 do
      robot.select(i)
      robot.drop(sinkSide)
    end
    n = n + 1
  end
end

while n < 100 do
  if robot.suck(sourceSide) then
    robot.drop(sinkSide)
    n = n + 1
  end
end
