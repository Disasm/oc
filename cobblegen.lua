local robot = require("robot")
local computer = require("computer")
local event = require("event")

while true do
  if not robot.use() then
    break
  end
  while not robot.detect() do
  end
end
while true do
  computer.beep(400, 0.5)
  if event.pull(5, "interrupted") then
    break
  end
end
