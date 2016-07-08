local robot = require('robot')
local component = require('component')
local ic = component.inventory_controller

local function gather(slot)
  if robot.space(slot) == 0 then
    return
  end
  robot.select(slot)
  for i=(slot+1),robot.inventorySize() do
    if robot.count(i) > 0 then
      if robot.compareTo(i) or (robot.count(slot) == 0) then
        robot.select(i)
        robot.transferTo(slot)
        robot.select(slot)
      end
    end
    if robot.space(slot) == 0 then
      return
    end
  end
end

robot.select(1)
while true do
  if robot.count(2) < 5 then
    gather(2)
  end
  if robot.count(2) == 0 then
    print("Out of cobblestone")
    break
  end
  robot.useUp()
  robot.select(2)
  ic.equip()
  for i=1,5 do
    if robot.useUp() then
      break
    end
    os.sleep(0.2)
  end
  ic.equip()
  robot.select(1)
  while not robot.forward() do
    robot.use()
  end
end
