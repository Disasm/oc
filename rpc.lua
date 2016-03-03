local component = require("component")
local event = require("event")
local modem = component.modem

local localAddress = modem.address
local rpcRequestPort = 111
local rpcResponsePort = 112
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
  modem.send(remoteAddress, rpcRequestPort, table.unpack(request))
  local timeout1 = timeout / (retries + 1)
  local nretry = 0
  while nretry < retries do
    local r = table.pack(event.pull(timeout1, "modem_message", localAddress, remoteAddress, rpcResponsePort))
    if r.n > 0 then
      return table.pack(table.unpack(r, 6))
    else
      -- resend
      nretry = nretry + 1
      modem.send(remoteAddress, rpcRequestPort, table.unpack(request))
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

  modem.open(rpcResponsePort)
  local wrapper = { address = address }
  mt = {
    __index = function(obj, funcName)
      return function(...)
        if not rpcall(obj.address, 1, 1, "ping") then
          error("RPC host unreachable", 2)
        end
        local r = table.pack(rpcall(obj.address, timeout, retries, "c", funcName, ...))
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
  modem.open(rpcRequestPort)
  rpcObject = obj
end

function on_modem_message(pktSignal, pktLocalAddress, pktRemoteAddress, pktPort, pktDistance, ...)
  if (pktLocalAddress ~= localAddress) or (pktPort ~= rpcRequestPort) then
    return
  end
  local r = table.pack(...)
  if r.n > 0 then
    local funcName = tostring(r[1])
    local func = rpcWrapper[funcName]
    if func ~= nil then
      local result = table.pack(pcall(func, rpcWrapper, table.unpack(r, 2)))
      modem.send(pktRemoteAddress, rpcResponsePort, table.unpack(result))
    else
      modem.send(pktRemoteAddress, rpcResponsePort, false, "no such method: "..funcName)
    end
  end
end

event.listen("modem_message", on_modem_message)

return rpc
