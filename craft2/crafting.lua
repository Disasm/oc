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
  return false
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


return module_r
