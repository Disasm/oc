local robot = require("robot")
local component = require("component")
local ic = component.inventory_controller
local computer = require("computer")
local sides = require("sides")
local movement = require("movement")
local file_serialization = require("file_serialization")
local chestSide = sides.down
local chestsList = nil


local item_cache = file_serialization.load("/item_type_data_cache.txt")
if item_cache == nil then item_cache = {} end 


function save_cache() 
    file_serialization.save("/item_type_data_cache.txt", item_cache)  
end



function equalThings(stack1, stack2)
    if (stack1 == nil) or (stack2 == nil) then
        return false
    end

    return (stack1.label == stack2.label) and (stack1.name == stack2.name)
end

chests = {}

local chestCache = nil;

chests.goToOutcomingChest = function() 
    for j = 1, #chestsList do 
        if chestsList[j].chest_type == "outcoming" then 
            movement.set_pos(chestsList[j].pos.x, chestsList[j].pos.z)
            return 
        end 
    end
    print("Warning: no outcoming chest!")
end


chests.sortIncoming = function() 
    local incoming_index = nil 
    for j = 1, #chestsList do 
        if chestsList[j].chest_type == "incoming" then 
            incoming_index = j
            break
        end 
    end
    if not incoming_index then 
        print("No incoming chest!")
        return
    end 
    print("Updating incoming chest")
    movement.set_pos(chestsList[incoming_index].pos.x, chestsList[incoming_index].pos.z)
    chestCache[incoming_index] = updateOneChestCache(incoming_index, chestsList[incoming_index].chest_type) 
    print("Searching for displaced items")
    while true do 
        local found_cargo = false 
        for j, s in pairs(chestCache[incoming_index]) do    
            local itemHash = s.name .. "_" .. s.label   
            if item_cache[itemHash] ~= nil then
                if item_cache[itemHash].chest_index ~= nil then 
                    print("Moving "..s.label.." to proper chest...")                
                    movement.set_pos(chestsList[incoming_index].pos.x, chestsList[incoming_index].pos.z)
                    ic.suckFromSlot(chestSide, j)
                    chestCache[incoming_index][j] = ic.getStackInSlot(chestSide, j)
                    found_cargo = true 
                    break 
                else 
                    print("No chest index in cache for "..itemHash)                
                end
            else 
                print("No cache entry for "..itemHash)
            end 
        end 
        if not found_cargo then return end 
        chests.dropAll();
    end 
    print("Done")
end


function updateOneChestCache(chest_index, chest_type) 
    local r = {}
    local n = ic.getInventorySize(chestSide)
    if n == nil then 
        print("Warning: chest is displaced")
        return 
    end
    for i = 1,n do
        r[i] = ic.getStackInSlot(chestSide, i);
        if r[i] ~= nil then
            local itemHash = r[i].name .. "_" .. r[i].label   
            if item_cache[itemHash] == nil then 
                print("Adding new item to cache: "..itemHash)                
                item_cache[itemHash] = {}
            end 
            item_cache[itemHash].max_size = r[i].maxSize
            if chest_type ~= "incoming" then 
                -- print("Setting chest index") 
                item_cache[itemHash].chest_index = chest_index
            end
        end
        
    end
    return r
end

chests.updateCache = function()
    print("Updating cache...")
    chestCache = {}
    for j = 1, #chestsList do 
        print("Checking chest "..j)
        if chestsList[j].chest_type ~= "outcoming" then 
            movement.set_pos(chestsList[j].pos.x, chestsList[j].pos.z)
            chestCache[j] = updateOneChestCache(j, chestsList[j].chest_type) 
        end
    end 
    save_cache();
end

chests.dropAll = function()
    
    local moved_to_chest = false 
    
    for slot=1,16 do
        if not chests.placeItemsToChest(slot) then
            print("Can't put items into chest");
            computer.beep(1000, 0.7);
        end
    end
    robot.select(1);
    save_cache();
end

chests.countItemInChest = function(stack)
    
    local cnt = 0;
    for i = 1, #chestCache do 
        if chestCache[i] ~= nil then
            for j, s in pairs(chestCache[i]) do
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
            for j, s in pairs(chestCache[i]) do
                if equalThings(s, stack) then
                    movement.set_pos(chestsList[i].pos.x, chestsList[i].pos.z)
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
    local stack = ic.getStackInInternalSlot(srcSlot);
    if stack == nil then return true end 
    
    local itemHash = stack.name .. "_" .. stack.label   
    local chest_index = nil
    if item_cache[itemHash] ~= nil then
        if item_cache[itemHash].chest_index ~= nil then 
            chest_index = item_cache[itemHash].chest_index
            if chest_index < 1 or chest_index > #chestsList then 
                print("Invalid chest index!")
                chest_index = nil
            else 
            end
        else 
            print("No chest index in cache for "..itemHash)      
        end 
    else 
        print("No cache entry for "..itemHash)
        item_cache[itemHash] = {}
    end
    item_cache[itemHash].max_size = stack.maxSize
    if not chest_index then 
        for j = 1, #chestsList do 
            if chestsList[j].chest_type == "incoming" then 
                movement.set_pos(chestsList[j].pos.x, chestsList[j].pos.z)
                chest_index = j
                break 
            end
        end
    end 
    if not chest_index then 
        print("No incoming chest!");
        computer.beep(1000, 0.7);
        return false
    end     
    movement.set_pos(chestsList[chest_index].pos.x, chestsList[chest_index].pos.z)
    

    robot.select(srcSlot);
    local n = ic.getInventorySize(chestSide);
    if n == nil then 
        print("Warning: chest is displaced")
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
    chestsList = v 
end
  

return chests
