local rpc = require("libs/rpc2")
local input = require("libcraft/craft_input")
local component = require("component")
local gpu = component.gpu
local text = require("text")
local inspect = require("serialization").serialize
local config = require("craft2/config")
local hosts = require("hosts")

local debugWidth

function debug_print(...)
  local t = table.pack(...)
  if t.n == 0 then
    t = {"\n", n=1}
  end

  local s = tostring(t[1])
  for i = 2,t.n do
    s = s.." "..tostring(t[i])
  end

  local w, h = gpu.getResolution()
  for line in text.wrappedLines(s, debugWidth, debugWidth) do
    gpu.copy(w - debugWidth, 2, debugWidth, h, 0, -1)
    gpu.fill(w - debugWidth, h, debugWidth, 1, " ")
    gpu.set(w - debugWidth, h, line)
  end
end

-- local computer = require("computer")

return { run = function()
  local master = rpc.connect(hosts[config.master]).master

  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")

  debugWidth = math.floor(w * 0.3)

  local wrapper = {
    item_database = require("craft2/item_database"),
    terminal = {
      set_tasks = function(tasks)
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
