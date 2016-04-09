
local module_r = {}
function module_r.create_storage()
  local master = require("craft2/master_main")
  local crafting = require("craft2/crafting")
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
    local loaded_items = {}
    local allow_slot2 = source_chest.role == "machine_output"
    for i = 1, source_chest.slots_count do
      l.dbg("Processing slot "..i)
      if i ~= 2 or allow_slot2 then
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
          loaded_items[stack[2]] = (loaded_items[stack[2]] or 0) + stack[1]
        end
      end
    end
    l.info("Loading items from chest succeeded.")
    return true, loaded_items
  end

  function r.get_stored_item_counts(ids)
    local ids_as_keys = {}
    for _, id in ipairs(ids) do
      ids_as_keys[id] = true
    end
    local result = {}
    for _, chest in ipairs(master.chests) do
      if chest.role == "storage" then
        for i = 3, chest.slots_count do
          local stack = chest.get_istack(i)
          local item_id = stack[2]
          if item_id ~= nil and ids_as_keys[item_id] then
            result[item_id] = (result[item_id] or 0) + stack[1]
          end
        end
      end
    end
    return result
  end

  function r.get_item_real_count(item_id)
    return r.get_stored_item_counts({ item_id })[item_id] or 0
  end

  function r.load_to_chest(sink_chest, sink_slot, item_id, count)
    if not sink_chest then
      error("r.load_to_chest: chest is nil")
    end
    -- todo: select closest and fullest chest
    l.info("test "..l.inspect(count))
    l.dbg(string.format("Loading %d x %d to chest", count, item_id))
    local count_left = count
    for _, chest in ipairs(master.chests) do
      for i = 3, chest.slots_count do
        if chest.role == "storage" then
          local stack = chest.get_istack(i)
          if item_id == stack[2] then
            local current_count = math.min(count_left, stack[1])
            l.dbg(string.format("Transfering %d items from chest %d", current_count, chest.id))
            if not chest.transfer_to(sink_chest, current_count, i, sink_slot) then
              return false, "Transfer failed"
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
    return false, "Not enough items"
  end

  function r.process_output_task(sink_chest, task)
    if task.count_left == nil then
      task.count_left = task.count
    end

    local real_count = r.get_item_real_count(task.item_id)
    local transfer_count = math.min(task.count_left, real_count)
    if transfer_count > 0 then
      local is_ok, msg = r.load_to_chest(sink_chest, nil, task.item_id, transfer_count)
      if is_ok then
        task.count_left = task.count_left - transfer_count
      else
        task.status = "error"
        task.status_message = msg
        return false
      end
    end
    if task.count_left == 0 then
      return true
    else -- not enough items
      if crafting.has_recipe(task.item_id) then
        if not task.craft_requested then
          task.craft_requested = true
          l.info(string.format("Requesting craft of %s", item_db.istack_to_string({ task.count_left, task.item_id })))
          master.add_task({
            name = "craft",
            item_id = task.item_id,
            count = task.count_left,
            priority = task.priority
          })
          task.status = "waiting"
          task.status_message = "Waiting for crafting"
        end
        return false
      else
        -- no crafting recipe
        l.error(string.format("Not enough items. Missing: %s", item_db.istack_to_string({ task.count_left, task.item_id })))
        l.error("Task is discarded.")
        return true
      end
    end

  end

  return r
end
return module_r
