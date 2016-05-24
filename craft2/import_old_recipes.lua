local file_serialization = require("libs/file_serialization")
local filesystem = require("filesystem")

return { run = function(input_path)
  local item_db = require("craft2/item_db")()
  local crafting = require("craft2/crafting")()

--  for _, stack in ipairs(file_serialization.load("/data/item_db_good.txt")) do
--    item_db.add(stack)
--  end

  local function convert_stack(stack)
    local id = item_db.stack_to_id(stack)
    if not id then
      error("item not found in database: "..stack.label)
    end
    return { stack.size, id }
  end

  for input_file in filesystem.list(input_path) do
    local data = file_serialization.load(input_path.."/"..input_file)
    if not data then
      error("file load failed: "..input_file)
    end
    local recipe = {}
    recipe.machine = data.machine_type or "craft"
    recipe.to = { convert_stack(data.to) }
    recipe.from = {}
    for i = 1, 9 do
      if data.from[i] then
        recipe.from[i] = convert_stack(data.from[i])
      end
    end
    crafting.add_recipe(recipe.to[1][2], recipe)
  end

  -- print(string.format("Successfully imported: %d", success_count))
end }
