local component = require("component")
local transposer = component.transposer
local sides = require("sides")
local util = require("stack_util")
local emulator = require("emulator")

local outputSide = sides.up
local outputSlot = 16+4
local storageSides = {sides.left--[[, sides.right, sides.front, sides.back]]--
}

local storageCache = {}

storage = {}

function storage.scan()
  storageCache = {}
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

function storage.getOutputInventorySize()
  return 16
end

function storage.getStackInOutputSlot(slot)
  if emulator and slot==1 then
    local file_serialization = require("file_serialization")
    local t = file_serialization.load("/sample.txt")
    if type(t) == "table" then
      return t
    end
  end
  return transposer.getStackInSlot(outputSide, slot + 4)
end

function storage.moveToOutput(stack)
  local s = transposer.getStackInSlot(outputSide, outputSlot)
  if (s ~= nil) and (not util.equalThings(s, stack)) then
    return false
  end
  if (transposer.getSlotMaxStackSize(outputSide, outputSlot) - s.size) < stack.size then
    return false
  end

  local cnt = stack.size
  for side,cache in pairs(storageCache) do
    for slot,s in pairs(cache) do
      if util.equalThings(s, stack) then
        local take = math.min(s.size, cnt)
        transposer.transferItem(side, outputSide, take, slot, outputSlot)
        cnt = cnt - take
        cache[slot] = transposer.getStackInSlot(side, slot)
      end
    end
  end
  return cnt == 0
end

function storage.moveToStorage(slot)
  if storage.getFreeSlotCount() < 1 then
    -- not enough space
    return false
  end
  local stack = storage.getStackInOutputSlot(slot)
  if stack == nil then
    error("there is no stack in slot "..tostring(slot), 2)
  end
  slot = slot + 4 -- robot has some internal slots too

  local cnt = stack.size
  for side,cache in pairs(storageCache) do
    for slot2,s in pairs(cache) do
      if util.equalThings(s, stack) then
        local freeSpace = transposer.getSlotMaxStackSize(side, slot2) - s.size
        local take = math.min(freeSpace, cnt)
        transposer.transferItem(outputSide, side, take, slot, slot2)
        cnt = cnt - take
        cache[slot2] = transposer.getStackInSlot(side, slot2)
      end
    end
  end
  for side,cache in pairs(storageCache) do
    local n = transposer.getInventorySize(side)
    for slot2=1,n do
      local s = cache[slot2]
      if s == nil then
        transposer.transferItem(outputSide, side, stack.size, slot, slot2)
        cache[slot2] = transposer.getStackInSlot(side, slot2)
        return true
      end
    end
  end
  return cnt == 0
end

function storage.moveAllToStorage()
  local n = storage.getOutputInventorySize()
  if storage.getFreeSlotCount() < n then
    -- not enough space
    return false
  end
  for slot=1,n do
    local stack = storage.getStackInOutputSlot(slot)
    if stack ~= nil then
      local ok = storage.moveToStorage(slot)
      if not ok then
        return false
      end
    end
  end
  return true
end

function storage.getFreeSlotCount()
  local cnt = 0
  for side,cache in pairs(storageCache) do
    local n = transposer.getInventorySize(side)
    for slot=1,n do
      if cache[slot] == nil then
        cnt = cnt + 1
      end
    end
  end
  return cnt
end

function storage.dump()
  for side,cache in pairs(storageCache) do
    for slot,s in pairs(cache) do
      if s ~= nil then
        print(sides[side].." "..slot.." "..s.label.." x "..s.size)
      end
    end
  end
end

return storage
