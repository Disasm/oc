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
local unicode = require("unicode")
local exchange = require("trade_exchange")


exchange:load();
tr.load("/tr_trade.txt")

package.loaded["gui"] = nil
_G["gui"] = nil
gui = require("gui")

function print1(...)
  term.setCursor(1,1)
  print(...)
end

item_db:load();

gpu.setPaletteColor(8,0x111111)

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
  local d = gui.Dialog.new(48, 12, parent)

  local db = item_db:getAll()
  local t = {}
  for i=1,#db do
    t[i] = {db[i].label}
  end

  d:addChild(gui.Table.new(d.xSize-4, d.ySize-4, t, {d.xSize-6}), 0, 0)--:setColor(0xc0c000)
  d:addChild(gui.SimpleButton.new(8, 1, "cancel", tr("otmena")), d.xSize-8-4, 11):setColor(0x00c000)
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
  local d = gui.Dialog.new(48, 12, parent)
  local label1 = gui.Label.new(20, item1Name, true)
  local label2 = gui.Label.new(20, item2Name, true)
  local size1 = gui.SpinBox.new(5, 1, 1, 64, 1)
  local size2 = gui.SpinBox.new(5, 1, 1, 64, 1)
  local count = gui.SpinBox.new(5, 1, 1, 64, 1)
  d:addChild(gui.Label.new(46, tr("Sozdanie lota")), 0, 0)
  d:addChild(gui.Label.new(35, tr("Vi daete drugomu igroku:"), true), 1, 1)
  d:addChild(gui.Label.new(8, tr("Predmet:")), 2, 2)
  d:addChild(label1, 11, 2)
  d:addChild(gui.Label.new(11, tr("Koli4estvo:")), 2, 3)
  d:addChild(size1, 14, 3)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select1", tr("vibor")), 30, 2):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample1", tr("obrazec")), 38, 2):setColor(0x00c000)

  d:addChild(gui.Label.new(35, tr("Vi polu4aete ot drugogo igroka:"), true), 1, 5)
  d:addChild(gui.Label.new(8, tr("Predmet:")), 2, 6)
  d:addChild(label2, 11, 6):setTextColor(0x00c000)
  d:addChild(gui.Label.new(11, tr("Koli4estvo:")), 2, 7)
  d:addChild(size2, 14, 7)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select2", tr("vibor")), 30, 6):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample2", tr("obrazec")), 38, 6):setColor(0x00c000)

  d:addChild(gui.Label.new(17, tr("Koli4estvo lotov:"), true), 1, 9)
  d:addChild(count, 19, 9)

  d:addChild(gui.SimpleButton.new(9, 1, "create", tr("sozdat'")), 1, 11):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", tr("otmena")), d.xSize-10-4, 11):setColor(0x00c000)

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

  local username = gui.getCurrentOwner()
  if username ~= nil then
    stack1.size = size1.sb_value
    stack2.size = size2.sb_value
    exchange:addLot(username, stack1, stack2, count.sb_value)
  end
end

function stackToString(s)
  return tonumber(s.size).." x "..s.label
end

