local component = require("component")
local robot =require("robot")
local ic = component.inventory_controller
local tractor_beam = component.tractor_beam

local function gather(slot)
    robot.select(slot)
    for i=1,robot.inventorySize() do
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

robot.select(1)
while true do
    if robot.count(1) > 0 then
        local n = robot.count(1)
        ic.equip()
        for i=1,n do
            robot.useDown()
        end
    end
    while tractor_beam.suck() do
        os.sleep(0.3)
    end
    
    local eggs = 0
    for i=1,robot.inventorySize() do
        if robot.count(i) == 0 then
            break
        end
        local s = ic.getStackInInternalSlot(i)
        robot.select(i)
        if s.name ~= "minecraft:egg" then
            robot.dropUp()
        else
            eggs = eggs + s.size
            robot.drop()
        end
    end
    robot.select(1)
    if eggs > 0 then
        print("Got "..eggs.." eggs!")
    end

    if robot.count(1) > 0 then
        gather(1)
    else
        robot.suck()
    end
end
