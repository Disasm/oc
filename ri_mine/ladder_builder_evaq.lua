local robot = require("robot")

local function move(dir)
  local func
  if dir == "up" then
    func = robot.up
  elseif dir == "down" then
    func = robot.down
  elseif dir == "forward" then
    func = robot.forward
  elseif dir == "back" then
    func = robot.back
  else
    error("invalid move direction")
  end
  while not func() do end
end
local function place(slot, dir)
  robot.select(slot)
  if dir == "up" then
    func = robot.placeUp
  elseif dir == "down" then
    func = robot.placeDown
  elseif dir == "forward" then
    func = robot.place
  else
    error("invalid move direction")
  end
  while not func() do end
end


robot.turnLeft()
for i = 1, 3 do move("forward") end
robot.turnLeft()
robot.turnLeft()
for i = 1, 3 do move("up") end
for i = 1, 2 do move("forward") end
robot.turnRight()
move("forward")
move("down")


