
local robot = require("robot")

local output_count = 15

local function report_tank_levels()
  local list = {}
  for i = 1, 2 do
    table.insert(list, string.format("%d", robot.tankLevel(i)))
  end
  print(string.format("Levels: [ %s ]", table.concat(list, " | ")))
end

function forward()
  -- print("forward")
  while not robot.forward() do end
end
function left()
  -- print("left")
  while not robot.turnLeft() do end
end
function right()
  -- print("right")
  while not robot.turnRight() do end
end

function get_lava()
  while robot.tankLevel(2) < 15000 do
    print("Filling tank...")
    robot.selectTank(1)
    robot.transferFluidTo(2, robot.tankLevel(1) - 1)
    report_tank_levels()
    robot.fillDown()
    while not robot.drainDown() do end
    report_tank_levels()
  end
end

report_tank_levels()
if robot.tankLevel(1) < 1 then
  while robot.tankLevel(1) < 1 do
    print("Please enter lava.")
    robot.drainDown()
    report_tank_levels()
  end
end
-- local side_is_right = false
while true do
  print("Filling outputs...")
  for i = 1, output_count do
    print(string.format("Filling output %d", i))
    get_lava()
    -- if side_is_right then right() else left() end
    -- left()
    robot.selectTank(2)
    robot.fill(16000)
    report_tank_levels()
    if i ~= output_count then
      -- if side_is_right then left() else right() end
      right()
      forward()
      left()
    end
  end
  print("Going back...")
  left()
  for i = 1, output_count - 1 do
    forward()
  end
  right()
  -- if side_is_right then left(); left() else left() end
  -- side_is_right = not side_is_right
end


