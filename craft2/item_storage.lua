
local module_r = {} 
function module_r.create_storage()
  local master = require("craft2/master_main")
  local l = master.log 
  local r = {}
  
  local item_db = require("craft2/item_database")
  local function max_stack(item_id)
    return item_db.get(item_id).maxStackSize
  end
  
  local function score_for_adding_items(stack, source_chest, sink_chest)
    local distance = source_chest.distances_to_chests[sink_chest.id]
    local free_slots = sink_chest.free_slots_count()
    local existing_space = sink_chest.space_in_existing_slots(stack[2])
    if existing_space > stack[1] then 
      existing_space = stack[1]
      free_slots = free_slots + 1 
    end 
    if free_slots == 0 then 
      return -1000
    end 
    local score = 1000.0
    if free_slots < 3 then 
      score = score - 10
    else 
      score = score + free_slots * 0.1 
    end 
    score = score - distance
    if existing_space > 0 then 
      score = score + 15
    end 
    l.dbg(string.format("chest=%d score=%d (dist=%d slots=%d e.s.=%d)", sink_chest.id, score, distance, free_slots, existing_space))
    return score 
  end 
    
  
  function r.load_all_from_chest(source_chest, task) 
    for i = 1, source_chest.slots_count do 
      local stack = table.unpack(source_chest.get_istack(i))
      if stack[1] > 0 then 
        local max_score = -1
        local max_score_chest = nil
        for _, sink_chest in ipairs(master.chests) do 
          if sink_chest.role == "storage" then 
            local score = score_for_adding_items(stack, source_chest, sink_chest)
            if score > max_score then 
              max_score = score 
              max_score_chest = sink_chest
            end 
          end 
        end 
        if not max_score_chest then 
          task.status = "error"
          task.status_message = "No available chests to store items!"
          return false 
        end 
        l.dbg(string.format("transfer from slot %d into chest %d", i, max_score_chest.id))
        if not source_chest.transfer_to(max_score_chest, stack[1], i, nil) then 
          task.status = "error"
          task.status_message = "Transfer failed."
          return false 
        end 
      end 
    end 
    l.info("Loading items from chest succeeded.")
    return true  
  end 
  
  function r.get_total_count(item_id)
    local result = 0
    for _, chest in ipairs(master.chests) do 
      for i = 3, chest.slots_count do 
        local stack = chest.get_istack(i)
        if item_id == stack[2] then 
          result = result + stack[1]
        end 
      end
    end 
    return result 
  end
  
  function r.load_to_chest(sink_chest, count, item_id, task) 
    -- todo: select closest and fullest chest 
    local count_left = count 
    for _, chest in ipairs(master.chests) do 
      for i = 3, chest.slots_count do 
        local stack = chest.get_istack(i)
        if item_id == stack[2] then 
          local current_count = math.max(count_left, stack[1])
          if not chest.transfer_to(sink_chest, current_count, i, nil) then 
            task.status = "error"
            task.status_message = "Transfer failed."
            return false 
          end 
          count_left = count_left - current_count
          if count_left == 0 then 
            l.info("Loading items into chest succeeded.")
            return true 
          end 
        end 
      end
    end 
  
  end 
  
  return r
end 
return module_r 
