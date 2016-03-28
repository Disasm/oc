local rpc = require("libs/rpc3")
local hosts = require("hosts")
local inspect = require("serialization").serialize

function pp(text, val)
  print(text.." = "..inspect(val))
end

local x = rpc.connect(hosts.master)
pp("x", x)

pp("x.test4.test4_2", x.test4.test4_2(2, 4))

pp("test5", x.test5())
pp("test7", x.test7("a", "b"))

pp("tricky7", x.tricky7("a", "b"))

pp("tricky8", x.tricky8("a", "b"))

