package.path = package.path .. ';/libs/?.lua'
local component = require("component")
local file_serialization = require("file_serialization")
local gpu = component.gpu
local computer = component.computer
local transposer = component.transposer
term = require("term")
local sides = require("sides")
local util = require("stack_util")
local item_db = require("stack_db")
local tr = require("tr")

tr.load("/tr_trade.txt")

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

gui.setIdealResolution()

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
  local d = gui.MessageBox.new(tr("Bros'te predmeti na robota"), {tr("Otmena"), "cancel"}, parent)
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
    local d = gui.MessageBox.new(tr("Net predmetov"), nil, parent)
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
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", tr("cancel")), d.xSize-10-4, 9):setColor(0x00c000)
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
  local item1Name = tr("ne vibran")
  local item2Name = tr("ne vibran")
  local d = gui.Dialog.new(48, 10, parent)
  local label1 = gui.Label.new(20, item1Name, true)
  local label2 = gui.Label.new(20, item2Name, true)
  d:addChild(gui.Label.new(46, tr("Sozdanie lota")), 0, 0)
  d:addChild(gui.Label.new(35, tr("Vi daete drugomu igroku:"), true), 1, 1)
  d:addChild(gui.Label.new(8, tr("Predmet:")), 2, 2)
  d:addChild(label1, 11, 2)
  d:addChild(gui.Label.new(11, tr("Koli4estvo:")), 2, 3)
  d:addChild(gui.SpinBox.new(5, 1, 1, 64, 1), 14, 3)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select1", tr("vibor")), 30, 2):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample1", tr("obrazec")), 38, 2):setColor(0x00c000)

  d:addChild(gui.Label.new(35, tr("Vi polu4aete ot drugogo igroka:"), true), 1, 5)
  d:addChild(gui.Label.new(8, tr("Predmet:")), 2, 6)
  d:addChild(label2, 11, 6):setTextColor(0x00c000)
  d:addChild(gui.Label.new(11, tr("Koli4estvo:")), 2, 7)
  d:addChild(gui.SpinBox.new(5, 1, 1, 64, 1), 14, 7)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select2", tr("vibor")), 30, 6):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample2", tr("obrazec")), 38, 6):setColor(0x00c000)

  d:addChild(gui.SimpleButton.new(9, 1, "create", tr("sozdat'")), 1, 9):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", tr("otmena")), d.xSize-10-4, 9):setColor(0x00c000)

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
        local d = gui.MessageBox.new(tr("Sna4ala viberite predmeti!"), nil, d)
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
      item1Name = tr("ne vibran")
      color1 = defaultTextColor
    else
      item1Name = stack1.label
      color1 = selectedTextColor
    end
    if stack2 == nil then
      item2Name = tr("ne vibran")
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
  --s:addChild(gui.SimpleButton.new(10, 1, "exit", "exit"), 5, 7):setColor(0xc00000)
  --s:addChild(gui.Button.new(10, 3, "btn", "show", false), 27, 20)
  --s:addChild(gui.Label.new(11, "label"), 10, 4)
  --s:addChild(gui.Frame.new(31, 10, 0x00c000), 20, 5):setColor(0x00c000)
  --s:addChild(gui.ShadowedButton.new(10, 1, "exit", "exit"), 5, 12):setColor(0xc00000)
  --s:addChild(gui.LargeSpinBox.new(5, 1, 0, 4096, 4), 20, 1):setColor(0x00c0c0)
  --s:addChild(gui.ShadowedButton.new(12, 1, "add_sample", "add sample"), 5, 14):setColor(0xc00000)
  --s:addChild(gui.ShadowedButton.new(9, 1, "add_lot", "add lot"), 5, 16):setColor(0xc00000)

  --s:addChild(gui.SimpleButton.new(9, 1, "add_lot", "my lots"), 0, 0):setColor(0x00c000)

  s:redraw()

  local d = gui.MessageBox.new(tr("Opening soon"), nil, s)
  local r = d:exec()
  computer.beep(523, 0.2);
  computer.beep(652, 0.2);
  computer.beep(784, 0.2);

  --[[
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
  end]]--
end

clearScreen()
while not quit do
  pcall(mainLoop)
  --mainLoop()
end
clearScreen()
