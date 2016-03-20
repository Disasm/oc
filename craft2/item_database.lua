local fser = require("libs/file_serialization")

function item_hash(stack)
  return stack.name .. "_" .. stack.label 
end

db_path = "/home/craft2/item_db/"
db_last_id_path = db_path .. "last_id"

function path_from_id(id)
  return db_path .. "by_id/" .. string.format("%06d", id)
end

function path_from_item_hash(hash)
  return db_path .. "by_hash/" .. hash 
end


local last_id = fser.load(db_last_id_path)
if not last_id then
  last_id = 0
  fser.save(db_last_id_path, last_id)
end

local hash_to_id_cache = {}

function r.hash_to_id(hash)
  if hash_to_id_cache[hash] then 
    return hash_to_id_cache[hash]
  end
  local v = fser.load(path_from_item_hash(hash))
  hash_to_id_cache[hash] = v
  return v
end

function r.stack_to_id(stack)
  return r.hash_to_id(item_hash(stack))
end

local data_cache = {}

function r.get(id)
  if data_cache[id] then
    return data_cache[id]
  end
  local v = fser.load(path_from_id(id))
  data_cache[id] = v 
  hash_to_id_cache[item_hash(v)] = id
  return v
end

function r.set(id, data) 
  fser.save(path_from_id(id), data)
  data_cache[id] = data
end

function r.add(data)
  last_id = last_id + 1 
  fser.save(path_from_item_hash(item_hash(data)), last_id)
  r.set(last_id, data)
end

return r
