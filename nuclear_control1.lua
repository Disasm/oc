local timeout = 10
local reactor_slots = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }

local robot = require('robot')
local computer = require('computer')
local component = require('component')
local sides = require('sides')
local event = require('event')


local names = {}
names["wrench"] = "ic2:electric_wrench"
names["reactor"] = "ic2:te"
names["rod"] = "ic2:uranium_fuel_rod"

local slots_count = robot.inventorySize()
local ic = component.inventory_controller
local redstone = component.redstone

local function find_slot(name, allow_nil, from_current)
  local start
  if from_current then
    start = robot.select()
  else
    start = 1
  end
  for i = start, slots_count do
    local stack = ic.getStackInInternalSlot(i)
    if name == "empty" and stack == nil then
      return i
    end
    if stack and stack.name == names[name] then
      return i
    end
  end
  if allow_nil then
    return nil
  else
    error("item not found: "..name)
  end
end

local function find_slots(name)
  local r = {}
  for i = 1, slots_count do
    local stack = ic.getStackInInternalSlot(i)
    if stack and stack.name == names[name] then
      table.insert(r, i)
    end
  end
  return r
end


local function equip(name)
  robot.select(find_slot(name))
  ic.equip()
end

local function place_rod(slot)
  robot.select(find_slot("rod", false, true))
  ic.dropIntoSlot(sides.front, slot, 1)
end

redstone.setOutput(sides.left, 0)
if not find_slot("reactor", true) then
  equip("wrench")
  robot.use()
end

while true do
  equip("empty")
  if computer.energy() < 1000 then
    error("not enough energy for safe nuclear operation")
  end
  if ic.getStackInInternalSlot(find_slot("wrench")).charge < 1000 then
    error("not enough wrench charge for safe nuclear operation")
  end
  equip("reactor")
  if not robot.use(sides.down) then
    error("robot.use() failed")
  end
  robot.select(1)
  for _, i in ipairs(reactor_slots) do
    place_rod(i)
  end
  redstone.setOutput(sides.left, 15)
  local interrupted = event.pull(timeout, "interrupted")
  redstone.setOutput(sides.left, 0)
  equip("wrench")
  robot.use()
  if interrupted then
    print("interrupted")
    break
  end
end


