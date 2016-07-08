component = require("component")
computer = require("computer")
robot = require("robot")
magnet = component.tractor_beam
ic = component.inventory_controller

safeDistance = 4

junkIds = {"minecraft:dirt", "minecraft:cobblestone", "minecraft:gravel",
"chisel:granite", "minecraft:sand", "minecraft:sandstone",
"chisel:marble", "chisel:andesite", "chisel:diorite", "chisel:limestone"}
badNames = {}
for _, x in pairs(junkIds) do
    badNames[x] = true
end

function forceForward()
    while not robot.forward() do
        os.sleep(0.3)
    end
end

function cleanup(force)
    local freeSlots = 0
    for i=1,robot.inventorySize() do
        if robot.count(i) == 0 then
            freeSlots = freeSlots + 1
        end
    end
    if (freeSlots > 1) and (not force) then
        return
    end
    
    print("Cleaning up...")
    
    computer.beep(2000, 1)
    
    local badSlots = {}
    for i=1,robot.inventorySize() do
        local s = ic.getStackInInternalSlot(i)
        if s ~= nil then
            if string.find(s.name, "argyrodite") then
                computer.beep(1000, 5)
                os.sleep(0.5)
                computer.beep(1000, 5)
                os.sleep(0.5)
                computer.beep(1000, 5)
            end
            if badNames[s.name] then
                table.insert(badSlots, i)
            end
        end
    end
    
    if #badSlots == 0 then
        return
    end
    
    robot.turnRight()
    robot.turnRight()
    for i=1,safeDistance do
        forceForward()
    end
    
    for _,slot in pairs(badSlots) do
        robot.select(slot)
        robot.drop()
    end
    robot.select(1)
    while not robot.use() do os.sleep(0.1) end
    os.sleep(1)
    while not robot.use() do os.sleep(0.1) end
    
    robot.turnRight()
    robot.turnRight()
    for i=1,safeDistance do
        forceForward()
    end
end

args = {...}
if #args > 0 then
    cleanup(true)
    return
end

while true do
    while true do
        if magnet.suck() == false then
            break
        end
    end
    
    cleanup()
    forceForward()
end
