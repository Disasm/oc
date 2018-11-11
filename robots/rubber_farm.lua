robot = require("robot")
component = require("component")
ic = component.inventory_controller
--magnet = component.tractor_beam
m = require("movement")
sides = require("sides")

--m.reset()

local maxHeight = 8


local names = {}
names["laser"]= "IC2:itemToolMiningLaser"
names["treetap"]= "IC2:itemTreetap" -- "IC2:itemTreetapElectric"
names["chainsaw"]= "minecraft:iron_axe" -- "IC2:itemToolChainsaw"
names["bonemeal"]= "Forestry:fertilizerCompound" -- "minecraft:dye"
names["sapling"]= "IC2:blockRubSapling"
names["bone"]= "minecraft:bone"
names["mfe"]= "IC2:blockElectric"
names["crystal"] = "IC2:itemBatCrystal"
names["wrench"] = "IC2:itemToolWrenchElectric"
names["shears"] = "minecraft:shears"
names["rubber"] = "IC2:itemHarz"

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

local function calcRubber()
    local cnt = 0
    for i=1,robot.inventorySize() do
        if robot.count(i) > 0 then
            local stack = ic.getStackInInternalSlot(i)
            if stack and stack.name == names["rubber"] then
                cnt = cnt + robot.count(i)
            end
        end
    end
    return cnt
end

local function useTreetap()
    equip("treetap")
    if not robot.use() then
        lastEquippedName = nil
        equip("treetap")
        return robot.use()
    else
        return true
    end
end


function mineTower(x, z, isFinal)
    m.set_pos(x, z)
    m.set_dir(-x, -z)

    equip("shears")
    for i=1,maxHeight do
        while true do
            if robot.up() then
                break
            end
            robot.swingUp()
            os.sleep(0.4)
        end
    end

    for i=1,maxHeight do
        print(i)
        while not robot.down() do
            os.sleep(0.4)
        end
        if robot.detect() then
            local oldCount = calcRubber()
            print("oldCount: "..oldCount)
            if useTreetap() then
                os.sleep(0.5)
                local newCount = calcRubber()
                print("newCount: "..oldCount)
                if newCount ~= oldCount then
                    print(""..(newCount-oldCount).." new rubber")
                    oldCount = newCount
                    
                    for k=1,12 do
                        useTreetap()

                        os.sleep(0.5)
                        local newCount = calcRubber()
                        print("newCount: "..oldCount)
                        if newCount ~= oldCount then
                            print(""..(newCount-oldCount).." new rubber")
                        end
                        oldCount = newCount
                    end
                end
            end
        end
        if isFinal then
            equip("chainsaw")
            robot.swing()
        end
    end
end

function mineTree()
    equip("empty")
    mineTower(0, -1)
    m.set_pos(-1, -1)
    mineTower(-1, 0)
    m.set_pos(-1, 1)
    mineTower(0, 1)
    m.set_pos(1, 1)
    mineTower(1, 0, true)
    m.set_pos(1, -1)
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
    return count
end

function checkSaplings()
    local saplingSlot = find_slot("sapling", true)
    if saplingSlot == nil then
        return false
    end
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
    local boneMealSlot = find_slot("bonemeal", true)
    if boneMealSlot == nil then
        return false
    end
    local s = ic.getStackInInternalSlot(boneMealSlot)
    if s.label ~= "Fertilizer" then
        return false
    end
    
    if s.size < 4 then
        gather(boneMealSlot)
    end
    
    if robot.count(boneMealSlot) < 4 then
        -- TODO: craft more
    end
    
    return robot.count(boneMealSlot) > 5
end

function checkTools()
    local i = find_slot("chainsaw")
    --[[local s = ic.getStackInInternalSlot(i)
    if s.charge < 1000 then
        print "Not enough energy in chainsaw"
        return false
    end]]--
    
    i = find_slot("treetap")
    --[[s = ic.getStackInInternalSlot(i)
    if s.charge < 500 then
        print "Not enough energy in treetap"
        return false
    end]]--
    i = find_slot("shears")
    
    return true
end

function growTree()
    equip("empty")
    if not checkSaplings() then
        print("Not enough saplings")
        return false
    end
    if not checkBoneMeal() then
        print("Not enough bone meal")
        return false
    end
    if not checkTools() then
        return false
    end
    
    m.set_pos(0, -1)
    m.set_dir(0, 1)
    
    equip("sapling")
    if not robot.use(sides.down) then
        print("Can't grow tree")
        return false
    end
    
    equip("bonemeal")
    if not robot.use() then
        print("Can't use bone meal")
        return false
    end
    while robot.use() do
        os.sleep(0.4)
    end
    
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
