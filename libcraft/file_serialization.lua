local serialization = require("serialization")
local filesystem = require("filesystem")


local file_serialization = {}

file_serialization.load = function(filename) 
  f = filesystem.open(filename, "r")
  if f == nil then return nil end
  local s = f:read(10000)
  f:close()
  return serialization.unserialize(s)
end

file_serialization.save = function(filename, object) 
  local f = filesystem.open(filename, "w")
  f:write(serialization.serialize(object))
  f:close()
end

return file_serialization