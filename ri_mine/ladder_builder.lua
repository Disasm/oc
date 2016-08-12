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


if robot.count(1) < 36 then
  error("not enough items!")
end
if robot.count(2) < 5 then
  error("not enough items!")
end

-- ladder
for i = 1, 3 do
  move("down")
  place(1, "up")
  move("back")
  place(2, "up")
  move("forward")
end
-- railing, floor
for j = 1, 2 do
  move("down")
  place(1, "up")
  move("back")
  place(2, "up")
  move("forward")

  robot.turnRight()
  for i = 1, 2 do
    move("forward")
    place(1, "up")
  end
  robot.turnRight()
  for i = 1, 3 do
    move("forward")
    place(1, "up")
  end

  robot.turnRight()
  for i = 1, 4 do
    move("forward")
    place(1, "up")
  end
  robot.turnRight()
  for i = 1, 3 do
    move("forward")
    place(1, "up")
  end
  robot.turnRight()
  move("forward")
  place(1, "up")
  if j == 2 then break end
  move("forward")
  robot.turnLeft()
end
robot.turnRight()
for i = 1, 2 do
  move("forward")
  place(1, "up")
end
robot.turnLeft()
for i = 1, 2 do
  move("forward")
  place(1, "up")
end
robot.turnLeft()
move("forward")
place(1, "up")
move("forward")
robot.turnLeft()
move("forward")
robot.turnRight()





