local fser = require("libs/file_serialization")
local filesystem = require("filesystem")

local r = {}


function r.item_hash(stack)
  return stack.name .. "_" .. stack.label
end

function r.istack_to_string(istack)
  if istack[1] > 0 then
    return string.format("%d x %s", istack[1], r.get(istack[2]).label)
  else
    return "empty"
  end
end

db_path = require("craft2/paths").item_db
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
  return r.hash_to_id(r.item_hash(stack))
end

local data_cache = {}

function r.get(id)
  if data_cache[id] then
    return data_cache[id]
  end
  local v = fser.load(path_from_id(id))
  if not v then error("No such item: "..tostring(id), 2) end
  data_cache[id] = v
  hash_to_id_cache[r.item_hash(v)] = id
  return v
end

function r.set(id, data)
  fser.save(path_from_id(id), data)
  data_cache[id] = data
  local hash = r.item_hash(data)
  hash_to_id_cache[hash] = id
  fser.save(path_from_item_hash(hash), id)
  if last_id < id then
    last_id = id
    fser.save(db_last_id_path, last_id)
  end
end

function r.add(data)
  local known_id = r.stack_to_id(data)
  local id = nil
  if known_id then
    id = known_id
  else
    last_id = last_id + 1
    fser.save(db_last_id_path, last_id)
    id = last_id
  end
  r.set(id, data)
  return id
end

function r.find_inexact(name)
  name = string.lower(name)

  local ids = {}
  for filename in filesystem.list(db_path .. "by_hash/") do
    if string.lower(filename):find(name) ~= nil then
      local id = fser.load(path_from_item_hash(filename))
      local s = r.get(id)
      if string.lower(s.label):find(name) ~= nil then
        ids[#ids+1] = id
      end
    end
  end
  return ids
end

return r
