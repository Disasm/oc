local component = require("component")

local item_database = require("craft2/item_database")

local r = {}
function r.get_transposers()
  local result = {}
  for address, _ in component.list("transposer", true) do 
    table.insert(result, address)
  end
  return result
end

function r.get_slots_count(transposer, side) 
  return component.invoke(transposer, "getInventorySize", side)
end

function r.get_stack(transposer, side, slot) 
  local result = component.invoke(transposer, "getStackInSlot", side, slot)
  if result then 
    -- filter dangerous fields like "tag"
    return { name = result.name, label = result.label, size = result.size, maxSize = result.maxSize }
  else
    return nil 
  end
end

function r.get_istack(transposer, side, slot) 
  local result = r.get_stack(transposer, side, slot)
  if result then 
    -- filter dangerous fields like "tag"
    local id = item_database.stack_to_id(result)
    if id then 
      return { result.size, id }
    else 
      return { result.size, unknown_stack = result }
    end 
  else
    return { 0 }
  end  
end

function r.transfer(transposer, source_side, sink_side, count, source_slot, sink_slot) 
  if count == nil then count = math.huge end 
  return component.invoke(transposer, "transferItem", source_side, sink_side, count, source_slot, sink_slot)
end
function r.get_items_count(transposer, side, slot) 
  local v = r.get_stack(transposer, side, slot)
  if v then 
    return v.size
  else 
    return 0
  end
end
return r
