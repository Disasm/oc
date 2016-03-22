local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")

local file_serialization = {}

function strip_filename(filename)
  pos = string.find(string.reverse(filename), "/")
  if pos == nil then return nil end 
  return string.sub(filename, 0, string.len(filename) - pos)
end

file_serialization.load = function(filename)
  local f = filesystem.open(filename, "r")
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

file_serialization.save = function(filename, object, add_return)
  local f = filesystem.open(filename, "w")
  if not f then 
    local path = strip_filename(filename)
    if path then 
      shell.execute(string.format("mkdir -p %s", path))
      f = filesystem.open(filename, "w")
    end
  end 
  if not f then 
    error("Failed to write to "..filename)
  end  
  local s = serialization.serialize(object)
  if add_return then 
    s = "return "..s
  end
  f:write(s)
  f:close()
end

return file_serialization
