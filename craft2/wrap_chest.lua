
local fser = require("libs/file_serialization")

return { wrap_chest = function(chest_id, chest_data) 
  local master = require("craft2/master_main")
  local l = master.log 
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
    if not r.main_transposer and not entry.transposer.interface.modem_address then 
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
  function r.transfer_to(other_chest, count, source_slot, sink_slot)
    local previous_count = r.get_istack(source_slot)[1]
    local target_count = previous_count - count
    local t = r.transposers_for_adjacent_chests[other_chest].id
    if not t then return false end 
    t.transposer.transter(t.side1, t.side2, count, source_slot, sink_slot)
    -- refresh cache for these 2 slots
    r.get_istack(source_slot, true)
    other_chest.get_istack(sink_slot, true)
    return r.get_istack(source_slot)[1] == target_count
  end
  
    
  r.content_cache = fser.load(content_cache_filename)
  if not r.content_cache then 
    l.info("No cache file. Refreshing cache...")
    r.content_cache = {}
    r.refresh_cache()
  end

  function r.find_transposers_for_adjacent_chests() 
    r.transposers_for_adjacent_chests = {}
    for i, chest in ipairs(master.chests) do 
      local found = false 
      for _, item in ipairs(r.transposers) do 
        for _, item2 in ipairs(chest.transposers) do  
          if item.transposer == item2.transposer then 
            local v = { transposer = item.transposer, side1 = item.side, side2 = item2.side }
            r.transposers_for_adjacent_chests[i] = v
            found = true 
            break 
          end
        end 
        if found then break end 
      end
    end
  end

  
  
  function r.find_paths_to_other_chests()
    -- https://ru.wikipedia.org/wiki/%D0%90%D0%BB%D0%B3%D0%BE%D1%80%D0%B8%D1%82%D0%BC_%D0%94%D0%B5%D0%B9%D0%BA%D1%81%D1%82%D1%80%D1%8B
    local vertices_count = #(master.chests)
    local start_vertix = r.id
    local visited_vertices = {}
    local distances = {}
    local paths = {}
    for i = 1, vertices_count do 
      if i == start_vertix then 
        distances[i] = 0
        paths[i] = { i }      
      else
        distances[i] = math.huge
      end 
    end 
    while true do 
      local min_distance = nil 
      local min_distance_vertix = nil 
      for i = 1, vertices_count do 
        if not visited_vertices[i] then 
          if min_distance == nil or distances[i] < min_distance then 
            min_distance = distances[i] 
            min_distance_vertix = i           
          end 
        end 
      end
      if min_distance_vertix == nil then break end 
      visited_vertices[min_distance_vertix] = true 
      for i = 1, vertices_count do 
        if not visited_vertices[i] then 
          local t = master.chests[min_distance_vertix].transposers_for_adjacent_chests[i]
          if t then 
            local cost 
            if t.transposer.interface.modem_address then 
              cost = 4
            else 
              cost = 1
            end 
            local new_distance = min_distance + cost 
            if new_distance < distances[i] then 
              distances[i] = new_distance
              paths[i] = {} 
              if not paths[min_distance_vertix] then 
                error("paths[min_distance_vertix] is nil")
              end 
              for _, item in ipairs(paths[min_distance_vertix]) do 
                table.insert(paths[i], item)
              end 
              table.insert(paths[i], i)
            end 
          end 
        end 
      end 
    end 
    
    --print(string.format("Paths from chest %d", r.id))
    --for i = 1, vertices_count do 
    --  print(string.format("to %d: %s (d=%d)", i, l.inspect(paths[i]), distances[i]))
    --end
    r.paths_to_chests = paths
    r.distances_to_chests = distances
  end
     
  return r
end }
