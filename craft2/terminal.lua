local rpc = require("libs/rpc2")
local input = require("libcraft/craft_input")
local component = require("component")
local gpu = component.gpu
local text = require("text")
local term = require("term")
local inspect = require("serialization").serialize
local config = require("craft2/config")
local hosts = require("hosts")
local window = require("craft2/window")
local item_database = require("craft2/item_database")

local debugWidth

local logWindow = nil
local taskWindow = nil

function updateTaskList(tasks)
  taskWindow:clear()
  for _,task in pairs(tasks) do
    local color = 0xffffff
    local name = task.name
    if task.name == "output" then
      name = "Output"
    end
    if task.status ~= nil then
      if task.status == "error" then
        color = 0xff3030
      end
    end
    local s = task.id..":"..name
    if task.name == "output" then
      local stack = item_database.get(task.item_id)

      local count = task.count or 0
      local count_left = task.count_left or count

      s = s.." "..count.." x "..stack.label
      if count_left ~= count then
        s = s .. ", left "..count_left
      end
    end
    if task.status_message ~= nil then
      s = s.." ("..task.status_message..")"
    end
    local oldFg = gpu.setForeground(color)
    taskWindow:write(s)
    gpu.setForeground(oldFg)
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

-- local computer = require("computer")

return { run = function()
  term.clear()
  local master = rpc.connect(hosts[config.master]).master

  local w, h = gpu.getResolution()
  debugWidth = math.floor(w * 0.3)
  logWindow = window.create(w - debugWidth+1, 1, debugWidth, h)
  logWindow:clear()
  local consoleHeight = math.floor(h * 0.5)
  term.setViewport(w - debugWidth, consoleHeight, 0, 0)
  taskWindow = window.create(1, consoleHeight+1, w-debugWidth, h-consoleHeight)
  taskWindow:clear()

  local wrapper = {
    item_database = require("craft2/item_database"),
    terminal = {
      set_tasks = function(tasks)
        updateTaskList(tasks)
        debug_print("Tasks: "..inspect(tasks))
      end,
      log_message = function(obj)
        gpu.setForeground(obj.color)
        debug_print(obj.text)
        gpu.setForeground(0xffffff)
      end
    }
  }

  rpc.bind(wrapper)
  print("Welcome to Craft 2 terminal")

  require("craft2/terminal_gui")()

end }
