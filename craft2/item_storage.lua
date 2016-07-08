local module_cache
return function()
  if module_cache then return module_cache end
  local item_storage = {}
  module_cache = item_storage

  local master = require("craft2/master")()
  local crafting = require("craft2/crafting")()

  local item_db = require("craft2/item_db")()

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
    master.log.dbg(string.format("chest=%d score=%d (dist=%d slots=%d e.s.=%d)", sink_chest.id, score, distance, free_slots, existing_space))
    return score
  end

  function item_storage.load_from_chest(source_chest, source_slot, task, loaded_items)
    if source_slot ~= 2 or allow_slot2 then
      master.log.dbg("test1")
      local stack = source_chest.get_istack(source_slot)
      master.log.dbg("test2 "..master.log.inspect(stack))
      if stack[1] > 0 then
        master.log.dbg("stack[1] > 0")
        local max_score = -1
        local max_score_chest
        for j, sink_chest in ipairs(master.chests) do
          master.log.dbg("iterating: chest "..j)
          if sink_chest.role == "storage" then
            master.log.dbg("Calling score_for_adding_items")
            local score = score_for_adding_items(stack, source_chest, sink_chest)
            if score > max_score then
              max_score = score
              max_score_chest = sink_chest
            end
          end
        end
        if not max_score_chest then
          if task then
            task.status = "error"
            task.status_message = "No available chests to store items!"
          end
          master.log.dbg("fail 1")
          return false
        end
        master.log.dbg(string.format("transfer from slot %d into chest %d", source_slot, max_score_chest.id))
        if not source_chest.transfer_to(max_score_chest, stack[1], source_slot, nil) then
          if task then
            task.status = "error"
            task.status_message = "Transfer failed."
          end
          master.log.dbg("fail 2")
          return false
        end
        loaded_items[stack[2]] = (loaded_items[stack[2]] or 0) + stack[1]
      end
    end
    return true, loaded_items
  end

  function item_storage.load_all_from_chest(source_chest, task)
    local loaded_items = {}
    local allow_slot2 = source_chest.role == "machine_output"
    for i = 1, source_chest.slots_count do
      master.log.dbg("Processing slot "..i)
      local r, new_loaded_items = item_storage.load_from_chest(source_chest, i, task, loaded_items)
      if not r then
        return false
      end
      loaded_items = new_loaded_items
    end
    master.log.dbg("Loading items from chest succeeded.")
    return true, loaded_items
  end

  function item_storage.get_stored_item_counts(ids)
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

  function item_storage.get_item_real_count(item_id)
    return item_storage.get_stored_item_counts({ item_id })[item_id] or 0
  end

  function item_storage.load_to_chest(sink_chest, sink_slot, item_id, count)
    if not sink_chest then
      error("r.load_to_chest: chest is nil")
    end
    -- todo: select closest and fullest chest
    master.log.dbg(string.format("Loading %d x %d to chest", count, item_id))
    local count_left = count
    for _, chest in ipairs(master.chests) do
      for i = 3, chest.slots_count do
        if chest.role == "storage" then
          local stack = chest.get_istack(i)
          if item_id == stack[2] then
            local current_count = math.min(count_left, stack[1])
            master.log.dbg(string.format("Transfering %d items from chest %d", current_count, chest.id))
            if not chest.transfer_to(sink_chest, current_count, i, sink_slot) then
              return false, "Transfer failed"
            end
            count_left = count_left - current_count
            if count_left == 0 then
              master.log.dbg("Loading items into chest succeeded.")
              return true
            end
          end
        end
      end
    end
    return false, "Not enough items"
  end

  function item_storage.process_output_task(sink_chest, task)
    if task.counts_left == nil then
      task.counts_left = {}
      if #(task.items) == 0 then
        l.error("Output task: no items requested.")
        return true
      end
      for _, istack in ipairs(task.items) do
        if istack[2] == nil then
          l.error("Output task: invalid item id.")
          return true
        end
        if istack[1] < 1 then
          l.error("Output task: count is not positive enough.")
          return true
        end
        task.counts_left[istack[2]] = istack[1]
      end
    end
    local all_completed = true
    for item_id, count in pairs(task.counts_left) do
      local real_count = item_storage.get_item_real_count(item_id)
      local transfer_count = math.min(count, real_count)
      if transfer_count > 0 then
        local is_ok, msg = item_storage.load_to_chest(sink_chest, nil, item_id, transfer_count)
        if is_ok then
          task.counts_left[item_id] = task.counts_left[item_id] - transfer_count
        else
          task.status = "error"
          task.status_message = msg
          return false
        end
      end
      if task.counts_left[item_id] > 0 then
        all_completed = false
      end
    end
    if all_completed then
      return true
    end
    if not task.craft_requested then
      task.craft_requested = true
      local items = {}
      for item_id, count in pairs(task.counts_left) do
        if count > 0 then
          if crafting.has_recipe(item_id) then
            table.insert(items, { count, item_id })
          else
            -- no crafting recipe
            master.log.error(string.format("Missing uncraftable items: %s", item_db.istack_to_string({ count, item_id })))
            master.log.error("Task is discarded.")
            master.notify(false)
            return true
          end
        end
      end
      local texts = {}
      for _, istack in ipairs(items) do
        table.insert(texts, item_db.istack_to_string(istack))
      end
      master.log.info(string.format("Requesting craft of %s", table.concat(texts, ", ")))
      master.add_task({
        name = "craft",
        items = items,
        priority = task.priority
      })
      task.status = "waiting"
      task.status_message = "Waiting for crafting"
      return false

    end
    return false
  end

  return item_storage
end
