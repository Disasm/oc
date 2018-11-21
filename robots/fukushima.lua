local event = require('event')
local robot = require("robot")
local computer = require('computer')
local component = require("component")
local crafting = component.crafting
local ic = component.inventory_controller

local names = {}
names["wrench"] = "ic2:electric_wrench"
names["condensator"] = "ic2:rsh_condensator"
names["fuel"] = "ic2:quad_uranium_fuel_rod"
names["redstone"] = "minecraft:redstone"

local function find_slot(item_type)
    for i=1,robot.inventorySize() do
        local stack = ic.getStackInInternalSlot(i)
        if stack and stack.name == names[item_type] then
            return i
        end
    end
end

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

local function equip(slot)
    robot.select(slot)
    ic.equip()
end

local function unequip()
    for i=1,robot.inventorySize() do
        if robot.count(i) == 0 then
            equip(i)
            return
        end
    end
end

local function check_reactor_item(slot, item_type)
    print("Checking reactor slot "..slot.."...")
    local s = ic.getStackInSlot(sides.front, slot)
    if s ~= nil then
        if s.name == names[item_type] then
            return
        end
    end
    error("Invalid item in reactor slot "..slot)
end

local condensator_slots = {1, 2, 3, 7, 8, 9}
local fuel_slots = {4, 5, 6}

local function check_reactor()
    print("Checking reactor...")
    for i=1,#condensator_slots do
        check_reactor_item(condensator_slots[i], "condensator")
    end
    for i=1,#fuel_slots do
        check_reactor_item(fuel_slots[i], "fuel")
    end
end

local function safe_check_reactor()
    return pcall(check_reactor)
end

local function check_wrench()
    unequip()
    local slot = find_slot("wrench")
    if slot == nil then
        error("wrench is not found")
    end
    local s = ic.getStackInInternalSlot(slot)
    local delta = s.maxDamage - s.damage
    if delta < 10 then
        error("wrench is almost broken")
    end
    equip(slot)
end

local function check_redstone()
    local slot = find_slot("redstone")
    if slot == nil then
        error("no redstone")
    end
    gather(slot)
    local s = ic.getStackInInternalSlot(slot)
    if s.size < #condensator_slots then
        error("insufficient redstone")
    end
end

local function recharge_slot(slot)
    local s = ic.getStackInSlot(sides.front, slot)
    if s.damage < 10000 then
        return
    end

    if not ic.suckFromSlot(sides.front, slot) then
        error("suckFromSlot() failed")
    end
    if not crafting.craft(1) then
        error("craft() failed")
    end
    if not ic.dropIntoSlot(sides.front, slot) then
        error("dropIntoSlot() failed")
    end
end

local function cycle()
    if computer.energy() < 1000 then
        error("not enough energy for safe nuclear operation")
    end
    check_redstone()

    -- prepare crafting zone
    local slot = find_slot("redstone")
    if slot ~= 1 then
        robot.select(slot)
        robot.transferTo(1)
    end
    robot.select(2)

    for i=1,#condensator_slots do
        recharge_slot(condensator_slots[i])
    end
end

check_reactor()
check_wrench()
check_redstone()
print("Checks passed, you can start reactor now...")

while true do
    if event.pull(1, "interrupted") then
        robot.use()
        return
    end
    local r, e = pcall(cycle)
    if not r then
        robot.use()
        print("Error: "..tostring(e))
        return
    end
end
