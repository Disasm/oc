
local fser = require("libs/file_serialization")

return { wrap_chest = function(chest_id, chest_data) 
  local master = require("craft2/master_main")
  local r = { 
    id = chest_id,
    role = chest_data.role, 
    slots_count = chest_data.slots_count, 
    transposers = {} 
  }
  r.can_transfer = (r.role == "storage")
  local content_cache_filename = string.format("/home/craft2/content_cache/%03d", r.id)
  local content_cache_modified = false
  
  for i, d in ipairs(chest_data.transposers) do 
    local entry = { transposer = master.transposers[d.transposer_id], side = d.side }
    if not r.main_transposer and not entry.transposer.interface.address then 
      -- first local transposer is assigned as main
      r.main_transposer = entry
    end 
    table.insert(r.transposers, entry)
  end 
  if not r.main_transposer then -- all transposers are remote 
    r.main_transposer = r.transposers[1]
  end
  
  function r.get_stack(slot) 
    if slot < 1 or slot > r.slots_count then 
      error("chest.get_stack: slot out of bounds")
    end
    return r.main_transposer.transposer.get_stack(r.main_transposer.side, slot)
  end
  
  function r.refresh_cache(slot)
    if slot == nil then 
      for i = 1, r.slots_count do 
        r.get_istack(i, true)
      end 
      r.save_cache()
    else 
      r.get_istack(slot, true)
    end 
  end 
  function r.save_cache()
    if content_cache_modified then 
      fser.save(content_cache_filename, r.content_cache)
    end 
  end 
  function r.get_istack(slot, no_cache) 
    if slot < 1 or slot > r.slots_count then 
      error("chest.get_stack: slot out of bounds")
    end
    if no_cache then
      local v = r.main_transposer.transposer.get_istack(r.main_transposer.side, slot)
      v = master.process_istack(v)
      r.content_cache[slot] = v
      content_cache_modified = true 
      return v
    else 
      return r.content_cache[slot]
    end 
  end
  
  
  function r.get_items_count(slot) 
    if slot < 1 or slot > r.slots_count then 
      error("chest.get_stack: slot out of bounds")
    end
    return r.main_transposer.transposer.get_items_count(r.main_transposer.side, slot)  
  end
  function r.find_transposer_for_adjacent_chest(other_chest) 
    for _, item in ipairs(r.transposers) do 
      for _, item2 in ipairs(other_chest.transposers) do 
        if item.transposer == item2.transposer then 
          return { transposer = item.transposer, side1 = item.side, side2 = item2.side }
        end
      end 
    end
    return nil
  end
  function r.transfer_to(other_chest, count, source_slot, sink_slot)
    if count == nil then count = math.huge end 
    local t = r.find_transposer_for_adjacent_chest(other_chest)
    if not t then return false end 
    t.transposer.transter(t.side1, t.side2, count, source_slot, sink_slot)
    r.get_istack(source_slot, true)
    other_chest.get_istack(sink_slot, true)
  end
  
    
  r.content_cache = fser.load(content_cache_filename)
  if not r.content_cache then 
    print("No cache file. Refreshing cache...")
    r.content_cache = {}
    r.refresh_cache()
  end
    
   
  return r
end }
