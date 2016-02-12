local serialization = require("serialization")
local filesystem = require("filesystem")


local file_serialization = {}

file_serialization.load = function(filename) {
  f = filesystem.open(filename, "r")
  local s = f:read(10000)
  f:close()
  return serialization.unserialize(s)
}

file_serialization.save = function(filename, object) {
  local f = filesystem.open(filename, "w")
  f:write(serialization.serialize(recipe))
  f:close()
}

return file_serialization