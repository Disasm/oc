local serialization = require("serialization")
local filesystem = require("filesystem")


local file_serialization = {}

file_serialization.load = function(filename)
  f = filesystem.open(filename, "r")
  if f == nil then return nil end
  local s = ""
  buf = f:read(2048)
  while buf ~= nil do
      s = s .. buf
      buf = f:read(2048)
  end
  f:close()
  return serialization.unserialize(s)
end

file_serialization.save = function(filename, object)
  local f = filesystem.open(filename, "w")
  f:write(serialization.serialize(object))
  f:close()
end

return file_serialization
