local sides = require("sides")
local transposer = require("component").transposer

local side_one = sides.front
local side_reserve = sides.back
local side_output = sides.left
local side_world = sides.down

for _, s in pairs({ side_one, side_reserve, side_output }) do
  if transposer.getFluidInTank(side_one) == nil then
    error("tank is missing")
  end
end
transposer.transferFluid(side_one, side_reserve)
local max_reserve = transposer.getFluidInTank(side_reserve)[1].capacity - 1000
while true do
  local output_fluid = transposer.getFluidInTank(side_output)[1]
  if output_fluid.capacity - output_fluid.amount < 1000 then
    os.sleep(1)
  else
    if transposer.getFluidInTank(side_reserve)[1].amount == 0 then
      error("No lava")
    end
    transposer.transferFluid(side_reserve, side_one, 1)
    transposer.transferFluid(side_one, side_world)
    transposer.transferFluid(side_world, side_reserve)
    local output_amount = transposer.getFluidInTank(side_reserve)[1].amount - max_reserve
    if output_amount > 0 then
      transposer.transferFluid(side_reserve, side_output, output_amount)
    end
  end
end
