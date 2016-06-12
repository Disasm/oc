local module_cache
return function()
  if module_cache then return module_cache end
  local crafting = {}
  module_cache = crafting

  local item_db = require("craft2/item_db")()
  local item_storage = require("craft2/item_storage")()
  local paths = require("craft2/paths")
  local fser = require("libs/file_serialization")
  local master = require("craft2/master")()
  local filesystem = require("filesystem")

  local function recipes_path(id)
    return string.format("%s%d", paths.recipes, id)
  end

  function crafting.all_craftable_ids()
    local r = {}
    for name in filesystem.list(paths.recipes) do
      table.insert(r, tonumber(name))
    end
    return r
  end


  function crafting.get_machines()
    return {craft=1, Extruder=1, Roller=1, Compressor=1, Furnace=1, Extractor=1, Macerator=1}
  end

  local function max_stack(item_id)
    return item_db.get(item_id).maxSize
  end

  function crafting.process_task(task)
    master.log.error("craft task is not implemented yet")
    return false
  end

  function crafting.has_recipe(item_id)
    return #(crafting.get_recipes(item_id)) > 0
  end

  function crafting.recipe_hash(recipe)
    local item_strings = {}
    for i = 1, 9 do
      if recipe.from[i] then
        table.insert(item_strings, string.format("%d: %s", i, item_db.istack_to_string(recipe.from[i])))
      end
    end
    local from_string = table.concat(item_strings, ", ")
    return string.format("%s(%s)", recipe.machine, from_string)
  end

  function crafting.recipe_readable(recipe)
    local item_strings = {}
    for _, stack in ipairs(recipe.to) do
      table.insert(item_strings, item_db.istack_to_string(stack))
    end
    local to_string = table.concat(item_strings, ", ")
    return string.format("%s -> %s", crafting.recipe_hash(recipe), to_string)
  end

  function crafting.get_recipes(item_id)
    local data = fser.load(recipes_path(item_id))
    if not data then
      data = {}
    end
    return data
  end

  function crafting.add_recipe(item_id, recipe)
    if not crafting.get_machines()[recipe.machine] then
      error("unknown machine in recipe")
    end
    local found_good_output = false
    for _, stack in ipairs(recipe.to) do
      if stack[2] == item_id then
        found_good_output = true
        break
      end
    end
    if not found_good_output then
      error("recipe.to doesn't contain the item")
    end
    local data = crafting.get_recipes(item_id)
    for _, old_recipe in ipairs(data) do
      if crafting.recipe_hash(recipe) == crafting.recipe_hash(old_recipe) then
        master.log.warn("This recipe already existed.")
        return
      end
    end
    table.insert(data, recipe)
    master.log.info(string.format("New recipe added for %s:", item_db.get(item_id).label))
    master.log.info(crafting.recipe_readable(recipe))
    crafting.set_all_recipes(item_id, data)
  end

  function crafting.remove_recipe(item_id, recipe_index)
    local data = crafting.get_recipes(item_id)
    table.remove(data, recipe_index)
    crafting.set_all_recipes(item_id, data)
  end

  local function count_items(ids, reservation)
    local counts = item_storage.get_stored_item_counts(ids)
    for _, id in pairs(ids) do
      local r = reservation[id] or 0
      counts[id] = (counts[id] or 0) - r
      if counts[id] < 0 then
        counts[id] = 0
      end
    end
    return counts
  end

  local function clone_table(reservation)
    local cloned = {}
    for k, v in pairs(reservation) do
      cloned[k] = v
    end
    return cloned
  end

  local function emulate_craft(istack_check, reservation, old_ids)
    master.log.debug(string.format("emulate_craft(%s, %s, %s)", master.log.inspect(istack_check), master.log.inspect(reservation), master.log.inspect(old_ids)))
    if reservation == nil then
      reservation = {}
    else
      reservation = clone_table(reservation)
    end

    if old_ids == nil then
      old_ids = {}
    else
      old_ids = clone_table(old_ids)
    end
    old_ids[istack_check[2]] = true

    -- check for available items
    local id = istack_check[2]
    local needed = istack_check[1]
    local counts = count_items({id}, reservation)
    if counts[id] > 0 then
      local take = math.min(counts[id], needed)
      reservation[id] = (reservation[id] or 0) + take
      needed = needed - take
    end
    if needed == 0 then
      master.log.debug("emulate_craft return (1)")
      return true, reservation, {}
    end
    istack_check = {needed, id}

    -- find related craft recipes
    local related_recipes = crafting.get_recipes(id)

    local filtered_recipes = {}
    for _, recipe in pairs(related_recipes) do
      local remove_recipe = false
      for _, istack in pairs(recipe.from) do
        if old_ids[istack[2]] then
          remove_recipe = true
          break
        end
      end
      if not remove_recipe then
        table.insert(filtered_recipes, recipe)
      end
    end
    related_recipes = filtered_recipes

    if #related_recipes == 0 then
      master.log.error(string.format("Missing items: %s", item_db.istack_to_string(istack_check)))
      return false, reservation, {}
    end

    for recipe_index, recipe in pairs(related_recipes) do
      local n = 0
      for _, istack in pairs(recipe.to) do
        if istack[2] == istack_check[2] then
          n = n + istack[1]
        end
      end
      n = math.ceil(istack_check[1] / n)

      local items_from = {}
      for _, istack in pairs(recipe.from) do
        items_from[istack[2]] = (items_from[istack[2]] or 0) + n * istack[1]
      end

      local ids = {}
      for id, _ in pairs(items_from) do
        ids[#ids+1] = id
      end

      local cloned_reservation = clone_table(reservation)
      local current_crafts = {}
      local ok = true
      for id, needed in pairs(items_from) do
        local result, reservation2, crafts = emulate_craft({needed, id}, cloned_reservation, old_ids)
        cloned_reservation = reservation2
        if result == false then
          ok = false
        else
          for _,v in pairs(crafts) do
            current_crafts[#current_crafts+1] = v
          end
        end
      end

      local craft = {istack_check, recipe_index}
      table.insert(current_crafts, craft)

      if ok then
        master.log.debug("emulate_craft return (3)")
        return true, cloned_reservation, current_crafts
      end
    end

    master.log.debug("emulate_craft return (4)")
    return false, reservation
  end

  local function merge_crafts(crafts)
    local map = {}
    for _, craft in pairs(crafts) do
      local istack = craft[1]
      local recipe_index = craft[2]
      local hash = tostring(istack[2]).."_"..recipe_index

      if map[hash] == nil then
        map[hash] = craft
      else
        map[hash][1][1] = map[hash][1][1] + istack[1]
      end
    end

    local r = {}
    for _, v in pairs(map) do
      r[#r+1] = v
    end
    return r
  end

  function crafting.craft_all_multiple(istacks, priority)
    local reservation
    local all_crafts = {}
    master.log.debug("Calling emulate_craft for each stack.")
    for _, stack in pairs(istacks) do
      local ok, new_reservation, crafts = emulate_craft(stack, reservation)
      if not ok then
        return false
      end
      reservation = new_reservation
      for _, craft in ipairs(crafts) do
        table.insert(all_crafts, craft)
      end
    end
    master.log.debug("Merging crafts.")
    all_crafts = merge_crafts(all_crafts)
    master.log.debug("Adding craft tasks.")
    for _, craft in pairs(all_crafts) do
      local istack = craft[1]
      local recipe_index = craft[2]
      master.add_task({
        name = "craft_one",
        item_id = istack[2],
        count = istack[1],
        priority = priority,
        recipe_index = recipe_index
      })
    end
    return true
  end

  function crafting.craft_all(task)
    return crafting.craft_all_multiple({ {task.count, task.item_id} }, task.priority)
  end

  local function load_items_into_machine(recipe, count, task)
    local one_craft_output = 0
    local total_use_count = 0
    if recipe.to then
      for _, istack in pairs(recipe.to) do
        if istack[2] == task.item_id then
          one_craft_output = one_craft_output + istack[1]
        end
      end
      total_use_count = math.ceil(count / one_craft_output)
    else
      one_craft_output = 1
      total_use_count = 1
    end


    local ids = {}
    local required_counts = {}
    for _, istack in pairs(recipe.from) do
      table.insert(ids, istack[2])
      required_counts[istack[2]] = (required_counts[istack[2]] or 0) + istack[1] * total_use_count
    end
    local counts = item_storage.get_stored_item_counts(ids)
    for _, id in pairs(ids) do
      if not counts[id] or counts[id] < required_counts[id] then
        local missing_stack = { required_counts[id] - (counts[id] or 0), id }
        task.status = "waiting"
        task.status_message = string.format("Missing %s", item_db.istack_to_string(missing_stack))
        return false
      end
    end
    if task.count and task.item_id then
      master.log.info(string.format("Crafting %s", item_db.istack_to_string({ task.count, task.item_id })))
    else
      master.log.info("Crafting unknown items");
    end

    if recipe.machine == "craft" then
      local craft_chest = master.role_to_chest["craft"]
      if not master.crafter or not craft_chest then
        master.log.error("Crafter is not available")
        task.status = "error"
        task.status_message = "Crafter is not available"
        return false
      end
      if not item_storage.load_all_from_chest(craft_chest, task) then
        return false
      end
      local max_crafts_per_use = total_use_count
      local function check_max_craft(stack)
        local stack_max_crafts = math.floor(max_stack(stack[2]) / stack[1])
        if max_crafts_per_use > stack_max_crafts then
          max_crafts_per_use = stack_max_crafts
        end
      end
      for _, stack in pairs(recipe.from) do
        check_max_craft(stack)
      end
      if recipe.to then
        for i, stack in pairs(recipe.to) do
          check_max_craft(stack)
        end
      end
      local use_count_left = total_use_count
      while use_count_left > 0 do
        local current_use_count = math.min(use_count_left, max_crafts_per_use)
        for i, stack in pairs(recipe.from) do
          if not item_storage.load_to_chest(craft_chest, i + 2, stack[2], stack[1] * current_use_count) then
            master.log.error("storage.load_to_chest unexpectedly failed")
            task.status = "error"
            task.status_message = "Unexpected error"
            return false
          end
        end
        master.log.info("Calling crafter")
        if not master.crafter.craft(one_craft_output * current_use_count) then
          master.log.error("Crafter error.")
          task.status = "error"
          task.status_message = "Crafter error"
          return false
        end
        use_count_left = use_count_left - current_use_count
      end
    else
      local machine_chest = master.role_to_chest[recipe.machine]
      if not machine_chest then
        master.log.error("Machine is not available: "..recipe.machine)
        task.status = "error"
        task.status_message = "No machine"
        return false
      end
      for _, istack in pairs(recipe.from) do
        if not item_storage.load_to_chest(machine_chest, nil, istack[2], istack[1] * total_use_count) then
          master.log.error("storage.load_to_chest unexpectedly failed")
          task.status = "error"
          task.status_message = "Unexpected error"
          return false
        end
      end
    end
    task.status = "waiting"
    task.status_message = "Waiting for output"
    task.prepared = true
    task.expected_output = {}
    if recipe.to then
      for _, istack in pairs(recipe.to) do
        task.expected_output[istack[2]] = istack[1] * total_use_count
      end
    end
    return true
  end

  function crafting.craft_one(task)
    if task.prepared then
      local ok, result = master.expect_machine_output(task.expected_output)
      if result then
        for item_id, count in pairs(result) do
          task.expected_output[item_id] = task.expected_output[item_id] - count
        end
        local any_left = false
        for _, count in pairs(task.expected_output) do
          if count > 0 then any_left = true end
        end
        if any_left then
          return false
        else
          master.log.info("Craft completed.")
          return true
        end
      end
    else
      local recipes = crafting.get_recipes(task.item_id)
      if task.recipe_index < 1 or task.recipe_index > #recipes then
        master.log.error(string.format("Invalid recipe index."))
        return true
      end
      local recipe_errors = {}
      local recipe = recipes[task.recipe_index]

      load_items_into_machine(recipe, task.count, task)
      return false
    end
  end

  function crafting.set_all_recipes(item_id, data)
    fser.save(recipes_path(item_id), data)
  end

  function crafting.forget_item(item_id)
    for _, id in ipairs(crafting.all_craftable_ids()) do
      local any_changed = false
      local data = crafting.get_recipes(id)
      local new_data = {}
      for _, recipe in ipairs(data) do
        local recipe_ok = true
        for _, stack in ipairs(recipe.from) do
          if stack[1] > 0 and stack[2] == item_id then
            recipe_ok = false
            break
          end
        end
        for _, stack in ipairs(recipe.to) do
          if stack[1] > 0 and stack[2] == item_id then
            recipe_ok = false
            break
          end
        end
        if recipe_ok then
          table.insert(new_data, recipe)
        else
          any_changed = true
        end
      end
      if any_changed then
        crafting.set_all_recipes(id, new_data)
      end
    end
  end

  function crafting.craft_incomplete_recipe(task)
    if not task.ingredients_craft_requested then
      master.log.debug("Calling craft_all_multiple...")
      if crafting.craft_all_multiple(task.recipe.from) then
        task.ingredients_craft_requested = true
        master.log.debug("craft_all_multiple is successful.")
      end
    end
    if task.prepared then
      master.log.debug("Pulling machine output.")
      local ok, result = master.expect_machine_output(nil)
      if result then
        local any = false
        for id, count in pairs(result) do
          task.output[id] = (task.output[id] or 0) + count
          if count > 0 then
            any = true
          end
        end
        if any then
          master.log.info("")
          master.log.info("Current craft output:")
          for id, count in pairs(task.output) do
            if count ~= 0 then
              master.log.info(item_db.istack_to_string({ count, id }))
            end
          end
          master.log.info("")
        end
      end
    else
      master.log.debug("Checking for other tasks.")
      for i, task2 in ipairs(master.tasks) do
        if task2.name == "craft_one" then
          task.status = "waiting"
          task.status_message = "Waiting for other craftings to finish"
          return false
        end
      end
      master.log.info(string.format("Crafting with new recipe"))
      local ok, result = master.expect_machine_output(nil)
      for id, count in pairs(result) do
        if count > 0 then
          master.log.warn("Bad news: machine output was not empty.")
        end
      end
      load_items_into_machine(task.recipe, 1, task)
      task.output = {}
      return false
    end
  end

  function crafting.get_incomplete_recipe(task)
    if not task.output then
      return false, "Recipe has not been processed yet."
    end
    local recipe = {}
    for key, val in pairs(task.recipe) do
      recipe[key] = val
    end
    recipe.to = {}
    local any = false
    for id, count in pairs(task.output) do
      if count > 0 then
        table.insert(recipe.to, {count, id})
        any = true
      end
    end
    if any then
      return true, recipe
    else
      return false, "Recipe has no output."
    end
  end

  return crafting
end
