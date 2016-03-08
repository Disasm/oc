local guiTimeout = 60
local underConstruction = true

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
local trade_db = require("trade_db")
local tr = require("tr")
local u = require("u")
local unicode = require("unicode")
local exchange = require("trade_exchange")
local storage = require("trade_storage")
local trade_robot = require("trade_robot_api")
local emulator = require("emulator")
local event = require("event")
local door_lock = require("door_lock")

exchange:load();
trade_db:load();
tr.load("/tr_trade.txt")

package.loaded["gui"] = nil
_G["gui"] = nil
gui = require("gui")

--[[function print1(...)
  term.setCursor(1,1)
  print(...)
end]]--


-- Manage door lock
door_lock.unlock()
event.listen("user_login", function()
  door_lock.lock()
end)
event.listen("user_logout", function()
  door_lock.unlock()
end)


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
  local d = gui.MessageBox.new(u("Бросьте предметы на робота"), {u("Отмена"), "cancel"}, parent)
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
    local d = gui.MessageBox.new(u("Нет предметов"), nil, parent)
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
  d:addChild(gui.SimpleButton.new(8, 1, "cancel", u("отмена")), d.xSize-8-4, 11):setColor(0x00c000)
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
  local item1Name = u("не выбран")
  local item2Name = u("не выбран")
  local d = gui.Dialog.new(48, 12, parent)
  local label1 = gui.Label.new(20, item1Name, true)
  local label2 = gui.Label.new(20, item2Name, true)
  local size1 = gui.SpinBox.new(5, 1, 1, 64, 1)
  local size2 = gui.SpinBox.new(5, 1, 1, 64, 1)
  local count = gui.SpinBox.new(5, 1, 1, 64, 1)
  d:addChild(gui.Label.new(46, u("Создание лота")), 0, 0)
  d:addChild(gui.Label.new(35, u("Вы даёте другому игроку:"), true), 1, 1)
  d:addChild(gui.Label.new(8, u("Предмет:")), 2, 2)
  d:addChild(label1, 11, 2)
  d:addChild(gui.Label.new(11, u("Количество:")), 2, 3)
  d:addChild(size1, 14, 3)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select1", u("выбор")), 30, 2):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample1", u("образец")), 38, 2):setColor(0x00c000)

  d:addChild(gui.Label.new(35, u("Вы получаете от другого игрока:"), true), 1, 5)
  d:addChild(gui.Label.new(8, u("Предмет:")), 2, 6)
  d:addChild(label2, 11, 6):setTextColor(0x00c000)
  d:addChild(gui.Label.new(11, u("Количество:")), 2, 7)
  d:addChild(size2, 14, 7)--:setColor(0x00c0c0)
  d:addChild(gui.SimpleButton.new(7, 1, "select2", u("выбор")), 30, 6):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(9, 1, "sample2", u("образец")), 38, 6):setColor(0x00c000)

  d:addChild(gui.Label.new(17, u("Количество лотов:"), true), 1, 9)
  d:addChild(count, 19, 9)

  d:addChild(gui.SimpleButton.new(9, 1, "create", u("создать")), 1, 11):setColor(0x00c000)
  d:addChild(gui.SimpleButton.new(10, 1, "cancel", u("отмена")), d.xSize-10-4, 11):setColor(0x00c000)

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
        local d = gui.MessageBox.new(u("Сначала выберите предметы!"), nil, d)
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
      item1Name = u("не выбран")
      color1 = defaultTextColor
    else
      item1Name = stack1.label
      color1 = selectedTextColor
    end
    if stack2 == nil then
      item2Name = u("не выбран")
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
      return false
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
  return true
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

  s:addChild(gui.Label.new(s.xSize-2, u("Все предложения")), 1, 0)
  s:addChild(gui.Label.new(sizeStack, u("Продажа"), true), 0, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(sizeStack, u("Покупка"), true), sizeStack, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(sizeCount, u("Кол-во"), true), sizeStack*2, 2):setColor(0x333333):setTextColor(0xFFBB24)
  s:addChild(gui.Label.new(s.xSize-(sizeStack*2+sizeCount), u("Пользователь"), true), sizeStack*2+sizeCount, 2):setColor(0x333333):setTextColor(0xFFBB24)

  buttons = {}
  if gui.getCurrentOwner() == nil then
    buttons = {
      {u("начать работу"), "start"},
    }
  else
    buttons = {
      {u("добавить лот"), "add_lot"},
      {u("мои лоты"), "my_lots"},
      {u("депозиты"), "inventory"},
      {u("завершить работу"), "logout"},
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

  local w, h = gpu.getResolution()
  local d = gui.Dialog.new(math.floor(w*0.8), math.floor(h*0.8), parent)

  local cw, ch = d:contentSize()
  d:addChild(gui.Label.new(cw, u("Мои лоты")), 0, 0)

  -- lot table
  local lots = exchange:getAllLots()
  local t = {}
  for i=1,#lots do
    local lot = lots[i]
    if lot.username == username then
      t[#t+1] = {stackToString(lot.from), stackToString(lot.to), tostring(lot.count)}
    end
  end
  local sizeCount = 7
  local sizeStack = math.floor((cw - sizeCount) / 2)
  local tbl = d:addChild(gui.Table.new(cw, ch-5, t, {sizeStack, sizeStack, sizeCount, sizeDelete}), 0, 3):setRowColors(0x000000, 0x111111)--:setColor(0xc0c000)
  tbl.filterEvent = function(self, ev)
    return
  end

  d:addChild(gui.Label.new(sizeStack, u("Продажа"), true), 0, 2):setColor(0x333333):setTextColor(0xFFBB24)
  d:addChild(gui.Label.new(sizeStack, u("Покупка"), true), sizeStack, 2):setColor(0x333333):setTextColor(0xFFBB24)
  d:addChild(gui.Label.new(sizeCount, u("Кол-во"), true), sizeStack*2, 2):setColor(0x333333):setTextColor(0xFFBB24)

  local btn = gui.SimpleButton.new(nil, nil, "close", u("закрыть"))
  d:addChild(btn, math.floor((d.xSize-2-btn.xSize)/2), d.ySize-4):setColor(0x00c000)

  local r = d:exec()
end

local initialStacks = {
    {label="Stone", size=64},
    {label="Diamonds", size=3},
    {label="Computer case Tier 3", size=2},
  }

function showAddDepositsScreen(username, parent)
  trade_robot.startGathering()
  local d = gui.MessageBox.new(u("Вросьте предметы на робота"), {u("Продолжить"), "continue"}, parent)
  d:exec()
  trade_robot.stopGathering()

  local ok = true
  for slot=1,storage.getOutputInventorySize() do
    local s = storage.getStackInOutputSlot(slot)
    if s ~= nil then
      local freeSpace = trade_db:getFreeSpaceForStack(username, s)
      if freeSpace < s.size then
        ok = false
        break
      else
        storage.moveToStorage(slot)
        trade_db:addStack(username, s)
      end
    end
  end
  if not ok then
    local mb = gui.MessageBox.new(u("Недостаточно места"), nil, d)
    local r = mb:exec()
  end
  trade_robot.dropAll()
end

function showDepositsScreen(parent)
  local username = gui.getCurrentOwner()
  if username == nil then
    return false
  end

  local w, h = gpu.getResolution()
  local d = gui.Dialog.new(math.floor(w*0.8), math.floor(h*0.8), parent)

  local cw, ch = d:contentSize()

  d:addChild(gui.Label.new(cw, u("Баланс и депозиты")), 0, 0)

  local stacks = trade_db:getAllUserStacks(username)
  --stacks = initialStacks
  local t = {}
  for _,stack in ipairs(stacks) do
    t[#t+1] = {stackToString(stack), u("забрать")}
  end
  local sizeLabel = 8
  local sizeStack = cw - 2 - sizeLabel
  local tbl = d:addChild(gui.Table.new(cw, ch-4, t, {sizeStack, sizeLabel}), 0, 2):setRowColors(0x000000, 0x111111)--:setColor(0xc0c000)
  tbl.filterEvent = function(self, ev)
    if type(ev) == "table" then
      local row = ev[1]
      if ev[2] == 2 then
        table.remove(initialStacks, row)
        return 'respawn'
      end
    end
  end

  local btnAdd = d:addChild(gui.SimpleButton.new(nil, nil, "add", u("добавить")), 0, ch-1):setColor(0x00c000)
  btnAdd.filterEvent = function(self, ev)
    showAddDepositsScreen(username, d)
    d:redraw()
  end

  local btn = gui.SimpleButton.new(nil, nil, "close", u("закрыть"))
  d:addChild(btn, cw-btn.xSize, ch-1):setColor(0x00c000)

  return d:exec()
end

local quit = false

function mainLoop()
  gui.setTimeout(guiTimeout)

  local s = gui.Screen.new(0)
  --s:addChild(gui.SimpleButton.new(10, 1, "exit", "exit"), 10, 0):setColor(0xc00000)

  drawMainScreen(s)

  s:redraw()

  pcall(trade_robot.stopGathering)
  pcall(trade_robot.dropAll)

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
      if inputLot(s) ==true then
        local mb = gui.MessageBox.new(u("Теперь вам нужно добавить предметы в разделе \"инвентарь\""), nil, s)
        mb:exec()
      end
      return
    end
    if ev == "my_lots" then
      showUserLots(s)
      return
    end
    if ev == "inventory" then
      while true do
        local r = showDepositsScreen(s)
        if r ~= 'respawn' then
          break
        end
      end
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

function mainLoopStub()
  local s = gui.Screen.new(0)
  s:redraw()

  local d = gui.MessageBox.new(u("Скоро открытие"), nil, s)
  local r = d:exec()
  computer.beep(523, 0.2);
  computer.beep(652, 0.2);
  computer.beep(784, 0.2);
end

if underConstruction then
  mainLoop = mainLoopStub
end

clearScreen()
while not quit do
  local result, reason = pcall(mainLoop)

  if result == false then
    if emulator then
      if reason == "exit" then
        break
      end
      clearScreen()
      term.setCursor(1,1)
      print(reason)
      return
    end
  else
    -- Report error
  end
end
clearScreen()
