local robot = require("robot")
local movement = require("libs/movement")
local os = require("os")
local args = {...}

function usage()
  print("Usage: plane_builder <width> <depth> {l|r}")
  print("Pattern 'l':")
  print("###")
  print("###")
  print("  ^")
  print("")
  print("Pattern 'r':")
  print("###")
  print("###")
  print("^  ")
end

if #args ~= 3 then
  usage()
  return
end

local pattern = args[3]
if (pattern ~= "l") and (pattern ~= "r") then
  print("Invalid pattern")
  usage()
  return
end

local x_size = tonumber(args[1])
local z_size = tonumber(args[2])
if (x_size == nil) or (z_size == nil) or (x_size <= 0) or (z_size <= 0) then
  print("Invalid size")
  usage()
  return
end

local amount = x_size * z_size
local cnt = 0
for i=1,robot.inventorySize() do
  cnt = cnt + robot.count(i)
end
if cnt < amount then
  print("Not enough items (need "..amount..")")
  return
end

function tryDig()
  for i=1,3 do
    if robot.swingDown() then
      return
    end
    os.sleep(0.3)
  end
end

local current_slot = 1
robot.select(current_slot)
function select_slot()
  if robot.count(current_slot) > 0 then
    return
  end
  for i=1,robot.inventorySize() do
    if robot.count(i) > 0 then
      current_slot = i
      robot.select(current_slot)
      return
    end
  end
end

movement.reset()
local dx = 1
if pattern == "l" then
  dx = -1
end
local dz = 1


movement.set_pos(0, 1)
for x=0,(x_size-1) do
  for z=1,z_size do
    local z1 = z
    if dz < 0 then
      z1 = z_size - z + 1
    end
    movement.set_pos(x*dx, z1)
    select_slot()
    robot.placeDown()
    --tryDig()
  end

  if x < (x_size-1) then
    local x1, z1 = movement.get_pos()
    movement.set_pos(x1 + dx, z1)
    dz = -dz
  end
end

movement.set_pos(0, 0)
movement.set_dir(0, 1)
