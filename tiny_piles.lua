local component = require("component")
local sides = require("sides")
local event = require("event")
local ic = component.inventory_controller
local robot = require("robot")
local computer = component.computer
local craft = component.crafting.craft
local serialization = require("serialization")

function inspect(v, text)
  print((text or "")..": "..serialization.serialize(v))
end

function clear()
  for i = 1, 16 do
    if robot.count(i) > 0 then 
      robot.select(i) 
      robot.drop()
    end
  end
end

local side = sides.front

function pull_items(slots, count, target_slot)
  robot.select(target_slot)
  local required_count = count - robot.count(target_slot)
  for i, slot in ipairs(slots) do 
    if required_count <= 0 then 
      return true
    end
    ic.suckFromSlot(side, slot, required_count)
    required_count = count - robot.count(target_slot)
    if required_count <= 0 then 
      return true
    end
  end

  computer.beep()
  print("pull_items failed")
  return false  
end

craft_table_slots = {1, 2, 3, 5, 6, 7, 9, 10, 11}

local process_counter = 0
function process()
  process_counter = process_counter + 1
  print("Process "..tostring(process_counter))
  local counts = {}
  local slots = {}
  local n = ic.getInventorySize(side)
  for i = 1, n do 
    local stack = ic.getStackInSlot(side, i)
    if stack then
      counts[stack.label] = (counts[stack.label] or 0) + stack.size
      if not slots[stack.label] then slots[stack.label] = {} end 
      local cnt = #(slots[stack.label])
      slots[stack.label][cnt + 1] = i
    end
  end
  for label, count in pairs(counts) do
    if string.find(label, "Tiny Pile of") ~= nil then 
      local craft_count = math.floor(count / 9)
      if craft_count > 64 then craft_count = 64 end
      if craft_count > 0 then 
        clear()
        local current_slots = slots[label]
        for i, target_slot in ipairs(craft_table_slots) do 
          if not pull_items(current_slots, craft_count, target_slot) then 
            clear()
            return 
          end
        end
        robot.select(16)
        craft(craft_count)
        robot.drop()
      end
    end
  end
end


event.timer(60, process, math.huge)
process()
