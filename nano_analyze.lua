local file_serialization = require("libs/file_serialization")
local serialization = require("serialization")
local filesystem = require("filesystem")
local io = require("io")
local component = require("component")
local gpu = component.gpu
local event = require("event")
local keyboard = require("keyboard")

local bad_things = {};
for i, name in ipairs({"poison", "confusion", "weakness", "moveSlowdown", "digSlowDown", "wither", "blindness", "hunger"}) do
  bad_things[name] = true
end


function waitForEnter()
    while true do
        local e, addr, ch, code, player = event.pull("key_down")
        if code == keyboard.keys.enter then
            break
        end
    end
end

print("click on screen")
local ev = table.pack(event.pull("touch"))
player_name = ev[6]
directory = "/nanodata/"..player_name
-- all_data = {}
effects = {}

for fileName in filesystem.list(directory) do
  if fileName ~= "bl" then
    local data = file_serialization.load(directory.."/"..fileName)
    if not data.effects then
      error("Invalid file: " .. directory.."/"..fileName)
    end
    local good_data = {}
    local good_data_any = false
    local any_positive = false
    for i, value in ipairs(data.effects) do
      if not string.find(value, "particles.") then
        good_data[#good_data + 1] = value
        good_data_any = true
        if not bad_things[value] then
          any_positive = true
        end
      end
    end
    if good_data_any and any_positive then
      effects_string = serialization.serialize(good_data)

      if not effects[effects_string] then
        effects[effects_string] = data.inputs
      else
        if #(data.inputs) < #(effects[effects_string]) then
          effects[effects_string] = data.inputs
        end
      end
    end
  end
end

local function effects_rating(effects)
  local r = 0
  for i, effect in ipairs(effects) do
    if bad_things[effect] then
      r = r - 3
    else
      r = r + 1
    end
  end
  return r
end

effects_list = {}
for effs, inputs in pairs(effects) do
  v = {}
  v.effects = serialization.unserialize(effs)
  v.inputs = inputs
  effects_list[#effects_list + 1] = v
end

table.sort(effects_list, function(a,b) return effects_rating(a.effects) > effects_rating(b.effects) end)


local linesPrinted = 0
for i, v in ipairs(effects_list) do
  io.write(serialization.serialize(v.inputs).." => ")
  for i, effect in ipairs(v.effects) do
    if bad_things[effect] then
      gpu.setForeground(0xff0000)
    else
      gpu.setForeground(0x00ff00)
    end
    io.write(effect .. " ")
    gpu.setForeground(0xffffff)
  end
  io.write("\n")
  linesPrinted = linesPrinted + 1
  if linesPrinted > 20 then
    waitForEnter()
    linesPrinted = 0
  end

end
