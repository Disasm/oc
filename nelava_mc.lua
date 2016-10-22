local sides = {
  [0] = "bottom", [1] = "top", [2] = "back", [3] = "front", [4] = "right", [5] = "left", [6] = "unknown",
  bottom = 0, top = 1, back = 2, front = 3, right = 4, left = 5, unknown = 6,
  down = 0, up = 1, north = 2, south = 3, west = 4, east = 5,
  negy = 0, posy = 1, negz = 2, posz = 3, negx = 4, posx = 5,
  forward = 3
}

function dump(o)
 if type(o) == 'table' then
  local s = '{ '
  for k,v in pairs(o) do
     if type(k) ~= 'number' then k = '"'..k..'"' end
     s = s .. '['..k..'] = ' .. dump(v) .. ','
  end
  return s .. '} '
 else
  return tostring(o)
 end
end

local transposer = component.proxy(component.list("transposer")())
local r = transposer.getFluidInTank(sides.up)
-- error(dump(r))

local side_one = sides.front
local side_reserve = sides.back
local side_output1 = sides.left
local side_output2 = sides.right
local side_world = sides.down

for _, s in pairs({ side_one, side_reserve, side_output1, side_output2 }) do
  if #transposer.getFluidInTank(s) == 0 then
    error("tank is missing")
  end
end
transposer.transferFluid(side_world, side_one)
transposer.transferFluid(side_one, side_reserve)
if transposer.getFluidInTank(side_reserve)[1].amount == 0 then
  error("no lava")
end

local reserve_capacity = transposer.getFluidInTank(side_reserve)[1].capacity
local max_reserve = reserve_capacity - 1000
local max_output = max_reserve - 1

function transfer(from, to, count)
  while not transposer.transferFluid(from, to, count) do
  end
end

function do_one(side_output)
  while transposer.getFluidInTank(side_reserve)[1].amount < max_reserve do
    transfer(side_reserve, side_one, 1)
    transfer(side_one, side_world)
    transfer(side_world, side_reserve)
  end
  transposer.transferFluid(side_reserve, side_output, max_output)
end

while true do
  do_one(side_output1)
  do_one(side_output2)
end

