robot = require("robot")
component = require("component")
ic = component.inventory_controller
magnet = component.tractor_beam
m = require("movement")
sides = require("sides")

m.reset()

local maxHeight = 8


local names = {}
names["laser"]= "IC2:itemToolMiningLaser"
names["treetap"]= "IC2:itemTreetapElectric"
names["chainsaw"]= "IC2:itemToolChainsaw"
names["bonemeal"]= "minecraft:dye"
names["sapling"]= "IC2:blockRubSapling"
names["bone"]= "minecraft:bone"
names["mfe"]= "IC2:blockElectric"
names["crystal"] = "IC2:itemBatCrystal"
names["wrench"] = "IC2:itemToolWrenchElectric"

local slots_count = robot.inventorySize()

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


local lastEquippedName = nil
local function equip(name)
  if name == lastEquippedName then
    return 
  end
  robot.select(find_slot(name))
  ic.equip()
  lastEquippedName = name
end


local function gather(slot)
    if robot.space(slot) == 0 then
        return
    end
    robot.select(slot)
    for i=(slot+1),robot.inventorySize() do
        if robot.count(i) > 0 then
            if robot.compareTo(i) or (robot.count(slot) == 0) then
                robot.select(i)
                robot.transferTo(slot)
                robot.select(slot)
            end
        end
        if robot.space(slot) == 0 then
            return
        end
    end
end


function mineTower(x, z, tool)
    m.set_pos(x, z)
    for i=1,maxHeight-1 do
        while true do
            if robot.up() then
                break
            end
            robot.swingUp()
            os.sleep(0.4)
        end
    end
    for i=1,maxHeight-1 do
        while not robot.down() do
            os.sleep(0.4)
        end
    end
end

function useTreetap(x, z)
    m.set_pos(x, z)
    m.set_dir(-x, -z)
    
    equip("treetap")
    
    for i=1,maxHeight do
        if robot.detect() then
            robot.use()
        end
        while not robot.up() do
            os.sleep(0.4)
        end
    end
    for i=1,maxHeight do
        while not robot.down() do
            os.sleep(0.4)
        end
    end
end

function mineTree()
    local spiral = { {3, 2}, {2, 2}, {2, 3}, {2, 4}, {3, 4}, {4, 4}, {4, 3}, {4, 2}, {4, 1}, {3, 1}, {2, 1}, {1, 1}, {1, 2}, {1, 3}, {1, 4}, {1, 5}, {2, 5}, {3, 5}, {4, 5}, {5, 5}, {5, 4}, {5, 3}, {5, 2}, {5, 1} }
    equip("empty")
    for _,v in pairs(spiral) do
        local x = v[1] - 3
        local z = v[2] - 3
        mineTower(x, z)
    end
    useTreetap(0, -1)
    m.set_pos(-1, -1)
    useTreetap(-1, 0)
    m.set_pos(-1, 1)
    useTreetap(0, 1)
    m.set_pos(1, 1)
    useTreetap(1, 0)
    equip("chainsaw")
    
    m.set_pos(1, 0)
    m.set_dir(-1, 0)
    equip("chainsaw")
    robot.swing()
    
    magnet.suck()
    
    mineTower(0, 0)
    equip("empty")
end

function getItemCount(label)
    local count = 0
    for i=1,robot.inventorySize() do
        if robot.count(i) > 0 then
            local stack = ic.getStackInInternalSlot(i)
            if stack.label == label then
                count = count + stack.size
            end
        end
    end
end

function checkSaplings()
    local saplingSlot = find_slot("sapling")
    local s = ic.getStackInInternalSlot(saplingSlot)
    if s.label ~= "Rubber Tree Sapling" then
        return false
    end
    
    if s.size < 4 then
        gather(saplingSlot)
    end
    
    return robot.count(saplingSlot) > 2
end

function checkBoneMeal()
    local boneMealSlot = find_slot("bonemeal")
    local s = ic.getStackInInternalSlot(boneMealSlot)
    if s.label ~= "Bone Meal" then
        return false
    end
    
    if s.size < 4 then
        gather(boneMealSlot)
    end
    
    if robot.count(boneMealSlot) < 4 then
        -- TODO: craft more
    end
    
    return robot.count(boneMealSlot) > 2
end

function checkTools()
    local i = find_slot("chainsaw")
    local s = ic.getStackInInternalSlot(i)
    if s.charge < 1000 then
        print "Not enough energy in chainsaw"
        return false
    end
    
    i = find_slot("treetap")
    s = ic.getStackInInternalSlot(i)
    if s.charge < 500 then
        print "Not enough energy in treetap"
        return false
    end
    
    return true
end

function growTree()
    if not checkSaplings() then
        print "Not enough saplings"
        return false
    end
    if not checkBoneMeal() then
        print "Not enough bone meal"
        return false
    end
    if not checkTools() then
        return false
    end
    
    m.set_pos(0, -1)
    m.set_dir(0, 1)
    
    equip("sapling")
    robot.use(sides.down)
    
    equip("bonemeal")
    robot.use()
    
    equip("empty")
    
    return true
end

cnt = 1
while true do
    print("Growing tree "..cnt)
    if not growTree() then
        break
    end
    cnt = cnt + 1
    mineTree()
end
