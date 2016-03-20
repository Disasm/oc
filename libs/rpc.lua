local component = require("component")
local serialization = require("serialization")
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
  request.n = nil
  request = serialization.serialize(request)
  modem.send(remoteAddress, rpcRequestPort, request)
  local timeout1 = timeout / (retries + 1)
  local nretry = 0
  while true do
    local r = table.pack(event.pull(timeout1, "modem_message", localAddress, remoteAddress, rpcResponsePort))
    if r.n > 0 then
      local result = serialization.unserialize(tostring(r[6]))
      return result
    else
      nretry = nretry + 1
      if nretry > retries then
        break
      end

      -- resend
      modem.send(remoteAddress, rpcRequestPort, request)
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

function rpc.connect(address, timeout, retries, ping_mode)

  modem.open(rpcResponsePort)
  local wrapper = { 
    address = address,
    timeout = timeout or defaultTimeout, 
    retries = retries or defaultRetries,
    ping_mode = ping_mode or "ping_always"
  }
  if wrapper.ping_mode == "ping_once" then 
    if not rpcall(wrapper.address, 1, 1, "ping") then
      error("RPC host unreachable", 2)
    end
  end
  
  mt = {
    __index = function(obj, funcName)
      return function(...)
        if obj.ping_mode == "ping_always" then 
          if not rpcall(obj.address, 1, 1, "ping") then
            error("RPC host unreachable", 2)
          end
        end
        local r = table.pack(rpcall(obj.address, obj.timeout, obj.retries, "c", funcName, ...))
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
    if type(r[1]) == "string" then
      local args = serialization.unserialize(r[1])
      if type(args) == "table" then
        local funcName = tostring(args[1])
        local func = rpcWrapper[funcName]
        if func ~= nil then
          local params = serialization.unserialize(tostring(r[2]))
          local result = {pcall(func, rpcWrapper, table.unpack(args, 2))}
          result = serialization.serialize(result)
          modem.send(pktRemoteAddress, rpcResponsePort, result)
        else
          modem.send(pktRemoteAddress, rpcResponsePort, false, "no such method: "..funcName)
        end
      else
        modem.send(pktRemoteAddress, rpcResponsePort, false, "invalid request")
      end
    else
      modem.send(pktRemoteAddress, rpcResponsePort, false, "invalid request type")
    end
  end
end

event.listen("modem_message", on_modem_message)

return rpc
