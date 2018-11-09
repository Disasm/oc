local timeout = 4
local rods_count = 3
--local reactor_slots = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }

local robot = require('robot')
local computer = require('computer')
local component = require('component')
local sides = require('sides')
local event = require('event')


local names = {}
names["wrench"] = "ic2:electric_wrench"
names["reactor"] = "ic2:te"
names["rod"] = "ic2:quad_uranium_fuel_rod"

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

local function check_slot(slot, name)
  local value = ic.getStackInInternalSlot(slot)
  if not value or value.name ~= names[name] then
    error(string.format("slot %d must contain %s", slot, name))
  end
end

local REACTOR_SLOT = 1
local ROD_SLOT_START = 2
local ROD_SLOT_END = ROD_SLOT_START + rods_count - 1
local WRENCH_SLOT = ROD_SLOT_END + 1
local EMPTY_SLOT = WRENCH_SLOT + 1
check_slot(REACTOR_SLOT, "reactor")
for i = ROD_SLOT_START, ROD_SLOT_END do
  check_slot(i, "rod")
end
check_slot(WRENCH_SLOT, "wrench")
if ic.getStackInInternalSlot(EMPTY_SLOT) then
  error(string.format("slot %d must be empty", slot))
end
robot.select(EMPTY_SLOT)
ic.equip()
if ic.getStackInInternalSlot(EMPTY_SLOT) then
  error(string.format("slot %d must be empty (equip slot was not empty", slot))
end

local function charge()
  local mfe_charge_slot = 1
  robot.select(WRENCH_SLOT)
  ic.dropIntoSlot(sides.up, mfe_charge_slot)
  local charge = ic.getStackInSlot(sides.up, mfe_charge_slot).charge
  while true do
    os.sleep(1)
    local new_charge = ic.getStackInSlot(sides.up, mfe_charge_slot).charge
    if new_charge == charge then
      break
    end
    charge = new_charge
  end
  ic.suckFromSlot(sides.up, mfe_charge_slot)
end

while true do
  if computer.energy() < 1000 then
    error("not enough energy for safe nuclear operation")
  end
  if ic.getStackInInternalSlot(WRENCH_SLOT).charge < 1000 then
    charge()
  end
  if ic.getStackInInternalSlot(WRENCH_SLOT).charge < 1000 then
    error("not enough wrench charge for safe nuclear operation")
  end
  robot.select(REACTOR_SLOT)
  ic.equip()
  if not robot.use(sides.down) then
    error("robot.use() failed")
  end
  for i = ROD_SLOT_START, ROD_SLOT_END do
    robot.select(i)
    robot.drop()
  end
  robot.select(WRENCH_SLOT)
  ic.equip()
  robot.select(REACTOR_SLOT)
  redstone.setOutput(sides.right, 15)
  local interrupted = event.pull(timeout, "interrupted")
  robot.use()
  redstone.setOutput(sides.right, 0)
  robot.select(WRENCH_SLOT)
  ic.equip()
  if interrupted then
    print("interrupted")
    break
  end
end


