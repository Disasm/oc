local component = require("component")
local redstone = nil
local sides = require("sides")

local list = component.list("redstone")
for k,v in pairs(list) do
  redstone = component.proxy(k)
end

local lockSide = sides.left

local lock = {}

function lock.lock()
  if redstone then
    redstone.setOutput(lockSide, 15)
  end
end

function lock.unlock()
  if redstone then
    redstone.setOutput(lockSide, 0)
  end
end

return lock

