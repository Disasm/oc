local component = require("component")
local filesystem = require("filesystem")
local robot = require("robot")
local term = require("term")
local ic = component.inventory_controller
local crafting = component.crafting
local computer = require("computer")
local db = require("craft_db")
local input = require("craft_input")
local chests = require("craft_chests")
local movement = require("movement")
local file_serialization = require("file_serialization")


local dataDirectory = "/craft";
local craftIndex = {1, 2, 3, 5, 6, 7, 9, 10, 11};
local lastStack = nil;
local logFile = filesystem.open("/log.txt", "a");

local r = {}
local machines = {};


function update_chests_list() 
  local chests1 = {};
  for j = 1, #machines do 
      if machines[j].machine_type == "Chest" then 
          chests1[#chests1 + 1] = machines[j];
      end
  end 
  chests.setChests(chests1);
end


local debug = function(s)
    print(s)
    logFile:write(s)
    logFile:write("\n")
end

function readStackInternal(index)
    local s = ic.getStackInInternalSlot(index)
    return db.createStackFromNative(s)
end

function getBlueprint()
    local stacks = {}
    for i=1,9 do
        stacks[i] = readStackInternal(craftIndex[i]);
    end
    return stacks
end

function listMachines()
    debug("Known machines:")
    for i = 1, #machines do 
        local m = machines[i] 
        debug(i..": "..m.machine_type .. " at ("..m.pos.x..", "..m.pos.z..")")
    end  
end

function inputMachineCommand() 
    listMachines();
    while true do
        debug("")
        debug("a: Add machine")
        debug("d: Delete machine")
        debug("q: Quit")
        local i = input.getChar();
        if i == "a" then
            debug("Enter machine type (empty to exit):");
            local machine_type = input.getString();
            if machine_type == "" then
                debug("Aborted.")
                return
            end
            local x, z = movement.get_pos();
            local machine = { machine_type=machine_type, pos={x=x, z=z} }
            if machine_type == "Chest" then 
                while true do
                    debug("")
                    debug("Select chest type:")
                    debug("s: Storage")
                    debug("i: Incoming")
                    debug("o: Outcoming")
                    debug("q: Quit")
                    local j = input.getChar();
                    if j == "s" then 
                        machine.chest_type = "storage"
                        break
                    elseif j == "i" then
                        machine.chest_type = "incoming"
                        break
                    elseif j == "o" then
                        machine.chest_type = "outcoming"
                        break
                    elseif j == "q" then 
                        debug("Aborted.")
                        return
                    end
                end
            end
            machines[#machines + 1] = machine
            file_serialization.save('/machines.txt', machines)
            update_chests_list()
            debug("Machine saved.")
            if machine_type == "Chest" then 
                chests.updateCache();
            end
            return
        elseif i == "d" then
        
            while true do
                debug("Input machine number:")
                local i = input.getNumber();
                if i == nil then return end
                if i < 1 or i > #machines then 
                    debug("Invalid number.")                    
                else
                    local is_chest = machines[i].machine_type == "Chest"
                    table.remove(machines, i)
                    file_serialization.save('/machines.txt', machines)
                    update_chests_list()
                    debug("Machine removed.")
                    if is_chest then 
                        chests.updateCache()
                    end
                    return
                end
            end
        elseif i == "q" then
            return
        end
    end
  
end



function inputMoveCommand()
  local x, z = movement.get_pos();
  debug("Current position: X = "..x..", Z = "..z)
  debug("Enter new position (empty to exit):")
  debug("X = ?")
  local x = input.getNumber();
  if x == nil then return end 
  debug("Z = ?")
  local z = input.getNumber();
  if z == nil then return end 
  movement.set_pos(x, z)
  debug("Done.")
end


function addRecipe(recipe)
    if db:find(recipe.to) ~= nil then 
          print("")
          print("Recipe for "..(recipe.to.label).." already exists!")
          print("Rewrite? [y/n]")
          if input.waitYesNo() == "n" then
              return
          end
    end 
    db:add(recipe)
    debug("Done.");
end

function inputCraftRecipe()
    local bp = nil;
    local rs = nil;
    
    bp = getBlueprint()
    robot.select(16);
    if not crafting.craft(1) then
        bp = nil
        debug("")
        debug("Insert items for craft into top left slots")
        debug("Press Enter to craft...")
        input.waitForEnter()
        while true do
            bp = getBlueprint()
            robot.select(16);
            if not crafting.craft(1) then
                debug("Craft error");
                debug("Retry? [y/n]")
                if input.waitYesNo() == "n" then
                    bp = nil
                    break
                end
            else
                break
            end
        end
    end
    
    if bp == nil then
        return
    end
    rs = readStackInternal(16);
    debug("Crafted "..rs.size.." x "..rs.label)
    
    local recipe = {recipe_type="craft", from=bp, to=rs}
    
    addRecipe(recipe)
end


function inputMachineRecipe() 
    debug("")
    listMachines();
    debug("");
    debug("Select machine (empty to quit):")
    local machine;
    while true do
        local i = input.getNumber();
        if i == nil then return end
        if i < 1 or i > #machines then 
            debug("Invalid number.")
        end
        machine = machines[i]
        break
    end
    movement.set_pos(machine.pos.x, machine.pos.z)
    
    local slot = 1
    local input_stack = nil 
    while true do 
        input_stack = readStackInternal(slot)
        if input_stack == nil then 
            debug("First slot is empty.")
            debug("Put input resource in the first slot.")
            debug("Retry? [y/n]")
            if input.waitYesNo() == "n" then
                return 
            end
        else 
            robot.select(slot)
            if not robot.dropDown() then 
                debug("DropDown failed.")
                debug("Retry? [y/n]")
                if input.waitYesNo() == "n" then
                    return 
                end
            else 
                break
            end
        end
    end
    while true do 
        debug("Wait for the resource to be processed.")
        debug("y: Suck output from machine")
        debug("n: Abort")
        if input.waitYesNo() == "n" then
            return 
        end
        if not robot.suckDown() then 
            debug("SuckDown failed.")
        else 
            break 
        end
    end
    local output_stack = readStackInternal(slot)
    
    debug("")
    debug("Recipe is ready:")
    debug("")
    debug("Machine type: "..machine.machine_type)
    debug("Input:  "..input_stack.size.." x "..input_stack.label);        
    debug("Output: "..output_stack.size.." x "..output_stack.label);   
    debug("")
    debug("Save? [y/n]")
    if input.waitYesNo() == "n" then
        return 
    end
    local recipe = {recipe_type = "generic_machine", machine_type = machine.machine_type, from = { input_stack }, to = output_stack }
    addRecipe(recipe)
end

function inputRecipe() 
  debug("")
  debug("Add new recipe:")
  debug("c: Craft recipe")
  debug("m: Machine recipe")
  debug("q: Quit")
  while true do
      local i = input.getChar();
      if i == "c" then
          inputCraftRecipe();
          return
      elseif i == "m" then
          inputMachineRecipe();
          return
      elseif i == "q" then
          return
      end
  end
  
end

function equalThings(stack1, stack2) 
    if (stack1 == nil) or (stack2 == nil) then
        return false
    end

    return (stack1.label == stack2.label) and (stack1.name == stack2.name)
end

function craftItem(stack, top)
    debug("Searching for "..stack.size.." x "..stack.label);
    local cnt = chests.countItemInChest(stack)
    if cnt > 0 then
        debug("Found "..cnt.." items in chest")
        if top then
            local take = stack.size;
            if cnt < take then
                take = cnt
            end
            chests.suckItemsFromChest(db.makeStack(stack, take), 16)
            robot.select(16);
            chests.goToOutcomingChest()
            robot.dropDown();
            stack.size = stack.size - take;
            cnt = 0;
        end
    end
    chests.dropAll();
    local cnt = stack.size - cnt
    if cnt <= 0 then
        return true
    else
        local index = db:find(stack)
        if index == nil then
            debug("Craft failed.");
            debug("You need to get: "..cnt.." x "..stack.label);
            return false;
        else
            debug("Crafting "..cnt.." x "..stack.label);
            local r = db:get(index);
            local n = math.ceil(cnt / r.to.size);
            
            local t = {}
            
            for slot, s in pairs(r.from) do
                local found = false
                for i = 1,#t do
                    if equalThings(t[i], s) then
                        t[i].size = t[i].size + s.size
                        found = true
                        break
                    end
                end
                if not found then
                    t[#t+1] = db.makeStack(s, s.size)
                end
            end

            for i=1,#t do
                local s = t[i]
                if not craftItem(db.makeStack(s, s.size * n), false) then
                    return false;
                end
            end
            
            for i=1,n do
                for slot, s in pairs(r.from) do
                    local slot2 = craftIndex[slot];
                    if not chests.suckItemsFromChest(s, slot2) then
                        debug("Can't get items from chest: "..s.size.." x "..s.label)
                        return false
                    end
                end
                if r.recipe_type == "generic_machine" then 
                    local machine_ok = false
                    for j = 1, #machines do                         
                        if machines[j].machine_type == r.machine_type then 
                            movement.set_pos(machines[j].pos.x, machines[j].pos.z)
                            machine_ok = true
                            break
                        end
                    end
                    if not machine_ok then 
                        debug("Machine is missing: "..r.machine_type)
                        return false
                    end                        
                    robot.select(1)
                    if not robot.dropDown() then 
                        debug("DropDown error")
                        return false;
                    end
                    robot.select(16)
                    local stack = nil 
                    while not stack or stack.size < r.to.size do 
                        stack = readStackInternal(16)
                        robot.suckDown()
                    end
                    
                else
                    -- do craft
                    robot.select(16);
                    local ok = crafting.craft(1);
                    if not ok then
                        debug("Craft error")
                        return false;
                    end
                    
                end
                
                cnt = cnt - robot.count(16)
                
                if top then
                    chests.goToOutcomingChest()
                    robot.select(16);
                    if cnt < 0 then
                        robot.dropDown(robot.count(16) + cnt);
                    else
                        robot.dropDown();
                    end
                end

                -- clean slots
                chests.dropAll();
            end
            return true
        end
    end
end

function askUser()
    local ind = nil;
    while true do
        debug("Enter item name (empty to exit):")
        local name = input.getString();
        if name == "" then
            return false
        end
    
        ind = db:findInexact(name)
        if #ind > 0 then
            break
        end
        
        debug("Item not found. Try again.");
    end
    
    if #ind > 1 then
        debug("Select one:");
        for i = 1,#ind do
            local s = db:get(ind[i]).to;
            debug(i..": "..s.label);
        end
        i = input.getNumber();
        if i == nil then
            return false
        end

        if (i < 1) or (i > #ind) then
            debug("Invalid value")
            return false
        end
        ind = ind[i];
    else
        ind = ind[1];
    end
    
    local s = db:get(ind).to;
    debug("Selected: "..s.label);

    debug("Enter item count (enter to cancel):");
    local n = input.getNumber();
    if n == nil then
        return false
    end
    
    chests.dropAll();
    -- chests.updateCache();

    s = db.makeStack(s, n);
    while true do
        local ok = craftItem(s, true);
        if ok then
            print("Crafted "..n.." x "..s.label)
            computer.beep(523, 0.2);
            computer.beep(652, 0.2);
            computer.beep(784, 0.2);
            computer.beep(1046, 0.2);
            break
        end
        
        debug("Retry? [y/n]")
        if input.waitYesNo() == "n" then
            break
        end
        chests.updateCache();
    end
    -- chests.updateCache();
end


function r.run_craft() 
    db:init(dataDirectory)
    db:load()
    
    machines = file_serialization.load("/machines.txt")
    if machines == nil then machines = {} end
    update_chests_list()

    term.clear();
    chests.updateCache();

    term.clear();

    while true do
        debug("");
        debug("");
        debug("What do you want? Select one.");
        debug("a: Add recipe");
        debug("c: Craft");
        debug("g: Move robot");
        debug("m: Edit machines");
        debug("s: Sort incoming");
        debug("q: Quit");
        while true do
            local i = input.getChar();
            if i == "a" then
                inputRecipe();
                break
            elseif i == "c" then
                if askUser() then
                    debug("Done")
                end
                break
            elseif i == "g" then
                inputMoveCommand()
                break
            elseif i == "m" then
                inputMachineCommand()
                break
            elseif i == "s" then
                chests.sortIncoming()
                break
            elseif i == "q" then
                return
            end
        end
    end
end

return r 