function drawMainScreen(s)
  -- lot table
  local lots = exchange:getAllLots()
  local t = {}
  for i=1,#lots do
    local lot = lots[i]
    t[i] = {stackToString(lot.from), stackToString(lot.to), tostring(lot.count), lot.username}
  end
  local sizeCount = 7
  local sizeUsername = 15
  local sizeStack = math.floor((s.xSize - sizeCount - sizeUsername - 2) / 2)
  s:addChild(gui.Table.new(s.xSize, s.ySize-4, t, {sizeStack, sizeStack, sizeCount, sizeUsername}), 0, 3):setRowColors(0x000000, 0x111111)--:setColor(0xc0c000)

  s:addChild(gui.Label.new(s.xSize-2, tr("Vse predlozeniya")), 1, 0)
  s:addChild(gui.Label.new(sizeStack, tr("Prodaza"), true), 0, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(sizeStack, tr("Pokupka"), true), sizeStack, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(sizeCount, tr("Kol-vo"), true), sizeStack*2, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(s.xSize-(sizeStack*2+sizeCount), tr("Polzovatel"), true), sizeStack*2+sizeCount, 2):setColor(0x333333):setTextColor(0xFFBB24)

  buttons = {}
  if gui.getCurrentOwner() == nil then
    buttons = {
      {tr("nachat' rabotu"), "start"},
    }
  else
    buttons = {
      {tr("dobavit' lot"), "add_lot"},
      {tr("moi loti"), "my_lots"},
      {tr("inventar'"), "inventory"},
      {tr("zavershit' rabotu"), "logout"},
    }
  end

  local totalSize = 0
  for _,button in ipairs(buttons) do
    totalSize = totalSize + (2 + unicode.len(button[1]))
  end
  totalSize = totalSize + #buttons - 1

  local offset = math.floor((s.xSize-totalSize)/2)
  for _,button in ipairs(buttons) do
    local btn = gui.SimpleButton.new(nil, nil, button[2], button[1])
    btn:setColor(0xffffff)
    btn:setTextColor(0x000000)
    s:addChild(btn, offset, s.ySize-1)
    offset = offset + btn.xSize + 1
  end
end

function showUserLots(s)
  local username = gui.getCurrentOwner()
  if username == nil then
    return
  end

  local d = gui.Dialog.new(s.xSize-10, s.ySize-4, parent)

  -- lot table
  local lots = exchange:getAllLots()
  local t = {}
  for i=1,#lots do
    local lot = lots[i]
    if lot.username == username then
      t[#t+1] = {stackToString(lot.from), stackToString(lot.to), tostring(lot.count), "X"}
    end
  end
  local sizeCount = 7
  local sizeDelete = 1
  local sizeStack = math.floor((d.xSize-2 - sizeCount - sizeDelete - 2) / 2)
  local tbl = d:addChild(gui.Table.new(d.xSize-3, d.ySize-7, t, {sizeStack, sizeStack, sizeCount, sizeDelete}), 0, 3):setRowColors(0x000000, 0x111111)--:setColor(0xc0c000)
  tbl.filterEvent = function(self, ev)
    return
  end

  d:addChild(gui.Label.new(sizeStack, tr("Prodaza"), true), 0, 2):setColor(0x333333):setTextColor(0xFFBB24)
  d:addChild(gui.Label.new(sizeStack, tr("Pokupka"), true), sizeStack, 2):setColor(0x333333):setTextColor(0xFFBB24)
  d:addChild(gui.Label.new(sizeCount, tr("Kol-vo"), true), sizeStack*2, 2):setColor(0x333333):setTextColor(0xFFBB24)
  d:addChild(gui.Label.new(tbl.xSize-(sizeStack*2+sizeCount), tr(" "), true), sizeStack*2+sizeCount, 2):setColor(0x333333):setTextColor(0xFFBB24)

  local btn = gui.SimpleButton.new(nil, nil, "close", tr("zakrit'"))
  d:addChild(btn, math.floor((d.xSize-2-btn.xSize)/2), d.ySize-4):setColor(0x00c000)

  local r = d:exec()
end

local quit = false

function mainLoop()
  local s = gui.Screen.new(0)
  s:addChild(gui.SimpleButton.new(10, 1, "exit", "exit"), 10, 0):setColor(0xc00000)

  drawMainScreen(s)

  s:redraw()

  --[[local d = gui.MessageBox.new(tr("Opening soon"), nil, s)
  local r = d:exec()
  computer.beep(523, 0.2);
  computer.beep(652, 0.2);
  computer.beep(784, 0.2);]]--

  while true do
    local ev = s:pullEvent()
    if ev == "start" then
      -- Just redraw
      return
    end
    if ev == "logout" then
      gui.clearCurrentOwner()
      return
    end
    if ev == "add_lot" then
      local s = inputLot(s)
      local d = gui.MessageBox.new(tr("Teper' vam nuzhno dobavit' predmeti v razdele \"inventar'\""), nil, s)
      local r = d:exec()
      return
    end
    if ev == "my_lots" then
      showUserLots(s)
      return
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
  --pcall(mainLoop)
  mainLoop()
end
clearScreen()
