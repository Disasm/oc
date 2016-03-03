local component = require("component")
local event = require("event")
local modem = component.modem

local localAddress = modem.address
local rpcPort = 111
local defaultTimeout = 5
local defaultRetries = 4

local rpcObject = nil
local rpcWrapper = {
  ping = function(self)
    return true
  end,

  isReady = function(self)
    return rpcObject ~= nil
  end,

  c = function(self, funcName, ...)
    if rpcObject == nil then
      error("RPC object is not ready", 2)
    else
      local func = rpcObject[funcName]
      if func == nil then
        error("RPC object does not contain function "..tostring(funcName), 2)
      end
      return func(...)
    end
  end,
}


local rpc = {}

function transact(remoteAddress, request, timeout, retries)
  modem.send(remoteAddress, rpcPort, table.unpack(request))
  local timeout1 = timeout / (retries + 1)
  local nretry = 0
  while nretry < retries do
    local r = table.pack(event.pull(timeout1, "modem_message", localAddress, remoteAddress))
    if r.n > 0 then
      return table.pack(table.unpack(r, 6))
    else
      -- resend
      nretry = nretry + 1
      modem.send(remoteAddress, rpcPort, table.unpack(request))
    end
  end
end

function rpcall(remoteAddress, timeout, retries, method, ...)
  local r = transact(remoteAddress, table.pack(method, ...), timeout, retries)
  if r == nil then
    return false, "RPC transaction failed"
  end
  return table.unpack(r)
end

function rpc.connect(address, timeout, retries)
  local timeout = timeout or defaultTimeout
  local retries = retries or defaultRetries

  modem.open(rpcPort)
  local wrapper = { address = address }
  mt = {
    __index = function(obj, funcName)
      return function(...)
        if not rpcall(obj.address, 1, 1, "ping") then
          error("RPC host unreachable", 2)
        end
        local r = table.wrap(rpcall(obj.address, timeout, retries, "c", funcName, ...))
        if r[1] == false then
          error(r[2], 2)
        end
        return table.unpack(r, 2)
      end
    end
  }
  return setmetatable(wrapper, mt)
end

function rpc.bind(obj)
  modem.open(rpcPort)
  rpcObject = obj
end

function rpc.pull()
  while true do
    local r = table.pack(event.pull("modem_message", localAddress))
    if r.n > 0 then
      local funcName = tostring(r[6])
      local func = rpcWrapper[funcName]
      if func ~= nil then
        local args = pcall(func, rpcWrapper, table.unpack(r, 7))
      else
        modem.send(r[3], rpcPort, false, "no such method: "..funcName)
      end
    end
  end
end

return rpc
