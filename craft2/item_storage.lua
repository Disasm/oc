
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
      l.dbg("Processing slot "..i)
      if i ~= 2 then
        l.dbg("test1")
        local stack = source_chest.get_istack(i)
        l.dbg("test2 "..l.inspect(stack))
        if stack[1] > 0 then
          l.dbg("stack[1] > 0")
          local max_score = -1
          local max_score_chest = nil
          for j, sink_chest in ipairs(master.chests) do
            l.dbg("iterating: chest "..j)
            if sink_chest.role == "storage" then
              l.dbg("Calling score_for_adding_items")
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
            l.dbg("fail 1")
            return false
          end
          l.dbg(string.format("transfer from slot %d into chest %d", i, max_score_chest.id))
          if not source_chest.transfer_to(max_score_chest, stack[1], i, nil) then
            task.status = "error"
            task.status_message = "Transfer failed."
            l.dbg("fail 2")
            return false
          end
        end
      end
    end
    l.info("Loading items from chest succeeded.")
    return true
  end

  function r.get_stored_item_counts(ids)
    local ids_as_keys = {}
    for _, id in ipairs(ids) do
      ids_as_keys[id] = true
    end
    local result = {}
    for _, chest in ipairs(master.chests) do
      for i = 3, chest.slots_count do
        local stack = chest.get_istack(i)
        local item_id = stack[2]
        if item_id ~= nil and ids_as_keys[item_id] then
          result[item_id] = (result[item_id] or 0) + stack[1]
        end
      end
    end
    return result
  end

  function r.load_to_chest(sink_chest, count, item_id, task)
    if task.count_left == nil then
      task.count_left = count
    end
    -- todo: select closest and fullest chest
    l.dbg(string.format("Loading %d x %d to chest", count, item_id))
    for _, chest in ipairs(master.chests) do
      for i = 3, chest.slots_count do
        if chest.role == "storage" then
          local stack = chest.get_istack(i)
          if item_id == stack[2] then
            local current_count = math.min(task.count_left, stack[1])
            l.dbg(string.format("Transfering %d items from chest %d", current_count, chest.id))
            if not chest.transfer_to(sink_chest, current_count, i, nil) then
              task.status = "error"
              task.status_message = "Transfer failed."
              return false
            end
            task.count_left = task.count_left - current_count
            if task.count_left == 0 then
              l.info("Loading items into chest succeeded.")
              return true
            end
          end
        end
      end
    end

    l.error("Not enough items.")
    return false

  end

  return r
end
return module_r
