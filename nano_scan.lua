local nanomachine = require("nanomachine")
local m = require("component").modem
local event = require("event")
local ser = require("serialization")
local fs = require("filesystem")
local unicode = require("unicode")
local file_serialization = require("libs/file_serialization")
local serialization = require("serialization")

local machine = nanomachine.find()
if machine == nil then
  print("nanomachine is not found")
  return
end

local input_count = 15

local function splitComma(str)
  str = str:sub(2, -2)
  local l = {}
  for i in str:gmatch("(.-),.-") do
    table.insert(l, i)
  end
  table.insert(l, str:match(".+,(.+)"))
  if #l == 0 then
    if str ~= "" then
      table.insert(l, str)
    end
  end
  return l
end

-- init
input_count = machine.getTotalInputCount()
local player_name = machine.getName()
print("Player name is " .. player_name)
print("TotalInputCount: " .. input_count)
print("SafeActiveInputs: " .. machine.getSafeActiveInputs())
print("MaxActiveInputs: " .. machine.getMaxActiveInputs())
local blacklist_inputs = file_serialization.load( "/nanodata/"..player_name.."/bl") or {}
print("Blacklist inputs: " .. serialization.serialize(blacklist_inputs))

local function clear()
  print("Turning off inputs")
  for i = 1, input_count, 1 do
    machine.setInput(i, false)
  end
end

local function getState()
  for i = 1, input_count, 1 do
    print("Input "..i.." is "..tostring(machine.getInput(i)));
  end
end

local function stateToString(state)
  local results = {}
  for i = 1, input_count do
    if state[i] then
      results[#results + 1] = tostring(i)
    end
  end
  local result = table.concat(results, "_")
  if result == "" then
    result = "0"
  end
  return result
end

clear()
print("Scanning")
local current_state = {}
for i = 1, input_count do
  current_state[i] = false
end

local function setState(state)
  for i = 1, input_count do
    if state[i] == false and current_state[i] == true then
      --print("Setting input "..tostring(i).." to "..tostring(state[i]))
      machine.setInput(i, state[i])
      current_state[i] = state[i]
    end
  end
  for i = 1, input_count do
    if state[i] == true and current_state[i] == false then
      --print("Setting input "..tostring(i).." to "..tostring(state[i]))
      machine.setInput(i, state[i])
      current_state[i] = state[i]
    end
  end
end

local function fastClear()
  local state = {}
  for i = 1, input_count do
    state[i] = false
  end
  setState(state)
end

local function effectsFileName(state)
  return "/nanodata/"..player_name.."/"..stateToString(state)..".txt"
end

local function saveActiveEffects()
  local effects = splitComma(machine.getActiveEffects())
  local data = {}
  data.effects = effects
  local inputs = {}
  for i = 1, input_count do
    if current_state[i] then
      inputs[#inputs + 1] = i
    end
  end
  data.inputs = inputs
  file_serialization.save(effectsFileName(current_state), data)
  print(ser.serialize(inputs).." => "..ser.serialize(effects))
end




-- local healthCheckCoolDown = 0;
local function checkHealth()
  -- if healthCheckCoolDown == 0 then
    -- healthCheckCoolDown = 5
  local v = machine.getHealth()
  -- print("Health: "..tostring(v))
  if v < 7 then
    fastClear()
    error("Your health is dangerously low!")
  end
  -- else
   --  healthCheckCoolDown = healthCheckCoolDown - 1
  -- end
end



local function testState(state)
  if not file_serialization.load(effectsFileName(state)) then
    for _, v in ipairs(blacklist_inputs) do
      if state[v] then
        print("Skipping blacklist state: "..stateToString(state))
        return
      end
    end
    checkHealth()
    setState(state)
    saveActiveEffects()
  end
end

for i = 1, input_count do
  local state = {}
  for j = 1, input_count do
    state[j] = (i == j)
  end
  testState(state)
end

for i = 1, input_count do
  for j = (i + 1), input_count do
    local state = {}
    for s = 1, input_count do
      state[s] = (s == i or s == j)
    end
    testState(state)
  end
end

-- for i = 1, input_count do
--   for j = (i + 1), input_count do
--     for z = (j + 1), input_count do
--       local state = {}
--       for s = 1, input_count do
--         state[s] = (s == i or s == j or s == z)
--       end
--       testState(state)
--     end
-- end
-- end



fastClear()

-- getState();

