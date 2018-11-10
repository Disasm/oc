local internet = require("internet")
local event = require("event")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")

-- run the server by executing the following command in the repository root:
-- python -m CGIHTTPServer 8000
local server_urls = {
  ["Ri"] = "http://home.idzaaus.org:8000/",
  ["disasm"] = "http://0.0.0.0:8000/",
}

local self_update_file = "u.lua"
local self_update_destination = "/home/u"

local function parent_dir(filename)
  pos = filename:reverse():find("/")
  if pos == nil then return nil end
  return filename:sub(1, #filename - pos)
end

local function make_parent_dir(path)
  local dir_path = parent_dir(path)
  if not dir_path then
    error("can't get parent dir for "..path)
  end
  if not filesystem.isDirectory(dir_path) then
    shell.execute(("mkdir -p %s"):format(dir_path))
  end
  if not filesystem.isDirectory(dir_path) then
    error("can't create directory: "..dir_path)
  end
end

local function download_file(library_file)
  local path = _G.updater.user_dir .. library_file
  make_parent_dir(path)
  local file = io.open(path, "w")
  for chunk in internet.request(server_urls[_G.updater.user_name]..library_file) do
    file:write(chunk)
  end
  file:close()
end

local function try_install_file(library_file)
  if _G.updater.index[library_file] then
    local path = _G.updater.user_dir .. library_file
    if not filesystem.exists(path) then
      print("Installing "..library_file)
      download_file(library_file)
    end
  end
end

local function restore_globals()
  package.path = _G.updater.standard_package_path
  _G.updater.enabled = false
end

local function download_index()
  local result = ""
  for chunk in internet.request(server_urls[_G.updater.user_name].."cgi-bin/index.py") do
    result = result .. chunk
  end
  local value, err = serialization.unserialize(result)
  if not value then
    error("invalid index data: " .. err)
  end
  return value
end

local function self_update()
  local ok, err = filesystem.copy(_G.updater.user_dir..self_update_file, self_update_destination)
  if ok then
    print("self update installed (reboot to apply changes)")
  else
    print("self update error: "..err)
  end
end

-- register global state object and override require()
if not _G.updater then
  _G.updater = {}
  _G.updater.standard_require = _G.require
  _G.updater.standard_package_path = package.path
  _G.updater.custom_require = function(library)
    if _G.updater.enabled then
      try_install_file(library .. ".lua")
    end
    return _G.updater.standard_require(library)
  end
  _G.require = _G.updater.custom_require
end

restore_globals() -- in case updater crashes

-- get current user
local key_up_event = table.pack(event.pull(1, "key_up"))
if not key_up_event then
  print("failed to get key up event")
  return
end
local user_name = key_up_event[5]
if not user_name then
  print("failed to get user name from event")
  return
end
if not server_urls[user_name] then
  print("unknown user name: " .. user_name)
end
_G.updater.user_name = user_name
_G.updater.user_dir = "/home/" .. _G.updater.user_name .. "/"

-- get new and old indexes
_G.updater.index = download_index()
local old_index = {}
local index_path = _G.updater.user_dir .. ".index"
local index_file = io.open(index_path, "r")
if index_file then
  local content = index_file:read("*a")
  index_file:close()
  old_index = serialization.unserialize(content)
end


-- update all existing files
try_install_file(self_update_file)
for library_file, new_time in pairs(_G.updater.index) do
  local path = _G.updater.user_dir .. library_file
  local library = library_file:sub(1, #library_file - #".lua")
  package.loaded[library] = nil -- unload old version
  if filesystem.exists(path) then
    if not old_index or not old_index[library_file] or old_index[library_file] ~= new_time then
      print("Updating "..library_file)
      download_file(library_file)
      if library_file == self_update_file then
        self_update()
      end
    end
  end
end

-- save index
make_parent_dir(index_path)
index_file = io.open(index_path, "w")
index_file:write(serialization.serialize(_G.updater.index))
index_file:close()

-- create env file to allow direct file execution
local env_file_path = _G.updater.user_dir .. "env"
if not filesystem.exists(env_file_path) then
  local env_file = io.open(env_file_path, "w")
  env_file:write("package.path = "..serialization.serialize(package.path) .."\n")
  env_file:close()
end


argv = {...}
if #argv > 0 then
  local target_file = argv[1]
  if target_file:sub(-1) == "/" then
    -- install all files in specified directory
    local any_ok = false
    for library_file, _ in pairs(_G.updater.index) do
      if library_file:sub(1, #target_file) == target_file then
        any_ok = true
        try_install_file(library_file)
      end
    end
    if not any_ok then
      print("unknown dir: "..target_file)
    end
  elseif target_file:sub(-4) ~= ".lua" then
    -- install and run specified file
    target_file = target_file .. ".lua"
    if not _G.updater.index[target_file] then
      print("unknown file: "..target_file)
      return
    end
    try_install_file(target_file)

    -- run the file in modified environment
    package.path = package.path .. ";" .. _G.updater.user_dir .. "?.lua"
    _G.updater.enabled = true
    local loaded = assert(loadfile(_G.updater.user_dir .. target_file))
    table.remove(argv, 1)
    loaded(table.unpack(argv))
    restore_globals()
  end
end
