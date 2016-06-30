local fs = require("libs/file_serialization")
local shell = require("shell")
local event = require("event")
local filesystem = require("filesystem")

function wget(url, path)
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

-- local argv = {...}

local ev = table.pack(event.pull("key_up"))
local username = ev[5]
print("Username: "..username)

local config_path = "/home/.dp/config/" .. username
if not filesystem.exists(config_path) then
  local initial_config = {
    gate = "?",
    download = {
      names = "",
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

local gate_list_file = "/tmp/dp_gate_list"
print("Loading file list...")
wget(config.gate .. "/gate.php?action=list&names="..config.download.names, gate_list_file)
local file_list = fs.load(gate_list_file)
if type(file_list) ~= "table" then
  error("Failed to load file list")
end

local hash_cache_path = "/home/.dp/hash_cache"
local hash_cache = fs.load(hash_cache_path) or {}

local any_updated = false
for _, item in ipairs(file_list) do
  if not hash_cache[item.path] or item.hash ~= hash_cache[item.path] then
    local local_path = item.path
    for from, to in pairs(config.download.mappings) do
      if string.sub(local_path, 1, string.len(from.."/")) == from.."/" then
        local_path = to.."/"..string.sub(local_path, string.len(from.."/") + 1)
        break
      end
    end
    print("Updating file: "..local_path)
    wget(config.gate .. "/files/" .. item.path, local_path)
    hash_cache[item.path] = item.hash
    any_updated = true
  end
end

fs.save(hash_cache_path, hash_cache)

print("Done.")
if any_updated then
  shell.execute("reboot")
end


