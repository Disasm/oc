local robot = require('robot')
while true do
  robot.useUp()
  while not robot.forward() do
    robot.use()
  end
end
