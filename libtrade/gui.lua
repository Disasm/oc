local unicode = require("unicode")
local component = require("component")
local event = require("event")
local gpu = component.gpu
local computer = require("computer")

local aux = {
  --              tl      tr      br      bl      hor     vert
  singleChars = { 0x250c, 0x2510, 0x2518, 0x2514, 0x2500, 0x2502 },
  doubleChars = { 0x2554, 0x2557, 0x255d, 0x255a, 0x2550, 0x2551 },
  arrowUp = 0x25b2,
  arrowDown = 0x25bc,
}

local restrictEvents = true
local currentOwner = nil
local currentTimeout = 1e6
local currentDeadline = computer.uptime() + currentTimeout

function startUserSession()
  computer.pushSignal("user_login")
  currentDeadline = computer.uptime() + currentTimeout
end

function terminateUserSession()
  computer.pushSignal("user_logout")
  currentDeadline = computer.uptime() + 1e6
  currentOwner = nil
  error('exit')
end

function updateUserSession()
  if currentOwner == nil then
    currentDeadline = computer.uptime() + 1e6
  else
    currentDeadline = computer.uptime() + currentTimeout
  end
end

function checkAutoLogout()
  if computer.uptime() > currentDeadline then
    terminateUserSession()
  end
end

function filterEvent(event)
  if event[1] ~= "touch" then
    return
  end
  updateUserSession()
  if not restrictEvents then
    return event
  end
  local w,h = gpu.getResolution()
  if event[3] == w and event[4] == 1 then
    terminateUserSession()
    return
  end
  if currentOwner == nil then
    currentOwner = event[6]
    startUserSession()
    return event
  else
    if currentOwner ~= event[6] then
      return
    else
      return event
    end
  end
end

function aux:drawBox(x, y, w, h, double)
  local chars
  if double then
    chars = self.doubleChars
  else
    chars = self.singleChars
  end
  gpu.set(x, y, unicode.char(chars[1]))
  gpu.set(x+w-1, y, unicode.char(chars[2]))
  gpu.set(x+w-1, y+h-1, unicode.char(chars[3]))
  gpu.set(x, y+h-1, unicode.char(chars[4]))
  for xi = 1, w-2 do
    gpu.set(x+xi, y, unicode.char(chars[5]))
    gpu.set(x+xi, y+h-1, unicode.char(chars[5]))
  end
  for yi = 1, h-2 do
    gpu.set(x, y+yi, unicode.char(chars[6]))
    gpu.set(x+w-1, y+yi, unicode.char(chars[6]))
  end
end


