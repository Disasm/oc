local event = require("event")
local component = require("component")

local radius = 2

local reader = component.os_rfidreader
local door = component.os_door

function set_door(val)
  if door.isOpen() ~= val then
    door.toggle()
  end
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
