local sides = require("sides")
local component = require("component")

local side_one = sides.front
local side_reserve = sides.back
local side_output1 = sides.left
local side_output2 = sides.right
local side_world = sides.down



local reserve_capacity = component.transposer.getFluidInTank(side_reserve)[1].capacity
local max_reserve = reserve_capacity - 1000
local max_output = reserve_capacity - 1

for address, _ in component.list("transposer") do
  local transposer = component.proxy(address)

  for _, s in pairs({ side_one, side_reserve, side_output1, side_output2 }) do
    if #transposer.getFluidInTank(s) == 0 then
      error("tank is missing")
    end
    transposer.transferFluid(side_one, side_reserve)
  end

  if transposer.getFluidInTank(side_reserve)[1].amount == 0 then
    error("No lava")
  end
end

function do_one(transposer, side_output)
  while transposer.getFluidInTank(side_reserve)[1].amount < max_reserve do
    transposer.transferFluid(side_reserve, side_one, 1)
    transposer.transferFluid(side_one, side_world)
    transposer.transferFluid(side_world, side_reserve)
  end
  transposer.transferFluid(side_reserve, side_output, max_output)
end

while true do
  for address, _ in component.list("transposer") do
    local transposer = component.proxy(address)
    do_one(transposer, side_output1)
    do_one(transposer, side_output2)
  end
end
