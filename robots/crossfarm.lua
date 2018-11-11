local event = require('event')
local robot = require("robot")
local component = require("component")
local crafting = component.crafting
local ic = component.inventory_controller

local args = {...}
if #args == 0 then
    print("Usage: crossfarm <xsize> <ysize> <first_empty> <timeout>")
    return
end

local x_size = tonumber(args[1])
local y_size = tonumber(args[2])
local first_empty = tonumber(args[3])
local timeout = tonumber(args[4])

if first_empty ~= 0 then
    first_empty = true
else
    first_empty = false
end

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
names["planks"] = "minecraft:planks"
names["stick"] = "minecraft:stick"
names["rod"] = "ic2:uranium_fuel_rod"
names["crop_sticks"] = "agricraft:crop_sticks"

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

local function clean_craft_field()
    local craft_slots = {1, 2, 3, 4, 5, 6, 7, 9, 10, 11}
    for i=1,#craft_slots do
        craft_slot = craft_slots[i]
        if robot.count(i) ~= 0 then
            local empty_slot = nil
            for j=12,robot.inventorySize() do
                if robot.count(j) == 0 then
                    empty_slot = j
                    break
                end
            end
            if empty_slot == nil then
                error("Can't find empty slot")
            end
            robot.select(i)
            robot.transferTo(empty_slot)
        end
    end
end

local function check_items(item_type, n)
    if n == 0 then
        return
    end
    local slot = find_slot(item_type)
    if slot ~= nil then
        gather(slot)
        if robot.count(slot) >= n then
            return
        end
    end
    error("Not enough items ("..item_type..")")
end

local function craft_sticks(n)
    local crop_sticks = n
    local sticks = crop_sticks
    local planks = math.floor(sticks / 2)
    local logs = math.floor(planks / 4)
    check_items("wood", logs)

    clean_craft_field()
    local slot = find_slot("wood")
    robot.select(slot)
    robot.transferTo(1)
    robot.select(4)
    crafting.craft(10000)
    
    robot.select(4)
    robot.transferTo(1, math.floor(planks / 2))
    robot.transferTo(5, math.floor(planks / 2))
    crafting.craft(10000)
    
    robot.select(4)
    robot.transferTo(1, math.floor(sticks / 4))
    robot.transferTo(2, math.floor(sticks / 4))
    robot.transferTo(5, math.floor(sticks / 4))
    robot.transferTo(6, math.floor(sticks / 4))
    crafting.craft(10000)
end

local equipped_sticks = 0
local function equip_sticks()
    local slot = find_slot("crop_sticks")
    if slot ~= nil then
        gather(slot)
        if robot.count(slot) < 32 then
            craft_sticks(32)
            equip_sticks()
        else
            equipped_sticks = robot.count(slot)
            equip(slot)
        end
    else
        craft_sticks(64)
        equip_sticks()
    end
end
local function ensure_sticks()
    if equipped_sticks < 2 then
        unequip()
        equip_sticks()
    end
end
local function work()
    ensure_sticks()
    robot.swingDown()
    robot.useDown()
    robot.useDown()
    equipped_sticks = equipped_sticks - 2
end
local function home_update()
    for i=1,robot.inventorySize() do
        local stack = ic.getStackInInternalSlot(i)
        if stack and stack.name == "agricraft:agri_seed" then
            robot.select(i)
            robot.dropUp()
        end
    end

    unequip()
    local slot = find_slot("crop_sticks")
    local n = 0
    if slot ~= nil then
        gather(slot)
        n = robot.count(slot)
    end
    if n < 32 then
        craft_sticks(32)
    end
    equip_sticks()
end

local current_empty = false
local function work_sometimes()
    if current_empty then
        work()
    end
end

home_update()
if event.pull(1, "interrupted") then
    return
end

while true do
    move("f")
    current_empty = first_empty
    work_sometimes()

    for x = 1, x_size do
        for y = 1, y_size-1 do
            move("f")
            current_empty = not current_empty
            work_sometimes()
        end
        if x ~= x_size then
            if x % 2 == 1 then
                move("rfr")
            else
                move("lfl")
            end
            current_empty = not current_empty
            work_sometimes()
        end
    end
    if x_size % 2 == 1 then
        move("ll")
        for y = 1, y_size-1 do
            move("f")
        end
    end
    move("r")
    for x = 1, x_size-1 do
        move("f")
    end
    move("lfll")

    home_update()

    if event.pull(60, "interrupted") then
        break
    end
end
