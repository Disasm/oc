local robot = require("robot")
local computer = require("computer")

robot.select(1)
for i = 1, 64*15 do
  robot.useDown()
end
computer.beep(200, 1)
