local robot = require("robot")
local component = require("component")
local sides = require("sides")
local libmine = require("libmine")
local ic = component.inventory_controller

local args = {...}
local mode = args[1] or "d"
local do_sieve = args[2] ~= "!" and mode ~= "c"

local target_names = { c = "cobble", g = "gravel", s = "sand", d = "dust"}

local mode_names = { c = "Cobblestone", g = "Gravel", s = "Sand", d = "Dust"}
if not mode_names[mode] then
  error("Invalid mode")
end
print("Mode: ".. mode_names[mode])
local target_name = target_names[mode]

local function get_tool()
  print("Tool failure!")
  robot.turnAround()
  libmine.last_equipped = nil
  libmine.equip("empty")
  robot.drop()

  if do_sieve then
    print("Using sieve")
    while true do
      local slot = libmine.find_slot(target_name, true)
      if not slot then break end
      robot.select(slot)
      local count = robot.count(slot) * 16
      ic.equip()
      for i = 1, count do
        robot.useDown()
      end
    end
  end
  print("Dropping everything")
  for i = 1, 16 do
    while robot.count(i) > 0 do
      robot.select(i)
      robot.drop()
    end
  end

  print("Searching for tool")

  local tool
  if mode == "c" then
    tool = "stone_pickaxe"
  else
    tool = "stone_hammer"
  end
  local found = false
  for i = 1, ic.getInventorySize(sides.front) do
    local stack = ic.getStackInSlot(sides.front, i)
    if stack and stack.name == libmine.item_names[tool] then
      if not ic.suckFromSlot(sides.front, i) then
        error("suckFromSlot failed")
      end
      found = true
      ic.equip()
      break
    end
  end
  robot.turnAround()
  if not found then
    error("Tool not found!")
  end
  print("Tool found")
end

local function do_swing(is_final, dir)
  local slot
  if is_final then
    slot = 2
  else
    slot = 1
  end
  robot.select(slot)
  local func
  if dir == "front" then
    func = robot.swing
  elseif dir == "up" then
    func = robot.swingUp
  else
    error("unsupported dir")
  end
  while true do
    local ok, err = func()
    if ok then
      break
    end
    if err == "block" then
      get_tool()
      robot.select(slot)
    end
  end
end

get_tool()
while true do
  do_swing(mode == "c" or mode == "g", "front")
  if mode ~= "c" and mode ~= "g" then
    while not robot.placeUp() do end
    do_swing(mode == "s", "up")
    if mode ~= "s" then
      while not robot.placeUp() do end
      do_swing(true, "up")
    end
  end
end

