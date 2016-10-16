local robot = require("robot")
local component = require("component")
local ic = component.inventory_controller
local craft = component.crafting.craft
local libmine = require("libmine")

for i = 1, 4*64 do
  libmine.last_equipped = nil
  libmine.equip("bucket")
  robot.use()
  robot.select(1)
  ic.equip()
  robot.select(12)
  craft()
  os.sleep(0.2)
end
