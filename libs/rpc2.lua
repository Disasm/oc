rpc = require("libs/rpc")

rpc2 = {}


function rpc2.bind(t)
  local wrapper = {}
  function wrapper.call(objName, funcName, ...)
    local obj = t[objName]
    if obj == nil then
      error("No such object: "..tostring(objName))
    end
    local func = obj[funcName]
    if func == nil then
      error("No such method: "..tostring(objName).."."..tostring(funcName))
    end
    return func(...)
  end

  rpc.bind(wrapper)
end

function rpc2.connect(...)
  local h = rpc.connect(...)
  local wrapper = {_h = h}

  local mt = {
    __index = function(obj, objName)
      local objWrapper = { _h = obj._h, _name = objName }
      local mt2 = {
        __index = function(obj, funcName)
          return function(...)
            return obj._h.call(obj._name, funcName, ...)
          end
        end
      }
      return setmetatable(objWrapper, mt2)
    end
  }
  return setmetatable(wrapper, mt)
end

return rpc2
