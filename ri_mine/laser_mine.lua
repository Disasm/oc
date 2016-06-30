local robot = require('robot')
local computer = require('computer')
local component = require('component')
local sides = require('sides')


local names = {}
names["laser"]= "IC2:itemToolMiningLaser"
names["mfe"]= "IC2:blockElectric"
names["crystal"] = "IC2:itemBatCrystal"
names["wrench"] = "IC2:itemToolWrenchElectric"

local slots_count = robot.inventorySize()
local ic = component.inventory_controller

local function find_slot(name, allow_nil)
  for i = 1, slots_count do
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

local mfe_charge_slot = 1 -- charge items
local mfe_discharge_slot = 2 -- discharge items

local function charge_one()
  ic.dropIntoSlot(sides.front, mfe_charge_slot)
  local charge = ic.getStackInSlot(sides.front, mfe_charge_slot).charge
  while true do
    os.sleep(1)
    local new_charge = ic.getStackInSlot(sides.front, mfe_charge_slot).charge
    if new_charge == charge then
      break
    end
    charge = new_charge
  end
  ic.suckFromSlot(sides.front, mfe_charge_slot)
end

local function charge()
  equip("mfe")
  if not robot.use(sides.down) then
    error("robot.use() failed")
  end
  local slots = ic.getInventorySize(sides.front)
  if slots ~= 2 then
    error("mfe inventory not found")
  end
  for _, slot in ipairs(find_slots("crystal")) do
    if ic.getStackInInternalSlot(slot).charge > 0 then
      robot.select(slot)
      ic.dropIntoSlot(sides.front, mfe_discharge_slot)
      break
    end
  end

  robot.select(find_slot("wrench")))
  charge_one()
  robot.select(find_slot("laser")))
  charge_one()

  local empty_found = false
  for i = 1, slots_count do
    if ic.getStackInInternalSlot(i) == nil then
      empty_found = true
      break
    end
  end
  if not empty_found then error("inventory is full") end
  ic.suckFromSlot(sides.front, mfe_discharge_slot)
  charge_one()
  equip("wrench")
  robot.use()
end

equip("laser")
while true do
  robot.useUp()

end


