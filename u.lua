local internet = require("internet")
local event = require("event")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")

local server_urls = {}
server_urls["Ri"] = "http://home.idzaaus.org:8000/"
server_urls["disasm"] = "http://0.0.0.0:8000/"

local function strip_filename(filename)
  pos = string.find(string.reverse(filename), "/")
  if pos == nil then return nil end
  return string.sub(filename, 0, string.len(filename) - pos)
end

local function make_parent_dir(path)
  local dir_path = strip_filename(path)
  if not dir_path then
    error("strip_filename failed")
  end
  if not filesystem.isDirectory(dir_path) then
    print("Creating directory "..dir_path)
    shell.execute(string.format("mkdir -p %s", dir_path))
  end
  if not filesystem.isDirectory(dir_path) then
    error("mkdir failed for "..dir_path)
  end
end

local function download_file(library_file)
  local path = "/home/" .. _G.updater.user_name .. "/" .. library_file
  make_parent_dir(path)
  local file = io.open(path, "w")
  for chunk in internet.request(server_urls[_G.updater.user_name]..library_file) do
    file:write(chunk)
  end
  file:close()
end

if not _G.updater then
  _G.updater = {}
  _G.updater.standard_require = _G.require
  _G.updater.standard_package_path = package.path
  _G.updater.custom_require = function(library)
    if _G.updater.enabled then
      _G.require = _G.updater.standard_require
      local library_file = library .. ".lua"
      if _G.updater.index[library_file] then
        local path = "/home/" .. _G.updater.user_name .. "/" .. library_file
        if not filesystem.exists(path) then
          print("Installing "..library_file)
          download_file(library_file)
        end
      end
      _G.require = _G.updater.custom_require
    end
    return _G.updater.standard_require(library)
  end
  _G.require = _G.updater.custom_require
end

argv = {...}
if #argv ~= 1 then
  error("program not specified")
end

local function restore_globals()
  package.path = _G.updater.standard_package_path
  _G.updater.enabled = false
end

if argv[1] == "-c" then
  if _G.updater then
    restore_globals()
  end
  return
end



local key_up_event = table.pack(event.pull("key_up"))
_G.updater.user_name = key_up_event[5]

local function download_index()
  local result = ""
  for chunk in internet.request(server_urls[_G.updater.user_name].."cgi-bin/index.py") do
    result = result .. chunk
  end
  local value, err = serialization.unserialize(result)
  if not value then
    error("can't deserialize: " .. err)
  end
  return value
end

_G.updater.index = download_index()
local old_index = {}
local index_path = "/home/" .. _G.updater.user_name .. "/.index"
local index_file = io.open(index_path, "r")
if index_file then
  local content = index_file:read "*a"
  index_file:close()
  old_index = serialization.unserialize(content)
end
for library_file, new_time in pairs(_G.updater.index) do
  local path = "/home/" .. _G.updater.user_name .. "/" .. library_file

  local library = string.sub(library_file, 0, string.len(library_file) - 4)
  package.loaded[library] = nil

  if filesystem.exists(path) then
    if not old_index or not old_index[library_file] or old_index[library_file] ~= new_time then
      print("Updating "..library_file)
      download_file(library_file)
    end
  end
end
make_parent_dir(index_path)
index_file = io.open(index_path, "w")
index_file:write(serialization.serialize(_G.updater.index))
index_file:close()

package.path = package.path .. ";/home/" .. _G.updater.user_name .. "/?.lua"

local env_file = io.open("/home/" .. _G.updater.user_name .. "/env", "w")
env_file:write("package.path = "..serialization.serialize(package.path) .."\n")
env_file:close()

_G.updater.enabled = true

require(argv[1])
restore_globals()

