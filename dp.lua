local fs = require("libs/file_serialization")
local shell = require("shell")
local event = require("event")
local filesystem = require("filesystem")

local function wget(url, path)
  if string.sub(path, 1, 1) ~= "/" then
    error("Absolute paths are not allowed")
  end
  if filesystem.exists(path) then
    if not filesystem.remove(path) then
      error("Failed to delete old file")
    end
  end
  fs.create_dirs(path)
  local command = "wget -q '"..url.."' '"..path.."'"
  shell.execute(command)
  if not filesystem.exists(path) then
    error("Failed to download file")
  end
end

local args = {...}

local ev = table.pack(event.pull("key_up"))
local username = ev[5]
print("Username: "..username)

local config_path = "/home/.dp/config/" .. username
if not filesystem.exists(config_path) then
  local initial_config = {
    gate = "?",
    download = {
      names = {},
      mappings = {}
    }
  }
  fs.save(config_path, initial_config)
  print("Please configure dp at "..config_path)
  return
end
local config = fs.load(config_path)
if not config then
  error("Can't load config file.")
end
if config.gate == "?" then
  error("Gate is not configured.")
end



local function map_to_local(path)
  local local_path = path
  for from, to in pairs(config.download.mappings) do
    local prefix = from.."/"
    if string.sub(local_path, 1, string.len(prefix)) == prefix then
      local_path = to.."/"..string.sub(local_path, string.len(prefix) + 1)
      break
    end
  end
  if string.sub(local_path, 1, 1) ~= "/" then
    local_path = "/" .. local_path
  end
  return local_path
end

local function map_to_global(path)
  local global_path = path
  for from, to in pairs(config.download.mappings) do
    local prefix = to.."/"
    if string.sub(global_path, 1, string.len(prefix)) == prefix then
      global_path = from.."/"..string.sub(global_path, string.len(prefix) + 1)
      break
    end
  end
  return global_path
end

local function do_update(global_names, auto_reboot)
  local gate_list_file = "/tmp/dp_gate_list"
  print("Loading file list...")
  wget(config.gate .. "/gate.php?action=list&names="..table.concat(global_names, ","), gate_list_file)
  local file_list = fs.load(gate_list_file)
  if type(file_list) ~= "table" then
    error("Failed to load file list")
  end
  if #file_list == 0 then
    print("No files matching request: "..table.concat(global_names, ","))
    return false
  end

  local hash_cache_path = "/home/.dp/hash_cache"
  local hash_cache = fs.load(hash_cache_path) or {}
  local any_updated = false
  for _, item in ipairs(file_list) do
    local local_path = map_to_local(item.path)
    if not hash_cache[local_path] or item.hash ~= hash_cache[local_path] then
      print("Updating file: "..local_path)
      wget(config.gate .. "/files/" .. item.path, local_path)
      hash_cache[local_path] = item.hash
      any_updated = true
    end
  end
  fs.save(hash_cache_path, hash_cache)
  print("Done.")
  if any_updated and auto_reboot then
    shell.execute("reboot")
  end
  return true
end

local function print_usage()
  print("Usage:")
  print("dp - update all")
  print("dp file1,file2 - add files to update list")
  print("dp -e - edit config")
end

if #args == 0 then
  do_update(config.download.names, true)
elseif #args == 1 then
  if args[1] == "-h" or args[1] == "--help" or args[1] == "/?" then
    print_usage()
  elseif args[1] == "-e" then
    shell.execute("edit "..config_path)
  else
    local local_path = args[1]
    if string.sub(local_path, 1, 1) ~= "/" then
      local_path = shell.getWorkingDirectory()..local_path
    end
    local global_path = map_to_global(local_path)
    local found = false
    for _, name in ipairs(config.download.names) do
      if name == global_path then
        found = true
        break
      end
    end
    if found then
      print("File is already in config: "..global_path)
      return
    end
    if do_update({ global_path }, false) then
      table.insert(config.download.names, global_path)
      fs.save(config_path, config)
      print("File added to config: "..global_path)
    end
  end
else
  print_usage()
end
