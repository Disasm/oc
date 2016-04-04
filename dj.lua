local component = require("component")
local redstone = component.redstone
local os = require("os")
local sides = require("sides")
local ic = component.inventory_controller
local robot = require("robot")

local duration = {
    ["11"]      = 71,  -- 1:11
    ["13"]      = 178, -- 2:58
    ["blocks"]  = 346, -- 5:46
    ["cat"]     = 185, -- 3:05
    ["chirp"]   = 186, -- 3:06
    ["far"]     = 174, -- 2:54
    ["mall"]    = 197, -- 3:17
    ["mellohi"] = 96,  -- 1:36
    ["stal"]    = 151, -- 2:31
    ["strad"]   = 188, -- 3:08
    ["wait"]    = 238, -- 3:58
    ["ward"]    = 251, -- 4:11
}
local delay = 3

math.randomseed(os.time())

local old_index = -1

while true do
  local r = math.random(16)
  local s = ic.getStackInInternalSlot(r)
  if s ~= nil and (r ~= old_index) then
    old_index = r
    local name = s.name
    name = string.sub(name, 18)
    local d = duration[name]
    if d ~= nil then
      robot.select(r)
      ic.equip()
      os.sleep(0.4)
      robot.use()
      os.sleep(d + delay)
      robot.use()
    end
  end
end
