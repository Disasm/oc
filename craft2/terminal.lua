local rpc = require("libs/rpc3")
local component = require("component")
local gpu = component.gpu
local unicode = require("unicode")
local term = require("term")
local inspect = require("serialization").serialize
local window = require("craft2/window")
local item_db = require("craft2/item_db")()
local event = require("event")

local debugWidth

local mainWindow
local logWindow
local taskWindow


function updateTaskList(tasks)
  taskWindow:clear()
  for _,task in pairs(tasks) do
    local color = 0xffffff
    local name = task.name
    if task.name == "output" then
      name = "Output"
    end
    if task.name == "craft" then
      name = "Complex craft"
    end
    if task.name == "craft_one" then
      name = "Craft"
    end
    if task.status == "error" then
      color = 0xff3030
    elseif task.status == "waiting" then
      color = 0xffff30
    elseif task.status == "running" then
      color = 0x30ff30
    end
    local s = task.id..":"..name
    if (task.name == "output") or (task.name == "craft") or (task.name == "craft_one") then
      local items
      if task.name == "craft_one" then
        items = { { task.count or 0, task.item_id } }
      else
        items = task.items
      end
      local texts = {}
      for _, istack in ipairs(items) do
        table.insert(texts, item_db.istack_to_string(istack))
      end
      local count = items[1][1]

      s = s.." "..table.concat(texts, ", ")
      if task.expected_output and task.machine ~= "craft" then
        local count_left
        for item_id, count in pairs(task.expected_output) do
          count_left = count
          break
        end
        local percents = 100 * (count - count_left) / count
        if percents < 0 then percents = 0 end
        percents = math.floor(percents + 0.5)
        s = s .. string.format(", %d%% complete, LEFT: %d",
          percents,
          count_left)
      end
    end
    if task.status_message ~= nil then
      s = s..string.format(": %s", task.status_message)
    end
    local oldFg = gpu.setForeground(color)
    taskWindow:write(s)
    if oldFg then
      gpu.setForeground(oldFg)
    end
  end
end

function debug_print(...)
  local t = table.pack(...)
  if t.n == 0 then
    t = {"\n", n=1}
  end

  local s = tostring(t[1])
  for i = 2,t.n do
    s = s.." "..tostring(t[i])
  end

  logWindow:write(s)
end

function main_print(...)
  local t = table.pack(...)
  if t.n == 0 then
    t = {"\n", n=1}
  end

  local s = tostring(t[1])
  for i = 2,t.n do
    s = s.." "..tostring(t[i])
  end

  mainWindow:write(s)
end

-- local computer = require("computer")

return function(master_interface)
  term.clear()

  local w, h = gpu.getResolution()
  debugWidth = math.floor(w * 0.3)
  logWindow = window.create(w - debugWidth+1, 1, debugWidth, h - 2)
  logWindow:clear()
  local consoleHeight = math.floor(h * 0.5)
  --term.setViewport(w-debugWidth-1, consoleHeight, 0, 0)
  mainWindow = window.create(1, consoleHeight+2, w-debugWidth-1, h-consoleHeight-1)
  mainWindow:clear()
  _G.print = main_print
  taskWindow = window.create(1, 1, w-debugWidth-1, consoleHeight)
  taskWindow:clear()

  for i=1,w-debugWidth do
    gpu.set(i, consoleHeight+1, unicode.char(0x2550))
  end
  for i=1,h do
    gpu.set(w - debugWidth, i, unicode.char(0x2551))
  end
  gpu.set(w - debugWidth, consoleHeight+1, unicode.char(0x2563))

  local wrapper = {
    item_database = require("craft2/item_db")(),
    terminal = {
      set_tasks = function(tasks)
        updateTaskList(tasks)
--        debug_print("Tasks: "..inspect(tasks))
      end,
      log_message = function(obj)
        gpu.setForeground(obj.color)
        debug_print(obj.text)
        gpu.setForeground(0xffffff)
      end,
      notifications = require("craft2/notifications")
    }
  }
  if rpc.is_available then
    rpc.bind(wrapper)
  end
  print("Welcome to Craft 2 terminal")
  local is_local_terminal = true
  if not master_interface then
    is_local_terminal = false
    local rpc = require("libs/rpc3")
    local hosts_ok, hosts = pcall(require, "hosts")
    if not hosts_ok then hosts = {} end
    master_interface = rpc.connect(hosts.master, { timeout = 15 })
  end

  event.timer(1, function() require("craft2/terminal_gui")(master_interface, is_local_terminal) end)
  return wrapper
end
