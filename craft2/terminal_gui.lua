local input = require("libcraft/craft_input")
local db = require("craft2/item_database")
local filesystem = require("filesystem")
local util = require("libs/stack_util")
local serialization = require("serialization")
local term = require("term")
local shell = require("shell")
local gpu = require("component").gpu

local master = nil
local master_enqueue = function(cmd)
  print("master.enqueue_command("..serialization.serialize(cmd)..")")
end

local logFile = filesystem.open("/log.txt", "a")
local oldPrint = print
local print = function(...)
  oldPrint(...)
  if logFile ~= nil then
    local t = table.pack(...)
    for i = 1,t.n do
      if i > 1 then
        logFile:write(" ")
      end
      logFile:write(t[i])
    end
    logFile:write("\n")
  end
end

function inputItem(onlyPresent)
  local ids = nil
  local counts = nil
  while true do
    print("Enter item name (empty to exit):")
    local name = input.getString()
    if name == "" then
      return
    end

    ids = db.find_inexact(name)

    counts = master.get_stored_item_counts(ids)
    if onlyPresent then
      local i = 1
      while i <= #ids do
        local count = counts[ids[i]] or 0
        if count == 0 then
          counts[ids[i]] = nil
          table.remove(ids, i)
        else
          i = i + 1
        end
      end
    end

    if #ids > 0 then
      break
    end

    print("Item not found. Try again.")
  end

  local id = nil
  if #ids > 1 then
    print("Select one:");
  end
  for i = 1,#ids do
    local s = db.get(ids[i])
    local count = counts[ids[i]] or 0

    local oldFg = gpu.getForeground()
    if count == 0 then
      gpu.setForeground(0xffff30)
    else
      gpu.setForeground(0x30ff30)
    end
    print(i..": "..s.label.." ("..count..")")
    gpu.setForeground(oldFg)
  end
  if #ids > 1 then
    i = input.getNumber()
    if i == nil then
      return
    end

    if (i < 1) or (i > #ids) then
      print("Invalid value")
      return
    end
    id = ids[i]
  else
    id = ids[1]
  end

  local s = db.get(id)
  if #ids > 1 then
    print("Selected: "..s.label)
  end

  local n = nil
  while true do
    print("Enter item count (enter to cancel):")
    n = input.getNumber()
    if n == nil then
      return
    end
    if (onlyPresent and n > counts[id]) or (n < 1) then
      print("Invalid count.")
    else
      break
    end
  end

  return id, n, s
end

function getItemsDialog(craftIfNeeded)
  local id, n, s = inputItem(not craftIfNeeded)
  if id ~= nil then
    master_enqueue({action="add_task", task={name="output", item_id=id, count=n}})
  end
end

function cleanIncoming()
  master_enqueue({action="add_task", task={name="incoming"}})
end

function killTask()
  print("Enter task ID (enter to cancel):")
  local id = input.getNumber()
  if id == nil then
    return
  end
  master_enqueue({action="remove_task", task_id=id})
end

return function()
  local isEmulator = require("libs/emulator").isEmulator
  if not isEmulator then
    local rpc = require("libs/rpc2")
    local hosts = require("hosts")
    local h = rpc.connect(hosts.master)
    master = h.master
    master_enqueue = h.master.enqueue_command
  end

  while true do
    print("")
    print("")
    print("What do you want? Select one.")
    print("g: Get items")
    print("c: Get items or craft")
    print("i: Clean incoming")
    print("k: Kill task")
    print("u: Update")
    print("r: Reboot master server");
    print("q: Quit")
    while true do
      local ch = input.getChar()
      if ch == "g" then
        getItemsDialog(false)
        break
      end
      if ch == "c" then
        getItemsDialog(true)
        break
      end
      if ch == "i" then
        cleanIncoming()
        break
      end
      if ch == "k" then
        killTask()
        break
      end
      if ch == "u" then
        shell.execute("up")
      end
      if ch == "r" then
        master_enqueue({action="quit", reboot=true})
      end
      if ch == "q" then
        return
      end
    end
  end
end
