local file_serialization = require("file_serialization")

local tr = {}
local map = nil
local tr_filename = nil

function tr.load(filename)
  tr_filename = filename or "/tr.txt"
  map = file_serialization.load(tr_filename)
  if map == nil then
    map = {}
  end
end

function tr.save()
  file_serialization.save(tr_filename, map, true)
end

function tr.translate(str)
  if map == nil then
    tr.load()
  end
  local t = map[str]
  if t == nil then
    t = str
    map[str] = t
    tr.save()
  end
  return t
end

tr = setmetatable(tr, {
  __call = function(t, str)
    return tr.translate(str)
  end
})

return tr
