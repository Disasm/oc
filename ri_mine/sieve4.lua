local robot = require("robot")
local component = require("component")
local sides = require("sides")
local libmine = require("libmine")
local ic = component.inventory_controller
local craft = component.crafting.craft
local metals = { "iron", "gold", "copper", "tin", "silver", "lead", "nickel", "platinum" }
local ore_names = {}
for i = 1, 5 do ore_names[i] = {} end
for _, metal in pairs(metals) do
  table.insert(ore_names[1], "exnihilo:exnihilo."..metal.."_broken")
  table.insert(ore_names[2], "exnihilo:"..metal.."_gravel")
  table.insert(ore_names[3], "exnihilo:exnihilo."..metal.."_crushed")
  table.insert(ore_names[4], "exnihilo:"..metal.."_sand")
  table.insert(ore_names[5], "exnihilo:exnihilo."..metal.."_powdered")
end
local work_modes = {
  fg = "from gravel: max ores + diamond, emerald, coal, lapis lazuli, flint",
  fs = "from sand: medium ores + yellorium, some seeds",
  fd = "from dust: low ores + redstone, glowstone, bone meal, blaze powder, gunpowder",
  c = "cobblestone", g = "gravel", s = "sand", d = "dust" }
local args = {...}
local mode = args[1]
if not mode or not work_modes[mode] then
  print("Available modes:")
  for k, v in pairs(work_modes) do print(string.format("  %s: %s", k, v)) end
  return
end
print("Mode: "..work_modes[mode])
print("Searching for chest")
local found_chest = false
for i = 1, 4 do
  local slot = ic.getStackInSlot(sides.front, 1)
  if slot and slot.label == "Stick" then
    found_chest = true
    break
  end
  robot.turnRight()
end
if not found_chest then
  print("Chest not found! Place the distinction stick in the 1st slot of the non-final chest.")
  return
end
local chest_slots = ic.getInventorySize(sides.front)
local robot_slots = robot.inventorySize()
local function detect_action(name, count, emulate)
  if name == libmine.item_names["gravel"] then
    if mode == "fg" or mode == "c" then
      return "sift", "Sifting gravel"
    elseif mode == "g" then
      return nil
    else
      return "hammer", "Hammering gravel"
    end
  end
  if name == libmine.item_names["sand"] then
    if mode == "fs" then
      return "sift", "Sifting sand"
    elseif mode == "s" then
      return nil
    else
      return "hammer", "Hammering sand"
    end
  end
  if name == libmine.item_names["dust"] then
    return "sift", "Sifting dust"
  end
  for stage = 1, 5 do
    for j = 1, #ore_names[stage] do
      if ore_names[stage][j] == name then
        if stage == 1 or stage == 3 or stage == 5 then
          if count > 3 or emulate then
            return "craft", "Crafting ore blocks"
          else
            return nil
          end
        else
          return "hammer", "Hammering ore blocks"
        end
      end
    end
  end
  return nil
end
local function empty_inventory()
  print("Emptying inventory")
  local turned_to_final = false
  for i = 1, robot_slots do
    for try = 1, 3 do
      local stack = ic.getStackInInternalSlot(i)
      if not stack then break end
      if detect_action(stack.name, stack.size, true) then
        if turned_to_final then
          robot.turnRight()
          turned_to_final = false
        end
      else
        if not turned_to_final then
          robot.turnLeft()
          turned_to_final = true
        end
      end
      robot.select(i)
      robot.drop()
    end
    if robot.count(i) > 0 then
      error("Emptying inventory failed!")
    end
  end
  if turned_to_final then
    robot.turnRight()
    turned_to_final = false
  end
  robot.select(1)
  ic.equip()
  robot.drop()
  if robot.count(1) > 0 then
    error("Emptying inventory failed!")
  end
end

local main_tool
if mode == "c" then
  main_tool = "stone_pickaxe"
else
  main_tool = "stone_hammer"
end
empty_inventory()
--print("Counting tools")
--local total_tools = 0
--for i = 1, chest_slots do
--  local stack = ic.getStackInSlot(sides.front, i)
--  if stack and stack.name == libmine.item_names[main_tool] then
--    total_tools = total_tools + 1
--  end
--end
--if total_tools == 0 then
--  print(string.format("No tools found (%s)", main_tool))
--  return
--end
--print(string.format("Tools count: %d (%s)", total_tools, main_tool))
local function get_tool(tool)
  robot.select(1)
  for i = 1, chest_slots do
    local stack = ic.getStackInSlot(sides.front, i)
    if stack and stack.name == libmine.item_names[tool] then
      if not ic.suckFromSlot(sides.front, i) then
        print("suckFromSlot failed")
      end
      found = true
      ic.equip()
      return true
    end
  end
  print(string.format("Failed to find tool (%s)", tool))
  return false
end
local force_all = true
while true do
  while true do
    print("Processing resources")
    local any_action = false
    for chest_slot = 1, chest_slots do
      local stack = ic.getStackInSlot(sides.front, chest_slot)
      if stack then
        if stack.size == 64 or force_all then
          local action, msg = detect_action(stack.name, stack.size, false) -- can be "hammer", "sift", "craft"
          if action then
            print(msg)
            any_action = true
            if action == "sift" then
              robot.select(1)
              if not ic.suckFromSlot(sides.front, chest_slot) then
                print("suckFromSlot failed")
              end
              local count = robot.count(1) * 16
              ic.equip()
              for i = 1, count do
                robot.useDown()
              end
              empty_inventory()
            elseif action == "hammer" then
              if not get_tool("stone_hammer") then
                return
              end
              local uses = stack.size
              robot.select(1)
              if not ic.suckFromSlot(sides.front, chest_slot, uses) then
                print("suckFromSlot failed")
              end
              while robot.count(1) > 0 do
                robot.select(1)
                while not robot.placeUp() do
                  -- in case of left over block
                  print("Hammering: placeUp failed! Retrying.")
                  robot.select(2)
                  robot.swingUp()
                  robot.select(1)
                end
                local count_before_swing = robot.count(1)
                robot.select(2)
                while not robot.swingUp() do
                  print("Hammering: swingUp failed! Retrying.")
                end
                if robot.count(1) > count_before_swing then
                  print("Tool failure detected")
                  break
                end
              end
              empty_inventory()
            elseif action == "craft" then
              local craft_count = math.floor(stack.size / 4)
              local crafting_slots = { 1, 2, 5, 6 }
              for _, slot in pairs(crafting_slots) do
                robot.select(slot)
                if not ic.suckFromSlot(sides.front, chest_slot, craft_count) then
                  print("suckFromSlot failed")
                end
              end
              robot.select(12)
              if not craft(craft_count) then
                print("Craft failed")
              end
              empty_inventory()
            end
          end
        end
      end
    end
    if not any_action then break end
  end
  force_all = false
  print("Getting new blocks")
  if not get_tool(main_tool) then return end
  robot.turnAround()
  robot.select(1)
  while robot.count(1) < 64 do
    local ok, err = robot.swing()
    if not ok then
      if err == "block" then
        print("Tool failure detected")
        break
      else
        os.sleep(0.5)
      end
    end
  end
  robot.turnAround()
  empty_inventory()
end
