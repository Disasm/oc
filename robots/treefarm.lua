local event = require('event')
local robot = require("robot")
local component = require("component")
local crafting = component.crafting
local ic = component.inventory_controller
local tractor_beam = component.tractor_beam

local function move(str)
  for i = 1, #str do
    local arg = str:sub(i,i)
    if arg == "f" then
      while not robot.forward() do
        os.sleep(0.3)
      end
    elseif arg == "b" then
      while not robot.back() do
        os.sleep(0.3)
      end
    elseif arg == "u" then
      while not robot.up() do
        os.sleep(0.3)
      end
    elseif arg == "d" then
      while not robot.down() do
        os.sleep(0.3)
      end
    elseif arg == "l" then
      robot.turnLeft()
    elseif arg == "r" then
      robot.turnRight()
    else
      error("unknown arg for move")
    end
  end
end

local names = {}
names["wood"] = "minecraft:log"
names["axe"] = "minecraft:diamond_axe"
names["sapling"] = "minecraft:sapling"

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

local function check_axe()
    unequip()
    local slot = find_slot("axe")
    if slot == nil then
        error("axe is not found")
    end
    local s = ic.getStackInInternalSlot(slot)
    local delta = s.maxDamage - s.damage
    if delta < 10 then
        error("axe is almost broken")
    end
end

local function check_saplings()
    local slot = find_slot("sapling")
    if slot == nil then
        error("no saplings")
    end
    gather(slot)
end

while true do
    check_axe()
    check_saplings()

    move("ff")
    local slot = find_slot("sapling")
    equip(slot)
    if not robot.useDown() then
        error("can't place sapling")
    end
    move("bb")

    local slot = find_slot("axe")
    equip(slot)

    print("Waiting for tree...")
    while true do
        if event.pull(5, "interrupted") then
            return
        end
        move("f")
        while tractor_beam.suck() do
            os.sleep(0.5)
        end
        if robot.detect() then
            break
        end
        move("b")
    end
    robot.swing()
    move("f")
    robot.swingDown()

    while robot.detectUp() do
        if not robot.swingUp() then
            error("swing error")
        end
        move("u")
    end

    while not robot.detectDown() do
        move("d")
    end
    move("ubb")

    move("r")
    while true do
        local slot = find_slot("wood")
        if slot == nil then
            break
        end
        robot.select(slot)
        robot.drop()
    end
    
    while true do
        local slot = find_slot("sapling")
        if slot == nil then
            break
        end
        gather(slot)
        local s = ic.getStackInInternalSlot(slot)
        if s.size > 32 then
            robot.select(slot)
            robot.dropUp(s.size - 32)
        else
            break
        end
    end
    move("lff")

    print("Waiting for saplings...")
    for i=1,30 do
        if i % 5 == 0 then
            for k=1,6 do
                while tractor_beam.suck() do
                    os.sleep(0.5)
                end
                move("u")
            end
            for k=1,6 do
                move("d")
            end
        end
        if event.pull(1, "interrupted") then
            return
        end
    end
    move("bb")
end
