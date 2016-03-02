package.path = package.path .. ';/libs/?.lua'
local component = require("component")
local file_serialization = require("file_serialization")
local gpu = component.gpu
local transposer = component.transposer
term = require("term")
local sides = require("sides")
local util = require("stack_util")
local item_db = require("stack_db")

package.loaded["gui"] = nil
_G["gui"] = nil
gui = require("gui")

function print1(...)
  term.setCursor(1,1)
  print(...)
end

item_db:load();

--addItemToDb({size=1,name="minecraft:clock",label="Clock"})
--addItemToDb({size=1,name="minecraft:gold_ingot",label="Gold Ingot"})
--addItemToDb({size=1,name="minecraft:redstone",label="Redstone"})

gpu.setResolution(80, 23)

local inputSide = sides.down
local outputSide = sides.left
local storageSide = sides.back

function clearScreen()
  gpu.setBackground(0x000000)
  gpu.setForeground(0xffffff)
  local w, h = gpu.getResolution()
  gpu.fill(1, 1, w, h, " ")
end

function clearInputChest()
  while transposer.transferItem(inputSide, outputSide) do
  end
end

function inputSample(parent)
  local stack = nil

  clearInputChest()

  local i = 0
  local d = gui.MessageBox.new("Drop items on hopper", {"Cancel", "cancel"}, parent)
  d.update = function(self)
    i = i + 1
    local s = transposer.getStackInSlot(inputSide, 1)
    if s ~= nil then
      stack = s
      error("done")
    end
  end
  local r = d:exec()

  clearInputChest()

  if r ~= nil then
    return
  end

  if stack == nil then
    local d = gui.MessageBox.new("No items", nil, parent)
    d:setColor(0xcc0000)
    local r = d:exec()
    return
  end
  item_db:add(stack)
  return stack
end

function inputFromDb(parent)
  local d = gui.Dialog.new(48, 10, parent)

  local db = item_db:getAll()
  local t = {}
  for i=1,#db do
    t[i] = {db[i].label}
  end

  d:addChild(gui.Table.new(d.xSize-4, d.ySize-4, t, {d.xSize-6}), 0, 0)--:setColor(0xc0c000)
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", "cancel", 0x00c000), d.xSize-10-4, 9)
  local ev = d:exec()
  if ev == "cancel" then
    return
  end

  local stack = db[ev[1]]

  --[[local d = gui.MessageBox.new("Item detected: "..stack.label, nil, parent)
  local r = d:exec()]]--

  return stack
end

function inputLot(parent)
  local defaultTextColor = 0xffffff
  local selectedTextColor = 0x00c000
  local stack1 = nil
  local stack2 = nil
  local item1Name = "not set"
  local item2Name = "not set"
  local d = gui.Dialog.new(48, 10, parent)
  local label1 = gui.Label.new(20, item1Name, true)
  local label2 = gui.Label.new(20, item2Name, true)
  d:addChild(gui.Label.new(46, "Create lot"), 0, 0)
  d:addChild(gui.Label.new(10, "You sell:", true), 1, 1)
  d:addChild(gui.Label.new(5, "Item:"), 2, 2)
  d:addChild(label1, 9, 2)
  d:addChild(gui.Label.new(6, "Count:"), 2, 3)
  d:addChild(gui.SpinBox.new(5, 1, 1, 64, 1), 9, 3)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(8, 1, "select1", "select", 0x00c000), 30, 2)
  d:addChild(gui.SimpleButton.new(8, 1, "sample1", "sample", 0x00c000), 39, 2)

  d:addChild(gui.Label.new(10, "You buy:", true), 1, 5)
  d:addChild(gui.Label.new(5, "Item:"), 2, 6)
  d:addChild(label2, 9, 6):setTextColor(0x00c000)
  d:addChild(gui.Label.new(6, "Count:"), 2, 7)
  d:addChild(gui.SpinBox.new(5, 1, 1, 64, 1), 9, 7)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(8, 1, "select2", "select", 0x00c000), 30, 6)
  d:addChild(gui.SimpleButton.new(8, 1, "sample2", "sample", 0x00c000), 39, 6)

  d:addChild(gui.SimpleButton.new(10, 1, "create", "create", 0x00c000), 1, 9)
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", "cancel", 0x00c000), d.xSize-10-4, 9)

  d.filterEvent = function(self, ev)
    if (ev == "sample1") or (ev == "sample2") then
      local s = inputSample(d)
      if s ~= nil then
        if ev == "sample1" then
          stack1 = s
        else
          stack2 = s
        end
      end
      return ""
    end

    if (ev == "select1") or (ev == "select2") then
      local s = inputFromDb(d)
      if s ~= nil then
        if ev == "select1" then
          stack1 = s
        else
          stack2 = s
        end
      end
      return ""
    end

    if ev == "create" then
      if (stack1 == nil) or (stack2 == nil) then
        local d = gui.MessageBox.new("Select items first!", nil, d)
        d:setColor(0xcc0000)
        local r = d:exec()
        return ""
      else
        return ev
      end
    end

    return ev
  end
  while true do
    local color1
    local color2

    if stack1 == nil then
      item1Name = "not set"
      color1 = defaultTextColor
    else
      item1Name = stack1.label
      color1 = selectedTextColor
    end
    if stack2 == nil then
      item2Name = "not set"
      color2 = defaultTextColor
    else
      item2Name = stack2.label
      color2 = selectedTextColor
    end
    label1.text = item1Name
    label2.text = item2Name

    label1:setTextColor(color1)
    label2:setTextColor(color2)

    local ev = d:exec()
    if ev == "cancel" then
      return
    end
    if ev == "create" then
      break
    end
  end

  -- add lots
end

local quit = false

function mainLoop()
  local s = gui.Screen.new(0x0000f0)
  s:addChild(gui.SimpleButton.new(10, 1, "exit", "exit", 0xc00000), 5, 7)
  s:addChild(gui.Button.new(10, 3, "btn", "show", false), 27, 20)
  s:addChild(gui.Label.new(11, "label"), 10, 4)
  --s:addChild(gui.Frame.new(31, 10, 0x00c000), 20, 5):setColor(0x00c000)
  s:addChild(gui.ShadowedButton.new(10, 1, "exit", "exit", 0xc00000), 5, 12)
  s:addChild(gui.LargeSpinBox.new(5, 1, 0, 4096, 4), 20, 1):setColor(0x00c0c0)
  s:addChild(gui.ShadowedButton.new(12, 1, "add_sample", "add sample", 0xc00000), 5, 14)
  s:addChild(gui.ShadowedButton.new(9, 1, "add_lot", "add lot", 0xc00000), 5, 16)

  s:addChild(gui.SimpleButton.new(9, 1, "add_lot", "my lots", 0x00c000), 0, 0)

  s:redraw()

  while true do
    local ev = s:pullEvent()
    if ev == "add_sample" then
      local s = inputSample(s)
    end
    if ev == "add_lot" then
      local s = inputLot(s)
    end
    if ev == "btn" then
      local d = gui.MessageBox.new("This is MessageBox", nil, s)
      local r = d:exec()
      --local d = gui.Dialog.new(43, 10, s)
    end
    if ev == "exit" then
      gpu.setBackground(0x000000)
      gpu.setForeground(0xffffff)
      term.setCursor(1,1)
      quit = true
      break
    end
    if type(ev) == "table" then
      term.setCursor(1,1)
      print(table.unpack(ev))
    end
  end
end

clearScreen()
while not quit do
  pcall(mainLoop)
  --mainLoop()
end
clearScreen()
