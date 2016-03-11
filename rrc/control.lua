-- Usage:
-- x = require("rrc/control")

rpc = require("/libs/rpc")
hosts = require("/hosts")
r = rpc.connect(hosts.robot)

result = {}
result.r = r

function result.l()
  r.r_turnLeft()
end
function result.rt()
  r.r_turnRight()
end
function result.u(n)
  if not n then n = 1 end
  for i = 1, n do
    if not r.r_up() then return end
  end
end
function result.d(n)
  if not n then n = 1 end
  for i = 1, n do
    if not r.r_down() then return end
  end
end

function result.f(n)
  if not n then n = 1 end
  for i = 1, n do
    if not r.r_forward() then return end
  end
end
function result.cl(side)
  n = r.ic_getInventorySize(side)
  if not n then print("error"); return end
  for i = 1,n do
    x = r.ic_getStackInSlot(side, i)
    if x then
      print(i, x.label, x.size)
    end
  end
end

return result
