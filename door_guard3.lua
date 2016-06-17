local event = require("event")
local component = require("component")
local sides = require("sides")

local radius = 2

local reader = component.os_rfidreader
local redstone = component.redstone

function set_door(is_open)
  -- print("set to ", is_open)
  redstone.setOutput(sides.top, is_open and 0 or 15)
end

function on_timer()
  local is_open = false
  for _, card in ipairs(reader.scan(radius * 2)) do
    if card.name == "Riateche" or card.name == "disasm" then
      is_open = true
    end
  end
  set_door(is_open)
end

event.timer(1, on_timer, math.huge)
set_door(false)
