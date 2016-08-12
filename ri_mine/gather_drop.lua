local component = require("component")
local computer = require("computer")
local robot = require("robot")
local magnet = component.tractor_beam
local ic = component.inventory_controller
local libmine = require("libmine")

local safeDistance = 1

local badNames = {}
for _, x in pairs({
    "minecraft:dirt", "minecraft:cobblestone", "minecraft:gravel",
    "chisel:granite", "minecraft:sand", "minecraft:sandstone",
    "chisel:marble", "chisel:andesite", "chisel:diorite", "chisel:limestone"
}) do
    badNames[x] = true
end

local slot_to_name = {}
local result_counts = {}
local name_to_label = {}

local function cleanup(force)
    local freeSlots = 0
    local new_result_counts = {}
    for i=1,robot.inventorySize() do
        local current_count = robot.count(i)
        if current_count == 0 then
            freeSlots = freeSlots + 1
        else
            if not slot_to_name[i] then
                local stack = ic.getStackInInternalSlot(i)
                slot_to_name[i] = stack.name
                if not name_to_label[stack.name] then
                    name_to_label[stack.name] = stack.label
                end
            end
            if not badNames[slot_to_name[i]] then
                new_result_counts[slot_to_name[i]] =
                    (new_result_counts[slot_to_name[i]] or 0) + current_count
            end
        end
    end
    for name, count in pairs(new_result_counts) do
        if count > (result_counts[name] or 0) then
            print(string.format("%d x %s", count, name_to_label[name]))
            result_counts[name] = count
            if string.find(name, "Custom_Ores") then
                computer.beep(1000, 0.5)
                os.sleep(0.5)
                computer.beep(1000, 0.5)
            end
        end
    end

    if (freeSlots > 1) and (not force) then
        return
    end
    
    print("Cleaning up...")
    
    computer.beep(2000, 1)

    local skippedOneCobble = false
    
    local badSlots = {}
    for i=1,robot.inventorySize() do
        local s = ic.getStackInInternalSlot(i)
        if s ~= nil then

            if not skippedOneCobble and s.name == libmine.item_names.cobble then
              skippedOneCobble = true
            elseif badNames[s.name] then
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
        libmine.force_forward()
    end
    
    for _,slot in pairs(badSlots) do
        robot.select(slot)
        robot.drop()
    end
    libmine.equip("lava_bucket")
    libmine.force_use()
    os.sleep(1)
    libmine.force_use()
    libmine.equip("laser")
    if not libmine.find_slot("lava_bucket", true) then
       error("Lava bucket has been misplaced.")
    end

    robot.turnRight()
    robot.turnRight()
    for i=1,safeDistance do
        libmine.force_forward()
    end

    for slot1=1, robot.inventorySize() do
        if robot.count(slot1) == 0 then
            for slot2 = slot1 + 1, robot.inventorySize() do
                if robot.count(slot2) > 0 then
                    robot.select(slot2)
                    robot.transferTo(slot1)
                    break
                end
            end
        end
    end
    robot.select(1)
end

args = {...}
if #args > 0 then
    cleanup(true)
    return
end

robot.select(libmine.find_slot("empty"))
ic.equip()
libmine.find_slot("lava_bucket")
libmine.find_slot("cobble")
libmine.equip("laser")
while true do

    robot.useUp()
    libmine.equip("cobble")
    for i=1,5 do
        if robot.useUp() then
            break
        end
        os.sleep(0.2)
    end
    libmine.equip("laser")

    while true do
        if magnet.suck() == false then
            break
        end
    end
    cleanup()
    while not robot.forward() do
        robot.use()
    end

end
