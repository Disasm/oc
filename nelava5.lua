local robot = require("robot")
local sides = require("sides")
local ic = require("component").inventory_controller
args = {...}
cmd = args[1]

if cmd == "i" then
  robot.selectTank(1)
  if not robot.drainUp() then error("fail") end
  while robot.drainUp() do end

elseif cmd == "o" then
  robot.selectTank(1)
  while true do
    while robot.tankSpace(1) >= 1000 do
      if not robot.transferFluidTo(2, 1) then error("fail1") end
      robot.selectTank(2)
      if not robot.fillDown() then error("fail2") end
      robot.selectTank(1)
      if not robot.drainDown() then error("fail3") end
    end
    robot.fill()
    --robot.fillUp()
    --ic.suckFromSlot(sides.front, 2)
    --ic.suckFromSlot(sides.up, 2)
  end
elseif cmd == "c" then
  local function clear_tank()
    while robot.tankLevel() > 0 do
      robot.fill()
    end
  end
  robot.selectTank(1)
  clear_tank()
  robot.selectTank(2)
  clear_tank()
elseif cmd == "d" then
  local function delete_tank()
    while robot.tankLevel() > 0 do
      robot.fillDown()
      robot.placeDown()
      robot.swingDown()
    end
  end
  robot.selectTank(1)
  delete_tank()
  robot.selectTank(2)
  delete_tank()
end

