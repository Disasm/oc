local robot = require("robot")
local component = require("component")
local ic = component.inventory_controller
local computer = require("computer")
local sides = require("sides")

local chestSide = sides.down

function equalThings(stack1, stack2)
    if (stack1 == nil) or (stack2 == nil) then
        return false
    end

    return (stack1.label == stack2.label) and (stack1.name == stack2.name)
end

chests = {}

local chestCache = nil;

chests.updateCache = function()
    print("Updating cache...")
    chestCache = {}
    local n = ic.getInventorySize(chestSide);
    for i = 1,n do
        chestCache[i] = ic.getStackInSlot(chestSide, i);
    end
end

chests.dropAll = function()
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
    robot.select(slot);
    local n = ic.getInventorySize(chestSide);
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
    local n = ic.getInventorySize(chestSide);
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

return chests
