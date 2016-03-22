rpc2 = require("libs/rpc2")
input = require("libcraft/craft_input")
component = require("component")
gpu = component.gpu
text = require("text")
inspect = require("serialization").serialize 

w, h = gpu.getResolution()
gpu.fill(1, 1, w, h, " ")

debugWidth = math.floor(w * 0.3)
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

wrapper = {
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

rpc2.bind(wrapper)
print("Welcome to Craft 2 terminal")
