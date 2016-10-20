local sides = require("sides")
local transposer = require("component").transposer

local side_one = sides.front
local side_reserve = sides.back
local side_output1 = sides.left
local side_output2 = sides.left
local side_world = sides.down

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

function do_one(output_side)
  transfer(side_reserve, side_one, 1)
  transfer(side_one, side_world)
  transfer(side_world, output_side)
end

function reserve_free_space()
  local info = transposer.getFluidInTank(side_reserve)[1]
  return info.capacity - info.amount
end

transposer.transferFluid(side_one, side_reserve)
while true do
  while reserve_free_space() >= 1000 do
    do_one(side_reserve)
  end
  for i = 1, 500 do
    do_one(side_output1)
    do_one(side_output2)
  end
end