local Widget = {}
function Widget.new(xSize, ySize, event)
  local w = {}
  w.xSize = xSize
  w.ySize = ySize
  w.xSizeHint = 1
  w.ySizeHint = 1
  w.backgroundColor = nil
  w.foregroundColor = nil
  w.setColor = function(self, color)
    self.backgroundColor = color
    for i = 1,#self.children do
      local child = self.children[i]
      child:setColor(color)
    end
    return self
  end
  w.updateColor = function(self, color)
    if self.backgroundColor == nil then
      self.backgroundColor = color
    end
    for i = 1,#self.children do
      local child = self.children[i]
      child:updateColor(self.backgroundColor)
    end
    return self
  end
  w.setTextColor = function(self, color)
    self.foregroundColor = color
    for i = 1,#self.children do
      local child = self.children[i]
      child:setTextColor(color)
    end
    return self
  end
  w.event = event
  w.pos = function(self)
    return self.x, self.y
  end
  w.size = function(self)
    return self.xSize, self.ySize
  end
  w.contentSize = w.size
  w.setSize = function(self, xSize, ySize)
    self.xSize = xSize
    self.ySize = ySize
    self:sizeChanged()
    return self
  end
  w.setContentSize = w.setSize
  w.sizeChanged = function(self)
    if self.layout ~= nil then
      self.layout:sizeChanged()
    end
  end
  w.updatePosition = function(self)
    if self.parent ~= nil then
      if (self.parent.x == nil) or (self.parent.y == nil) then
        return
      end
      self.x = self.parent.x + self.relx
      self.y = self.parent.y + self.rely
    end
    for i = 1,#self.children do
      local child = self.children[i]
      child:updatePosition()
    end
  end
  w.children = {}
  w.addChild = function(self, w, relx, rely)
    self.children[#self.children+1] = w
    w.relx = relx
    w.rely = rely
    w.parent = self
    w:updatePosition()
    w:updateColor(w.parent.backgroundColor)
    if w.foregroundColor == nil then
      w.foregroundColor = w.parent.foregroundColor
    end
    return w
  end
  w.setLayout = function(self, layout)
    self.layout = layout
    self:addChild(layout, 0, 0)
    layout:sizeChanged()
  end

  local function inBox(event, w)
    if event[1] ~= "touch" then
      return false
    end

    local x, y = event[3], event[4]
    return (w.x <= x) and (x < w.x+w.xSize) and
           (w.y <= y) and (y < w.y+w.ySize)
  end
  w.translateEvent = function(self, event)
    if not inBox(event, self) then
      return
    end
    local result = nil
    for i = 1,#self.children do
      local child = self.children[i]
      if inBox(event, child) then
        local ev = child:translateEvent(event)
        if ev ~= nil then
          result = ev
          break
        end
      end
    end
    if result == nil then
      result = self.event
    end
    if result ~= nil then
      result = self:filterEvent(result)
    end
    return result
  end
  w.filterEvent = function(self, event)
    return event
  end
  w.drawChildren = function(self)
    for i = 1,#self.children do
      local child = self.children[i]
      child:drawColored()
    end
  end
  w.draw = function(self)
    self:clear()
    self:drawChildren()
  end
  w.drawColored = function(self)
    local oldBg = gpu.setBackground(self.backgroundColor or 0x000000)
    local oldFg = gpu.setForeground(self.foregroundColor or 0xffffff)
    w:draw()
    gpu.setBackground(oldBg)
    gpu.setForeground(oldFg)
  end
  w.redraw = w.drawColored
  w.clear = function(self)
    gpu.fill(self.x, self.y, self.xSize, self.ySize, " ")
  end
  w.update = function(self)
  end
  return w
end
function Widget.new0()
  return Widget.new(0, 0, nil)
end


local ShadowedWidget = {}
function ShadowedWidget.new(xSize, ySize, event)
  local w = Widget.new(xSize+1, ySize+1, event)
  w.draw = function(self)
    -- clear
    gpu.setBackground(self.backgroundColor)
    gpu.fill(self.x, self.y, self.xSize-1, self.ySize-1, " ")

    -- draw shadow
    local oldFg = gpu.setForeground(0x000000)
    local _, _, bg = gpu.get(self.x+self.xSize-1, self.y)
    gpu.setBackground(bg)
    gpu.set(self.x+self.xSize-1, self.y, unicode.char(0x2584))

    gpu.setBackground(0x000000)
    gpu.fill(self.x+self.xSize-1, self.y+1, 1, self.ySize-2, unicode.char(0x2588))

    for xi=1,self.xSize-1 do
      local _, _, bg = gpu.get(self.x+xi, self.y+self.ySize-1)
      gpu.setBackground(bg)
      gpu.set(self.x+xi, self.y+self.ySize-1, unicode.char(0x2580))
    end
    gpu.setForeground(oldFg)

    -- draw children
    self:drawChildren()
  end
  w.contentSize = function(self)
    return self.xSize-1, self.ySize-1
  end
  return w
end


local Label = {}
function Label.new(xSize, text, alignLeft)
  alignLeft = not not alignLeft
  local w = Widget.new(xSize, 1, nil)
  w.text = text
  w.draw = function(self)
    w:clear()
    local text = self.text
    if unicode.wlen(text) > self.xSize then
      text = unicode.sub(text, 1, self.xSize)
    end
    local dx
    if alignLeft then
      dx = 0
    else
      dx = math.floor((self.xSize - unicode.wlen(self.text)) / 2)
      if dx < 0 then
        dx = 0
      end
    end
    gpu.set(self.x + dx, self.y, text)
  end
  return w
end


local Frame = {}
function Frame.new(xSize, ySize, double)
  local w = Widget.new(xSize+2, ySize+2, nil)
  w.double = not not double
  w.draw = function(self)
    self:clear()
    aux:drawBox(self.x, self.y, self.xSize, self.ySize, self.double)
    self:drawChildren()
  end
  local origAddChild = w.addChild
  w.addChild = function(self, w, relx, rely)
    return origAddChild(self, w, relx+1, rely+1)
  end
  w.contentSize = function(self)
    return self.xSize-2, self.ySize-2
  end
  return w
end


local ShadowedFrame = {}
function ShadowedFrame.new(xSize, ySize, double)
  local w = ShadowedWidget.new(xSize+2, ySize+2, nil)
  w.double = not not double

  w:addChild(Frame.new(xSize, ySize, double), 0, 0)
  local origAddChild = w.addChild
  w.addChild = function(self, w, relx, rely)
    return origAddChild(self, w, relx+1, rely+1)
  end
  local oldContentSize = w.contentSize
  w.contentSize = function(self)
    local xs, ys = oldContentSize(self)
    return xs-2, ys-2
  end
  return w
end


local Button = {}
function Button.new(xSize, ySize, event, text, double)
  local b = Widget.new(xSize, ySize, event)
  b:addChild(Frame.new(xSize-2, ySize-2, double), 0, 0)
  b:addChild(Label.new(xSize-2, text), 1, 1)
  return b
end
function Button.dimensions(text)
  return unicode.len(text)+2, 3
end


local SimpleButton = {}
function SimpleButton.new(xSize, ySize, event, text)
  xSize = xSize or (unicode.len(text)+2)
  ySize = ySize or 1
  local w = Widget.new(xSize, ySize, event)
  w.draw = function(self)
    self:clear()
    self:drawChildren()
  end
  w:addChild(Label.new(xSize, text), 0, math.floor(ySize/2))
  return w
end


local ShadowedButton = {}
function ShadowedButton.new(xSize, ySize, event, text)
  local w = ShadowedWidget.new(xSize, ySize, event)
  w:addChild(Label.new(xSize, text), 0, math.floor(ySize/2))
  return w
end
function ShadowedButton.dimensions(text)
  return unicode.len(text)+1, 2
end


local SpinBox = {}
function SpinBox.new(xSize, value, minValue, maxValue, step)
  local w = Widget.new(xSize+2, 1)
  w.sb_value = value or 0
  w.sb_minValue = minValue or 0
  w.sb_maxValue = maxValue or 100000
  w.sb_step = step or 1

  w:addChild(SimpleButton.new(1, 1, "less", "<"), 0, 0)
  w:addChild(SimpleButton.new(1, 1, "more", ">"), xSize+1, 0)
  w.sb_label = Label.new(xSize, tostring(w.sb_value))
  w:addChild(w.sb_label, 1, 0)

  w.filterEvent = function(self, ev)
    if ev == nil then
      return
    end

    if ev == "less" then
      w.sb_value = w.sb_value - w.sb_step
    else
      w.sb_value = w.sb_value + w.sb_step
    end
    if w.sb_value < w.sb_minValue then
      w.sb_value = w.sb_minValue
    end
    if w.sb_value > w.sb_maxValue then
      w.sb_value = w.sb_maxValue
    end
    w.sb_label.text = tostring(w.sb_value)
    w.sb_label:drawColored()
  end
  return w
end
function SpinBox.dimensions(xSize)
  return xSize+2, 1
end


local LargeSpinBox = {}
function LargeSpinBox.new(xSize, value, minValue, maxValue)
  local w = Widget.new(xSize, 3)
  w.sb_value = value or 0
  w.sb_minValue = minValue or 0
  w.sb_maxValue = maxValue or 100000
  w.sb_step = step or 1

  local dx = math.floor((xSize - 3) / 2)

  w:addChild(SimpleButton.new(1, 1, "100", "+"), dx+0, 0)
  w:addChild(SimpleButton.new(1, 1, "10", "+"), dx+1, 0)
  w:addChild(SimpleButton.new(1, 1, "1", "+"), dx+2, 0)
  w.sb_label = Label.new(xSize, tostring(w.sb_value))
  w:addChild(w.sb_label, 0, 1)
  w:addChild(SimpleButton.new(1, 1, "-100", "-"), dx+0, 2)
  w:addChild(SimpleButton.new(1, 1, "-10", "-"), dx+1, 2)
  w:addChild(SimpleButton.new(1, 1, "-1", "-"), dx+2, 2)

  w.filterEvent = function(self, ev)
    if ev == nil then
      return
    end
    local delta = tonumber(ev)
    if delta ~= 0 then
      w.sb_value = w.sb_value + delta
    end
    if w.sb_value < w.sb_minValue then
      w.sb_value = w.sb_minValue
    end
    if w.sb_value > w.sb_maxValue then
      w.sb_value = w.sb_maxValue
    end
    w.sb_label.text = tostring(w.sb_value)
    w.sb_label:drawColored()
  end
  return w
end
function LargeSpinBox.dimensions(xSize)
  return xSize, 3
end


local Table = {}
function Table.new(xSize, ySize, values, widths)
  local w = Widget.new(xSize, ySize)
  w.tab_values = values
  w.tab_widths = widths
  w.tab_offset = 0
  w.tab_labels = {}
  w.evenColor = 0x000000
  w.oddColor = 0x000000
  w.scrollbarColor = 0x333333

  local b1 = w:addChild(Label.new(2, unicode.char(aux.arrowUp)..unicode.char(aux.arrowUp)), xSize-2, 0)
  local b2 = w:addChild(Label.new(2, unicode.char(aux.arrowDown)..unicode.char(aux.arrowDown)), xSize-2, ySize-1)
  b1.event = "up"
  b2.event = "down"
  local disableScroll = (w.ySize >= #values)
  for y = 1,w.ySize do
    w.tab_labels[y] = {}
    local row = values[y]
    local offset = 0
    for x = 1,#widths do
      local value = ""
      if values[y] ~= nil then
        value = values[y][x] or ""
      end
      local labelWidth = widths[x] - 1
      if labelWidth <= 0 then
        labelWidth = 1
      end
      local label = Label.new(labelWidth, tostring(value), true)
      w:addChild(label, offset, y-1)
      w.tab_labels[y][x] = label
      offset = offset + widths[x]
    end
  end

  local oldTranslateEvent = w.translateEvent
  w.translateEvent = function(self, event)
    local ev = oldTranslateEvent(self, event)
    if ev ~= nil then
      if (ev == "up") and (not disableScroll) then
        w.tab_offset = w.tab_offset - 1
      end
      if (ev == "down") and (not disableScroll) then
        w.tab_offset = w.tab_offset + 1
      end
      if w.tab_offset < 0 then
        w.tab_offset = 0
      end
      if (w.tab_offset > (#w.tab_values-ySize)) and (not disableScroll) then
        w.tab_offset = (#w.tab_values-ySize)
      end
      w:redraw()
      return
    end

    if event[1] ~= "touch" then
      return
    end
    local x, y = event[3], event[4]
    if (w.x <= x) and (x < w.x+w.xSize-1) and
       (w.y <= y) and (y < w.y+w.ySize) then
      x = x - w.x
      y = y - w.y
    else
      return
    end

    local xindex = 0
    local offset = 0
    for i=1,#w.tab_widths do
      if offset <= x and x < offset + w.tab_widths[i] then
        xindex = i
        break
      end
      offset = offset + w.tab_widths[i]
    end
    if xindex == 0 then
      return
    end

    local yindex = 1 + y + w.tab_offset
    if yindex > #w.tab_values then
      return
    else
      ev = {yindex, xindex}
      ev = self:filterEvent(ev)
      return ev
    end
  end
  w.draw = function(self)
    self:clear()
    for y=1,w.ySize do
      for x=1,#w.tab_widths do
        if w.tab_values[y+w.tab_offset] ~= nil then
          w.tab_labels[y][x].text = tostring(w.tab_values[y+w.tab_offset][x])
        end
      end
    end

    local oldBg = gpu.setBackground(self.scrollbarColor)
    gpu.fill(self.x+self.xSize-2, self.y, 2, self.ySize, " ")
    gpu.setBackground(oldBg)

    for y=1,self.ySize do
      local color
      if (y%2) == 1 then
        color = self.evenColor
      else
        color = self.oddColor
      end
      local oldBg = gpu.setBackground(color)
      gpu.fill(self.x, self.y + y - 1, self.xSize - 2, 1, " ")
      gpu.setBackground(oldBg)
    end
    -- drow children without coloring
    for i = 1,#self.children do
      local child = self.children[i]
      local _,_,oldBg = gpu.get(child.x, child.y)
      oldBg = gpu.setBackground(oldBg)
      local oldFg = gpu.setForeground(child.foregroundColor or 0xffffff)
      child:draw()
      gpu.setForeground(oldFg)
      gpu.setBackground(oldBg)
    end
  end
  w.setRowColors = function(self, evenColor, oddColor)
    self.evenColor = evenColor
    self.oddColor = oddColor
    return self
  end

  return w
end


local Screen = {}
function Screen.new(bgColor)
  local w, h = gpu.getResolution()
  local w = Widget.new(w, h, nil)
  w.relx = 0
  w.rely = 0
  w.x = 1
  w.y = 1
  w.backgroundColor = bgColor or 0x000000
  w.foregroundColor = 0xffffff
  w:addChild(SimpleButton.new(1, 1, "exit", "X"), w.xSize-1, 0)
  w.pullEvent = function(self)
    while true do
      local ev = table.pack(event.pull(0.2, "touch"))
      checkAutoLogout()
      if ev ~= nil then
        ev = filterEvent(ev)
        if ev ~= nil then
          ev = self:translateEvent(ev)
          if ev ~= nil then
            return ev
          end
        end
      end
    end
  end
  return w
end


local Dialog = {}
function Dialog.new(xSize, ySize, parent)
  local w = ShadowedFrame.new(xSize, ySize, false)
  w:setColor(0x404040)

  local sw, sh = gpu.getResolution()
  w.relx = 0
  w.rely = 0
  w.x = math.floor((sw - xSize) / 2)
  w.y = math.floor((sh - ySize) / 2)
  w.dialogParent = parent
  w.exec = function(self)
    for i = 1,#self.children do
      local child = self.children[i]
      child:updatePosition()
    end
    if pcall(self.update, self) == false then return end
    self:draw()

    local ev
    while true do
      ev = table.pack(event.pull(0.2, "touch"))
      checkAutoLogout()
      if ev ~= nil then
        ev = filterEvent(ev)
        if ev ~= nil then
          ev = self:translateEvent(ev)
          if ev ~= nil then
            break
          end
        end
      end
      if pcall(self.update, self) == false then
        ev = nil
        break
      end
    end
    if self.dialogParent ~= nil then
      self.dialogParent:redraw()
    else
      self:clear()
    end
    return ev
  end
  return w
end


local MessageBox = {}
function MessageBox.new(text, buttons, parent)
  if buttons == nil then
    buttons = {"OK", "close"}
  end
  if type(buttons[1]) ~= "table" then
    buttons = {buttons}
  end

  -- TODO: multi-line text
  local textWidth = unicode.len(text)
  local buttonsWidth = #buttons - 1
  for i = 1,#buttons do
    local bw, bh = Button.dimensions(buttons[i][1])
    buttonsWidth = buttonsWidth + bw
  end
  local contentWidth = math.max(textWidth, buttonsWidth)
  local contentHeight = 3 + 1

  local w = Dialog.new(contentWidth + 2, contentHeight, parent)
  local cw, ch = w:contentSize()

  local dx = math.floor((cw - textWidth) / 2)
  w:addChild(Label.new(textWidth, text), dx, 0)

  local dx = math.floor((cw - buttonsWidth) / 2)
  for i = 1,#buttons do
    local btn = buttons[i]
    local bw, bh = Button.dimensions(btn[1])
    local btn = Button.new(bw, bh, btn[2], btn[1], false)
    w:addChild(btn, dx, 1)
    dx = dx + bw + 1
  end

  return w
end


gui = {
  Label = Label,
  Frame = Frame,
  ShadowedFrame = ShadowedFrame,
  Button = Button,
  SimpleButton = SimpleButton,
  ShadowedButton = ShadowedButton,
  SpinBox = SpinBox,
  LargeSpinBox = LargeSpinBox,
  Table = Table,
  Screen = Screen,
  Dialog = Dialog,
  MessageBox = MessageBox,

  getCurrentOwner = function()
    return currentOwner
  end,

  clearCurrentOwner = function()
    currentOwner = nil
  end,

  setIdealResolution = function()
    -- TODO: use getAspectRatio or getSize
    gpu.setResolution(71, 25)
  end,

  setTimeout = function(timeout)
    currentTimeout = timeout
    updateUserSession()
  end,
}
return gui
