local component = require("component")
local file_serialization = require("file_serialization")

local topology = file_serialization.load("topology.txt")

function wrapRemoteTransposer(address)
end

function wrapTransposer(address)
  if component.type(address) == "transposer" then
    return component.proxy(address)
  else
    return wrapRemoteTransposer(address)
  end
end


local self = {}

self.getStackInSlot = function(side, slot)
end

self.transferItem = function(sourceSide, sinkSide, count, sourceSlot, sinkSlot)
end

self.getInventorySize = function(side)
end

self.getSlotMaxStackSize = function(side, slot)
end

