local robot = require("robot")
local component = require("component")

local libmine = {}

libmine.item_names = {}
libmine.item_names["laser"]= "IC2:itemToolMiningLaser"
libmine.item_names["treetap"]= "IC2:itemTreetapElectric"
libmine.item_names["chainsaw"]= "IC2:itemToolChainsaw"
libmine.item_names["bone_meal"]= "minecraft:dye"
libmine.item_names["sapling"]= "IC2:blockRubSapling"
libmine.item_names["bone"]= "minecraft:bone"
libmine.item_names["mfe"]= "IC2:blockElectric"
libmine.item_names["crystal"] = "IC2:itemBatCrystal"
libmine.item_names["wrench"] = "IC2:itemToolWrenchElectric"
libmine.item_names["cobble"] = "minecraft:cobblestone"
libmine.item_names["gravel"] = "minecraft:gravel"
libmine.item_names["sand"] = "minecraft:sand"
libmine.item_names["dust"] = "exnihilo:dust"
libmine.item_names["lava_bucket"] = "minecraft:lava_bucket"
libmine.item_names["stick"] = "minecraft:stick"
libmine.item_names["stone_pickaxe"] = "minecraft:stone_pickaxe"
libmine.item_names["stone_hammer"] = "exnihilo:hammer_stone"

local slots_count = robot.inventorySize()
local ic = component.inventory_controller


function libmine.find_slot(name, allow_nil)
  for i = 1, slots_count do
    local stack = ic.getStackInInternalSlot(i)
    if name == "empty" and stack == nil then
      return i
    end
    if stack and stack.name == libmine.item_names[name] then
      return i
    end
  end
  if allow_nil then
    return nil
  else
    error("item not found: "..name)
  end
end

function libmine.find_slots(name)
  local r = {}
  for i = 1, slots_count do
    local stack = ic.getStackInInternalSlot(i)
    if stack and stack.name == libmine.item_names[name] then
      table.insert(r, i)
    end
  end
  return r
end

function libmine.check_equip_safety()
  local stack = ic.getStackInInternalSlot(1)
  if not stack or stack.name ~= libmine.item_names.stick then
    error("Please place safety stick in the first slot!")
  end
  robot.select(1)
end

libmine.last_equipped = nil
function libmine.equip(name)
  if name == libmine.last_equipped then return end
  libmine.last_equipped = name
  local slot = libmine.find_slot(name)
  robot.select(slot)
  if name == "laser" and ic.getStackInInternalSlot(slot).charge < 10000 then
    error("Laser is out of power")
  end
  ic.equip()
  -- libmine.check_equip_safety()
end

libmine.force_forward = function()
  while not robot.forward() do
    os.sleep(0.3)
  end
end

libmine.force_use = function()
  while not robot.use() do
    os.sleep(0.1)
  end
end






return libmine
