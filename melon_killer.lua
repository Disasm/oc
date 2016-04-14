
local robot = require("robot")

local function go()
  while robot.forward() do
  end
end

local x = 4

for i = 1, x do
  robot.swingDown()
  go()
  go()
end
