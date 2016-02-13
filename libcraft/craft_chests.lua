local robot = require("robot")
local component = require("component")
local ic = component.inventory_controller
local computer = require("computer")
local sides = require("sides")
local movement = require("movement")

local chestSide = sides.down
local chests = nil

function equalThings(stack1, stack2)
    if (stack1 == nil) or (stack2 == nil) then
        return false
    end

    return (stack1.label == stack2.label) and (stack1.name == stack2.name)
end

chests = {}

local chestCache = nil;

chests.goToOutcomingChest = function() 
    for j = 1, #chests do 
        if chests[j].chest_type == "outcoming" then 
            movement.set_pos(chests[j].pos.x, chests[j].pos.z)
            return 
        end 
    end
    print("Warning: no outcoming chest!")
end


function updateOneChestCache() 
    local r = {}
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        print("Warning: chest is displaced")
        return 
    end
    for i = 1,n do
        r[i] = ic.getStackInSlot(chestSide, i);
    end
    return r
end

chests.updateCache = function()
    print("Updating cache...")
    chestCache = {}
    for j = 1, #chests do 
        print("Checking chest "..j)
        if chests[j].chest_type ~= "outcoming" then 
            movement.set_pos(chests[j].pos.x, chests[j].pos.z)
            chestCache[j] = updateOneChestCache() 
        end
    end 
end

chests.dropAll = function()
    
    local moved_to_chest = false 
    
    for slot=1,16 do
        if robot.count(slot) > 0 then
            if not moved_to_chest then 
            
                local chest_ok = false
                for j = 1, #chests do 
                    if chests[j].chest_type == "storage" then 
                        movement.set_pos(chests[j].pos.x, chests[j].pos.z)
                        chest_ok = true 
                        break 
                    end
                end
                if not chest_ok then 
                    debug("No storage chests!");
                    computer.beep(1000, 0.7);
                    return
                end 
            
                moved_to_chest = true
            end 
        
        
            if not chests.placeItemsToChest(slot) then
                debug("Can't put items into chest");
                computer.beep(1000, 0.7);
            end
        end
    end
    robot.select(1);
end

chests.countItemInChest = function(stack)
    
    local cnt = 0;
    for i = 1, #chestCache do 
        if chestCache[i] ~= nil then 
            for j = 1, #(chestCache[i]) do 
                local s = chestCache[i][j];
                if equalThings(s, stack) then
                    cnt = cnt + s.size;
                end
            
            end    
        end
    end
    return cnt;
end

chests.suckItemsFromChest = function(stack, slot)
    robot.select(slot);
    local cnt = stack.size;
    for i = 1, #chestCache do 
        if chestCache[i] ~= nil then 
            for j = 1, #(chestCache[i]) do 
                local s = chestCache[i][j];
                if equalThings(s, stack) then
                    movement.set_pos(chests[i].pos.x, chests[i].pos.z)
                    local ok = false;
                    local take = s.size;
                    if s.size > cnt then
                        take = cnt;
                        ok = ic.suckFromSlot(chestSide, j, cnt);
                    else
                        ok = ic.suckFromSlot(chestSide, j);
                    end
                    if ok then
                        cnt = cnt - take;
                        chestCache[i][j] = ic.getStackInSlot(chestSide, j);
                        if cnt <= 0 then return true end 
                    end            
                end
            end         
        end
    end
    return false
end

chests.placeItemsToChest = function(srcSlot)
    local chest_ok = false
    local chest_index = nil
    for j = 1, #chests do 
      if chests[j].chest_type == "storage" then 
            movement.set_pos(chests[j].pos.x, chests[j].pos.z)
            chest_ok = true 
            chest_index = j
            break 
        end
    end
    if not chest_ok then 
        debug("No storage chests!");
        computer.beep(1000, 0.7);
        return
    end   
  
    local stack = ic.getStackInInternalSlot(srcSlot);
    robot.select(srcSlot);
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        debug("Warning: chest is displaced")
        return 
    end
    for i = 1,n do
        if robot.count(srcSlot) == 0 then
            break
        end
        local s = chestCache[chest_index][i];
        if equalThings(stack, s) then
            ic.dropIntoSlot(chestSide, i);
            chestCache[chest_index][i] = ic.getStackInSlot(chestSide, i);
        end
    end
    
    if robot.count(srcSlot) > 0 then
        for i = 1,n do
            if robot.count(srcSlot) == 0 then
                break
            end

            local s = chestCache[chest_index][i];
            if s == nil then
                ic.dropIntoSlot(chestSide, i);
                chestCache[chest_index][i] = ic.getStackInSlot(chestSide, i);
            end
        end
    end
    return robot.count(srcSlot) == 0;
end

chests.setChests = function(v)
    chests = v 
end
  

return chests
