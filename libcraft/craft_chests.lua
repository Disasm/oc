local robot = require("robot")
local component = require("component")
local ic = component.inventory_controller
local computer = require("computer")
local sides = require("sides")
local movement = require("movement")

local chestSide = sides.down
local machines = nil

function equalThings(stack1, stack2)
    if (stack1 == nil) or (stack2 == nil) then
        return false
    end

    return (stack1.label == stack2.label) and (stack1.name == stack2.name)
end

chests = {}

local chestCache = nil;


function go_to_the_chest()
    local pos = nil
    for j = 1, #machines do 
        if machines[j].machine_type == "Chest" then 
            pos = machines[i].pos;
            break
        end
    end 
    if pos then
        movement.set_pos(pos.x, pos.z)
    end
end

chests.updateCache = function()
    print("Updating cache...")
    chestCache = {}
    go_to_the_chest()
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        print("Warning: chest is displaced")
        return 
    end
    for i = 1,n do
        chestCache[i] = ic.getStackInSlot(chestSide, i);
    end
end

chests.dropAll = function()
    go_to_the_chest()
    for slot=1,16 do
        if robot.count(slot) > 0 then
            if not chests.placeItemsToChest(slot) then
                debug("Can't put items into chest");
                computer.beep(1000, 0.7);
            end
        end
    end
    robot.select(1);
end

chests.countItemInChest = function(stack)
    go_to_the_chest()
    local n = ic.getInventorySize(chestSide);
    local cnt = 0;
    for i = 1,n do
        --local s = ic.getStackInSlot(chestSide, i);
        local s = chestCache[i];
        if equalThings(s, stack) then
            cnt = cnt + s.size;
        end
    end
    return cnt;
end

chests.suckItemsFromChest = function(stack, slot)
    go_to_the_chest()
    robot.select(slot);
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        debug("Warning: chest is displaced")
        return 
    end
    local cnt = stack.size;
    for i = 1,n do
        --local s = ic.getStackInSlot(chestSide, i);
        local s = chestCache[i];
        if equalThings(s, stack) then
            local ok = false;
            local take = s.size;
            if s.size > cnt then
                take = cnt;
                ok = ic.suckFromSlot(chestSide, i, cnt);
            else
                ok = ic.suckFromSlot(chestSide, i);
            end
            if ok then
                cnt = cnt - take;
                chestCache[i] = ic.getStackInSlot(chestSide, i);
            end
        end
        if cnt <= 0 then
            break
        end
    end

    if cnt > 0 then
        return false
    else
        return true
    end
end

chests.placeItemsToChest = function(srcSlot)
    local stack = ic.getStackInInternalSlot(srcSlot);
    robot.select(srcSlot);
    go_to_the_chest()
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        debug("Warning: chest is displaced")
        return 
    end
    for i = 1,n do
        if robot.count(srcSlot) == 0 then
            break
        end
        local s = chestCache[i];
        if equalThings(stack, s) then
            ic.dropIntoSlot(chestSide, i);
            chestCache[i] = ic.getStackInSlot(chestSide, i);
        end
    end
    
    if robot.count(srcSlot) > 0 then
        for i = 1,n do
            if robot.count(srcSlot) == 0 then
                break
            end

            local s = chestCache[i];
            if s == nil then
                ic.dropIntoSlot(chestSide, i);
                chestCache[i] = ic.getStackInSlot(chestSide, i);
            end
        end
    end
    return robot.count(srcSlot) == 0;
end

chests.setMachines = function(v)
    machines = v 
end
  

return chests
