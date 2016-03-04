local component = require("component")
local transposer = component.transposer
local sides = require("sides")
local util = require("stack_util")

local outputSide = sides.up
local outputSlot = 16
local storageSides = {sides.left, sides.right, sides.front, sides.back}

local storageCache = {}

storage = {}

function storage.scan()
  for _,side in pairs(storageSides) do
    local cache = {}

    local n = transposer.getInventorySize(side)
    for slot=1,n do
      cache[slot] = transposer.getStackInSlot(side, slot);
    end

    storageCache[side] = cache
  end
end

-- Check stuck size in storage only!
function storage.getStackSize(stack)
  local cnt = 0
  for side,cache in pairs(storageCache) do
    for slot,s in pairs(cache) do
      if util.equalThings(s, stack) then
        cnt = cnt + s.size
      end
    end
  end
  return cnt
end

function storage.moveToOutput(stack)
  local cnt = stack.size
  for side,cache in pairs(storageCache) do
    for slot,s in pairs(cache) do
      if util.equalThings(s, stack) then
        local take = math.min(s.size, cnt)
        transposer.transferItem(side, outputSide, take, slot)
        cnt = cnt - take
        cache[slot] = transposer.getStackInSlot(side, slot)
      end
    end
  end
  return cnt == 0
end

function storage.moveToStorage(slot)
  local stack = transposer.getStackInSlot(outputSide, slot)
  if stack == nil then
    error("there is no stack in slot "..tostring(slot), 2)
  end
  local cnt = stack.size
  for side,cache in pairs(storageCache) do
    for slot2,s in pairs(cache) do
      if util.equalThings(s, stack) then
        local freeSpace = transposer.getSlotMaxStackSize(side, slot2) - s.size
        local take = math.min(freeSpace, cnt)
        transposer.transferItem(outputSide, side, take, slot, slot2)
        cnt = cnt - take
        cache[slot] = transposer.getStackInSlot(side, slot2)
      end
    end
  end
  for side,cache in pairs(storageCache) do
    local n = transposer.getInventorySize(side)
    for slot2=1,n do
      local s = cache[slot2]
      if s == nil then
        transposer.transferItem(outputSide, side, stack.size, slot, slot2)
        cache[slot] = transposer.getStackInSlot(side, slot2)
        return true
      end
    end
  end
  return cnt == 0
end

function storage.moveAllToStorage()
  --local n = transposer.getInventorySize(outputSide)
  --for slot=1,n do
  for slot=5,20 do
    local stack = transposer.getStackInSlot(outputSide, slot)
    if stack ~= nil then
      local ok = storage.moveToStorage(slot)
      if not ok then
        return false
      end
    end
  end
  return true
end

return storage
