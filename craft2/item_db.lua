local module_cache
return function()
  if module_cache then return module_cache end
  local item_db = {}
  module_cache = item_db

  local fser = require("libs/file_serialization")
  local filesystem = require("filesystem")

  function item_db.item_hash(stack)
    return stack.name .. "_" .. stack.label
  end

  function item_db.istack_to_string(istack)
    if istack[1] > 0 then
      local data = item_db.get(istack[2], true)
      return string.format("%d x %s", istack[1], data and data.label or "[INVALID ID]")
    else
      return "empty"
    end
  end

  local db_path = require("craft2/paths").item_db
  local db_last_id_path = db_path .. "last_id"

  local function path_from_id(id)
    return db_path .. "by_id/" .. string.format("%06d", id)
  end

  local function path_from_item_hash(hash)
    return db_path .. "by_hash/" .. string.gsub(hash, "/", "_")
  end

  local last_id = fser.load(db_last_id_path)
  if not last_id then
    last_id = 0
    fser.save(db_last_id_path, last_id)
  end

  local hash_to_id_cache = {}


  function item_db.hash_to_id(hash)
    if hash_to_id_cache[hash] then
      return hash_to_id_cache[hash]
    end
    local v = fser.load(path_from_item_hash(hash))
    hash_to_id_cache[hash] = v
    return v
  end

  function item_db.stack_to_id(stack)
    return item_db.hash_to_id(item_db.item_hash(stack))
  end

  local data_cache = {}

  function item_db.get(id, allow_fail)
    if data_cache[id] then
      return data_cache[id]
    end
    local v = fser.load(path_from_id(id))
    if not v then
      if allow_fail then
        return nil
      else
        error("No such item: "..tostring(id), 2)
      end
    end
    data_cache[id] = v
    hash_to_id_cache[item_db.item_hash(v)] = id
    return v
  end

  function item_db.set(id, data)
    fser.save(path_from_id(id), data)
    data_cache[id] = data
    local hash = item_db.item_hash(data)
    hash_to_id_cache[hash] = id
    fser.save(path_from_item_hash(hash), id)
    if last_id < id then
      last_id = id
      fser.save(db_last_id_path, last_id)
    end
  end

  function item_db.remove(id)
    local stack = item_db.get(id)
    local hash = item_db.item_hash(stack)
    filesystem.remove(path_from_id(id))
    filesystem.remove(path_from_item_hash(hash))
    data_cache[id] = nil
    hash_to_id_cache[hash] = nil
  end

  function item_db.add(data)
    local known_id = item_db.stack_to_id(data)
    local id
    if known_id then
      id = known_id
    else
      last_id = last_id + 1
      fser.save(db_last_id_path, last_id)
      id = last_id
    end
    item_db.set(id, data)
    return id
  end

  function item_db.find_inexact(name)
    name = string.lower(name)

    local ids = {}
    for filename in filesystem.list(db_path .. "by_hash/") do
      if string.lower(filename):find(name) ~= nil then
        local id = fser.load(path_from_item_hash(filename))
        local s = item_db.get(id)
        if string.lower(s.label):find(name) ~= nil then
          ids[#ids+1] = id
        end
      end
    end
    return ids
  end

  return item_db
end
