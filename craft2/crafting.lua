local module_r = {}

local db = require("craft2/item_database")
local paths = require("craft2/paths")
local fser = require("libs/file_serialization")


function module_r.process_task(task)
  local master = require("craft2/master_main")
  local l = master.log

  l.error("craft task is not implemented yet")
  return false



end

function module_r.has_recipe(item_id)
  return #(module_r.get_recipes(item_id)) > 0
end

function module_r.recipe_hash(recipe)
  local item_strings = {}
  for i = 1, 9 do
    if recipe.from[i] then
      table.insert(item_strings, string.format("%d: %s", i, db.istack_to_string(recipe.from[i])))
    end
  end
  local from_string = table.concat(item_strings, ", ")
  return string.format("%s(%s)", recipe.machine, from_string)
end

function module_r.recipe_readable(recipe)
  local item_strings = {}
  for _, stack in ipairs(recipe.to) do
    table.insert(item_strings, db.istack_to_string(stack))
  end
  local to_string = table.concat(item_strings, ", ")
  return string.format("%s -> %s", module_r.recipe_hash(recipe), to_string)
end

function module_r.get_recipes(item_id)
  local data = fser.load(paths.recipes(item_id))
  if not data then
    data = {}
  end
  return data
end

local known_machines = {craft=1, Extruder=1, Roller=1, Compressor=1, Furnace=1, Extractor=1, Macerator=1}

function module_r.add_recipe(item_id, recipe)
  local l = require("craft2/master_main").log
  if not known_machines[recipe.machine] then
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
  local data = module_r.get_recipes(item_id)
  for _, old_recipe in ipairs(data) do
    if module_r.recipe_hash(recipe) == module_r.recipe_hash(old_recipe) then
      l.warn("This recipe already existed.")
      return
    end
  end
  table.insert(data, recipe)
  l.info(string.format("New recipe added for %s:", db.get(item_id).label))
  l.info(module_r.recipe_readable(recipe))
  fser.save(paths.recipes(item_id), data)
end

function module_r.craft_one(task)
  local item_db = require("craft2/item_database")
  local recipes = module_r.get_recipes(task.item_id)
  local master = require("craft2/master_main")
  local l = master.log
  if task.prepared then
    local ok, result = master.expect_machine_output({ [task.item_id]=task.expected_count })
    if result then
      task.expected_count = task.expected_count - (result[task.item_id] or 0)
      if task.expected_count == 0 then
        l.info("Craft completed.")
        return true
      else
        return false
      end
    end
  else
    l.info(string.format("Crafting %s", item_db.istack_to_string({ task.count, task.item_id })))
    if #recipes == 0 then
      l.error(string.format("No crafting recipe for %s.", item_db.get(task.item_id).label))
      return true
    end
    local recipe_errors = {}
    local selected_recipe = nil
    local selected_use_count = nil
    for _, recipe in ipairs(recipes) do
      local one_craft_output = 0
      for _, istack in pairs(recipe.to) do
        if istack[2] == task.item_id then
          one_craft_output = one_craft_output + istack[1]
        end
      end
      local recipe_use_count = math.ceil(task.count / one_craft_output)
      local recipe_ok = true
      local ids = {}
      local required_counts = {}
      for _, istack in pairs(recipe.from) do
        table.insert(ids, istack[2])
        required_counts[istack[2]] = (required_counts[istack[2]] or 0) + istack[1] * recipe_use_count
      end
      local counts = master.item_storage.get_stored_item_counts(ids)
      for _, id in pairs(ids) do
        if not counts[id] or counts[id] < required_counts[id] then
          recipe_ok = false
          local missing_stack = { required_counts[id] - (counts[id] or 0), id }
          table.insert(recipe_errors, string.format("Missing required item: %s", item_db.istack_to_string(missing_stack)))
          break
        end
      end
      if recipe_ok then
        selected_recipe = recipe
        selected_use_count = recipe_use_count
        break
      end
    end
    if not selected_recipe then
      if #recipe_errors == 1 then
        l.error(recipe_errors[1])
      else
        l.error("All recipes are not available:");
        for i, err in recipe_errors do
          l.error(string.format("%d: %s", i, err))
        end
      end
      task.status = "error"
      task.status_message = "Missing items"
      return false
    end
    if selected_recipe.machine == "craft" then
      if not master.item_storage.load_all_from_chest(master.role_to_chest["craft"], task) then
        return false
      end
      for i = 1, 9 do
        local stack = selected_recipe.from[i]
        if stack then
          if not master.item_storage.load_to_chest(master.role_to_chest["craft"], i + 2, stack[2], stack[1] * selected_use_count) then
            l.error("storage.load_to_chest unexpectedly failed")
            task.status = "error"
            task.status_message = "Unexpected error"
            return false
          end
        end
      end
      master.crafter.craft(task.count)
    else
      for _, istack in pairs(selected_recipe.from) do
        if not master.item_storage.load_to_chest(master.role_to_chest[selected_recipe.machine], nil, istack[2], istack[1] * selected_use_count) then
          l.error("storage.load_to_chest unexpectedly failed")
          task.status = "error"
          task.status_message = "Unexpected error"
          return false
        end
      end
    end
    task.status = "waiting"
    task.status_message = "Waiting for output"
    task.prepared = true
    task.expected_count = task.count
    return false
  end
end

return module_r
