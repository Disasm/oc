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

function print_list() 
  io.write("Current list: ")
  for i, v in ipairs(files) do 
    io.write(v)
    io.write(" ")
  end
  io.write("\n")
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

function update_one(name) 
  local name_absolute = shell.getWorkingDirectory().."/"..name
  print("Updating "..name_absolute)
  if filesystem.exists(name_absolute) then 
    shell.execute("rm \""..name.."\"")
  end 
  if filesystem.exists(name_absolute) then 
    error("Failed to remove old file")
  end  
  shell.execute("wget \""..url..name.."\" \""..name.."\"")
  if not filesystem.exists(name_absolute) then 
    error("Failed to download file")  
  end
end

function print_usage()
  print("Usage:")
  print("up list     - Print list")
  print("up add path - Add path to list")
  print("up rm path  - Remove path from list")
  print("up up path  - Update specific file")
  print("up          - Update all")
end

if #argv > 0 then
  if argv[1] == "add" then
    if #argv ~= 2 then 
      print_usage()
      return
    end
    table.insert(files, argv[2])
    f = filesystem.open(filename, "w")
    f:write(serialization.serialize(files))
    f:close()
    print("Added!")
    print_list() 
    return
  elseif argv[1] == "rm" then
    if #argv ~= 2 then 
      print_usage()
      return
    end
    for i, v in ipairs(files) do 
      if v == argv[2] then 
        table.remove(files, i)
        print("Removed!")
        break
      end
    end
    f = filesystem.open(filename, "w")
    f:write(serialization.serialize(files))
    f:close()
    print_list() 
    return  
  elseif argv[1] == "list" then
    print_list() 
    return  
  elseif argv[1] == "up" then
    if #argv ~= 2 then 
      print_usage()
      return
    end
    update_one(argv[2])
    return
  else 
    print_usage()
    return
  end
end

for i, file in ipairs(files) do 
  update_one(file)
end
shell.execute("reboot")
