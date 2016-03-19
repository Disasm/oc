local shell = require("shell")
local event = require("event")
local filesystem = require("filesystem")
local serialization = require("serialization")

argv = {...}

filename = "up.cfg"
files = {}

f = filesystem.open(filename, "r")
if f ~= nil then
  local s = f:read(math.huge)
  f:close()
  if s ~= nil then
    files = serialization.unserialize(s)
  end
end

if #argv > 0 then
  files[#files+1] = argv[1]
  f = filesystem.open(filename, "w")
  f:write(serialization.serialize(files))
  f:close()
  return
end

local ev = table.pack(event.pull("key_up"))
local username = ev[5]
print("You are probably "..username)
local url
if username == "Riateche" then
  url = "http://www.idzaaus.org/static/tmp/oc/"
else
  url = "http://42b.ru/oc/tree/"
end

for i = 1, #files do 
  local name = files[i]..".lua"
  shell.execute("rm \""..name.."\"")
  shell.execute("wget \""..url..name.."\" \""..name.."\"")
end
shell.execute("reboot")
