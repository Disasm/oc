local file_serialization = require("libs/file_serialization")
local filesystem = require("filesystem")

return { run = function(input_path)
  local item_database = require("craft2/item_database")
  local db_fail_count = 0
  local checked_hashes = {}

  local function check_stack(stack)
    if not stack then
      print("nil stack")
      return true
    end
    local hash = item_database.item_hash(stack)
    if checked_hashes[hash] then return true end
    checked_hashes[hash] = true
    if not item_database.hash_to_id(hash) then
      print(string.format("Missing: %s (%s)", stack.label, stack.name))
      db_fail_count = db_fail_count + 1
      if db_fail_count > 10 then
        return false
      end
    end
    return true
  end

  local success_count = 0
  for input_file in filesystem.list(input_path) do
    data = file_serialization.load(input_path.."/"..input_file)
    if not data then
      print("Error: file load failed: "..input_file)
    else
      success_count = success_count + 1
    end
    if not check_stack(data.to) then goto fail end
    for key, val in pairs(data.from) do
      if not check_stack(val) then goto fail end
    end
  end

  ::fail::
  print(string.format("Successfully processed: %d / 283", success_count))
  -- print(string.format("Successfully imported: %d", success_count))
end }
