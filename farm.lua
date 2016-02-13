local robot = require("robot")
local component = require("component")
local term = require("term")
local ic = component.inventory_controller

print("Slots:")
print("X - Hoe")
print("1 - Bone meal")
print("2 - Seeds")
print("Press Enter to continue")
term.read()

function gather(slot)
    robot.select(slot)
    for i=1,16 do
        local space = robot.space(slot)
        if space == 0 then
            break
        end
        if (i ~= slot) and robot.compareTo(i) then
            robot.select(i)
            robot.transferTo(slot, space)
            robot.select(slot)
        end
    end
end

while true do
    if (robot.count(1) < 3) or (robot.count(2) < 2) then
        break
    end
    
    -- Use Hoe
    robot.useDown()
    
    os.sleep(0.4)

    -- Seeds
    robot.select(2)
    ic.equip()
    robot.useDown()
    ic.equip()
    
    os.sleep(0.4)
    
    -- Bone meal
    robot.select(1)
    ic.equip()
    while true do
        if robot.useDown() == false then
            break
        end
        os.sleep(0.4)
    end
    
    os.sleep(0.4)
    
    -- Take result
    robot.swingDown()
    ic.equip()
    
    gather(1)
    gather(2)
end
