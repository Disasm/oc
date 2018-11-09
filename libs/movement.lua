local robot = require("robot")
local computer = require("computer")
local component = require("component")
local eeprom = component.proxy(component.list("eeprom")())
local serialization = require("serialization")
local os = require("os")
local _,file_serialization = pcall(require, "file_serialization")

local m = {}
m.storage = "eeprom"

local stateFileName = "/position.dat"
local state = nil

local function saveState()
  if m.storage == nil then
    return
  end
  if m.storage == "eeprom" then
    s = serialization.serialize(state)
    eeprom.setLabel(s)
  end
  if m.storage == "hdd" then
    file_serialization.save(stateFileName, state)
  end
end

local function loadState()
  if m.storage == nil then
    return
  end
  if m.storage == "eeprom" then
    local s = eeprom.getLabel()
    state = serialization.unserialize(s)
  end
  if m.storage == "hdd" then
    s = file_serialization.load(stateFileName)
    if type(s) == "table" and s.x ~= nil then
        state = s
    else
        state = {
            x = 0,
            y = 0,
            z = 0,
            dx = 0,
            dz = 1,
        }
        saveState()
    end
  end
end

local function turnLeft()
    robot.turnLeft()
    state.dx, state.dz = -state.dz, state.dx
    saveState()
end

local function turnRight()
    robot.turnRight()
    state.dx, state.dz = state.dz, -state.dx
    saveState()
end

local function tryForward()
    tries = 0
    while not robot.forward() do
        tries = tries + 1
        if tries > 20 then
            return false
        end
        os.sleep(0.8)
    end
    state.x = state.x + state.dx
    state.z = state.z + state.dz
    saveState()
    return true
end

local function forceForward()
    while not robot.forward() do
        os.sleep(0.8)
    end
    state.x = state.x + state.dx
    state.z = state.z + state.dz
    saveState()
    return true
end

local function calcTurns(dx, dz)
    local dx1 = state.dx
    local dz1 = state.dz
    local cnt = 0
    while (dx1 ~= dx) or (dz1 ~= dz) do
        dx1, dz1 = -dz1, dx1
        cnt = cnt + 1
    end
    return cnt
end

local function gotoDir(dx, dz)
    local n = calcTurns(dx, dz)
    if n == 0 then
        return
    elseif n == 1 then
        turnLeft()
    elseif n == 2 then
        turnLeft()
        turnLeft()
    else
        turnRight()
    end
end

local function gotoxz(x, z, dx0, dz0)
    local dx = 0
    if (state.x - x) < 0 then
        dx = 1
    else
        dx = -1
    end

    local dz = 0
    if (state.z - z) < 0 then
        dz = 1
    else
        dz = -1
    end

    if state.x ~= x then
        gotoDir(dx, 0)
        while state.x ~= x do
            forceForward()
        end
    end

    if state.z ~= z then
        gotoDir(0, dz)
        while state.z ~= z do
            forceForward()
        end
    end

    if (dx0 ~= nil) and (dz0 ~= nil) then
        gotoDir(dx0, dz0)
    end
end

m.reset = function()
    state = {
        x = 0,
        y = 0,
        z = 0,
        dx = 0,
        dz = 1,
    }
    saveState()
end

m.get_pos = function()
    return state.x, state.z
end

m.set_pos = function(x, z)
    gotoxz(x, z)
end

m.get_dir = function()
    return state.dx, state.dz
end

m.set_dir = function(dx, dz)
    gotoDir(dx, dz)
end

loadState()

return m
