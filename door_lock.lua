local component = require("component")
local redstone = component.redstone
local sides = require("sides")

local lockSide = sides.left

local lock = {}

function lock.lock()
  redstone.setOutput(lockSide, 15)
end

function lock.unlock()
  redstone.setOutput(lockSide, 0)
end

return lock

