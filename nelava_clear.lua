local sides = require("sides")
local transposer = require("component").transposer

local side_one = sides.up
local side_reserve = sides.right
local side_output1 = sides.front
--local side_output2 = sides.front
local side_world = sides.back

for _, s in pairs({ side_one, side_reserve, side_output1, side_output2 }) do
  if transposer.getFluidInTank(side_one) == nil then
    error("tank is missing")
  end
end

function transfer(from, to, count)
  print("transfer", from, to, count)
  while not transposer.transferFluid(from, to, count) do
    os.sleep(1)
  end
  print("transfer ok")
end

for _, s in pairs({ side_one, side_reserve, side_world }) do
  while true do
    local r = transposer.getFluidInTank(s)
    if r == nil or #r == 0 or r[1].amount == 0 then break end
    transfer(s, side_output1)
  end
end
