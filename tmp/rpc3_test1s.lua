local rpc = require("libs/rpc3")

local obj = {
  test1 = 42,
  test2 = "string1",
  test3 = nil,
  test4 = {
    test4_1 = "meow",
    test4_2 = function(arg1, arg2) return arg1 + arg2 end
  },
  test9 = function() return 42, 32, 22 end
}

function obj.test5()
  return "is it ok?"
end

function test6(x, y)
  return "return "..x..", "..y
end

obj.test7 = test6

function tricky_call(val)
  local val2 = val * 2
  obj["tricky"..tostring(val)] = function()
    return val2
  end
end
tricky_call(7)
tricky_call(8)

rpc.bind(obj)

