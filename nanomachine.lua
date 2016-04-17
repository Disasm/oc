local modem = require("component").modem
local event = require("event")

mt = {
  __index = function(obj, funcName)
    return function(...)
      modem.send(obj.address, 27091, "nanomachines", funcName, ...)
      while true do
        local r = table.pack(event.pull(2, "modem_message"))
        if r.n > 0 then
          if r[3] == obj.address and r[6] == "nanomachines" then
            return table.unpack(r, 8)
          end
        else
          -- resend
          print("Warning: no answer on command "..funcName)
          modem.broadcast(27091, "nanomachines", funcName, ...)
        end
      end
    end
  end
}

function wrap(address)
  local t = {}
  t.address = address
  function t.setInputFast(input, value)
    modem.send(t.address, 27091, "nanomachines", "setInput", input, value)
  end
  setmetatable(t, mt)
  return t
end

local nanomachine = {}
nanomachine.getList = function()
  modem.setStrength(3)
  modem.open(27091)
  modem.broadcast(27091, "nanomachines", "setResponsePort", 27091)
  local machines = {}
  while true do
    local ev = {event.pull(3, "modem_message")}
    if #ev < 5 then
      break
    end
    if ev[5] < 3 and ev[6] == "nanomachines" then
      machines[ev[3]] = ev[5]
    end
  end
  list = {}
  for k,v in pairs(machines) do
    local m = wrap(k)
    m.distance = v
    list[#list+1] = m
  end
  return list
end

nanomachine.find = function()
  list = nanomachine.getList()
  if #list == 0 then
    return nil
  end
  if #list == 1 then
    return list[1]
  end
  minDistance = list[1].distance
  minIndex = 1
  for i=2,#list do
    if list[i].distance < minDistance then
      minDistance = list[i].distance
      minIndex = i
    end
  end
  return list[minIndex]
end

return nanomachine
