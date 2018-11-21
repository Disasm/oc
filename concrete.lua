local robot = require("robot")
local component = require("component")

ic = component.inventory_controller
while true do
  robot.useDown()
  ic.equip()
  robot.swingDown()
  ic.equip()
end
