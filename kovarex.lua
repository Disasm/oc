local sides = require("sides")
local event = require("event")
local robot = require("robot")
local component = require("component")
local computer = require("computer")
local crafting = component.crafting
local ic = component.inventory_controller

local function suck(side, slot_min, slot_max, count)
  while true do
    for i = slot_min, slot_max do
      if robot.count() == count then
        return
      end
      ic.suckFromSlot(side, i, count - robot.count())
      if robot.count() == count then
        return
      end
    end
    if event.pull(1, "interrupted") then
      error("interrupted")
    end
  end
end

while true do
  if robot.count(2) == 0 then -- running from empty state
    robot.select(1)
    suck(sides.front, 4, 4, 7)
    robot.select(8)
    suck(sides.front, 2, 3, 64)
    robot.select(12)
    suck(sides.front, 2, 3, 48)

    robot.select(4)
    crafting.craft(63)
    for i = 5, 7 do
      robot.transferTo(i, 21)
    end

    robot.select(8)
    robot.transferTo(1, 21)
    robot.transferTo(2, 21)
    robot.transferTo(3, 21)
    robot.transferTo(9, 1)
    robot.select(12)
    robot.transferTo(9, 20)
    robot.transferTo(10, 21)
    robot.transferTo(11, 7)
  end -- else, running from crafting state

  robot.select(11)
  suck(sides.up, 1, 27, 21)

  robot.select(4)
  crafting.craft(21)
  robot.drop(20)

  for target = 28, 45 do
    if robot.count(4) == 0 then
      break
    end
    ic.dropIntoSlot(sides.up, target)
  end
end
