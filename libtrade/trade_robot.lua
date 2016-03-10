local rpc = require("rpc")
local robot = require("robot")
local component = require("component")
local tb = component.tractor_beam
local ic = component.inventory_controller
local sides = require("sides")

local enableGathering = false

api = {}

function api.startGathering()
  enableGathering = true
end

function api.stopGathering()
  enableGathering = false
end

function api.dropAll()
  for slot=1,16 do
    if robot.count(slot) > 0 then
      robot.select(slot)
      robot.dropUp()
    end
  end
  robot.select(1)
  while robot.suck() do
    robot.dropUp()
  end
end

function api.getSample()
  local stack = nil
  for slot=1,ic.getInventorySize(sides.front) do
    stack = ic.getStackInSlot(sides.front, slot)
    if stack ~= nil then
      break
    end
  end
  if stack ~= nil then
    enableGathering = false
    api.dropAll()

    local s = {}
    s.label = stack.label
    s.name = stack.name
    s.maxSize = stack.maxSize
    s.size = stack.size
    return s
  end
end

function api.test()
  return {42, "1", "23"}
end

rpc.bind(api)

while true do
  os.sleep(0.5)
  if enableGathering then
    robot.select(1)
    while tb.suck() do
      robot.drop()
    end
  end
end
