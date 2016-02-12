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


function inputMachineCommand() 
    debug("Known machines:")
    for i = 1, #machines do 
        local m = machines[i] 
        debug(i..": "..m.machine_type .. " at ("..m.pos.x..", "..m.pos.z..")")
    end
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
            machines[#machines + 1] = machine
            file_serialization.save('/machines.txt', machines)
            chests.setMachines(machines)
            debug("Machine saved.")
            return
        elseif i == "d" then
            debug("I'm tired of following orders. Just edit the file yourself.")
            return
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

function inputRecipe()
    local bp = nil;
    local rs = nil;
    
    bp = getBlueprint()
    robot.select(16);
    if not crafting.craft(1) then
        bp = nil
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
    
    local recipe = {from=bp, to=rs}
    
    db:add(recipe)
    db:load()
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
            robot.dropUp();
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
                -- do craft
                robot.select(16);
                local ok = crafting.craft(1);
                if not ok then
                    debug("Craft error")
                    return false;
                end
                
                if top then
                    robot.select(16);
                    if cnt > robot.count(16) then
                        robot.dropUp(cnt);
                    else
                        robot.dropUp();
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
    chests.dropAll();
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
end


function r.run_craft() 
    db:init(dataDirectory)
    db:load()
    
    machines = file_serialization.load("/machines.txt")
    if machines == nil then machines = {} end
    chests.setMachines(machines)

    term.clear();
    chests.updateCache();

    term.clear();

    while true do
        debug("");
        debug("");
        debug("What do you want? Select one.");
        debug("a: Add recipe");
        debug("c: Craft");
        debug("m: Move robot");
        debug("M: Edit machines");
        debug("q: Quit");
        while true do
            local i = input.getChar();
            if i == "a" then
                inputRecipe();
                debug("Done.");
                break
            elseif i == "c" then
                if askUser() then
                    debug("Done");
                end
                chests.updateCache();
                break
            elseif i == "m" then
                inputMoveCommand();
                break
            elseif i == "M" then
                inputMachineCommand();
                break
            elseif i == "q" then
                return
            end
        end
    end
end

return r 
