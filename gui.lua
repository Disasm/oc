local unicode = require("unicode")
local component = require("component")
local event = require("event")
local gpu = component.gpu

local aux = {
  --              tl      tr      br      bl      hor     vert
  singleChars = { 0x250c, 0x2510, 0x2518, 0x2514, 0x2500, 0x2502 },
  doubleChars = { 0x2554, 0x2557, 0x255d, 0x255a, 0x2550, 0x2551 },
}

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
    for i = 1,#self.children do
      local child = self.children[i]
      if inBox(event, child) then
        local ev = child:translateEvent(event)
        if ev ~= nil then
          return ev
        end
      end
    end
    return self.event
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
  return w
end
function Widget.new0()
  return Widget.new(0, 0, nil)
end


local ShadowedWidget = {}
function ShadowedWidget.new(xSize, ySize, event, color)
  local w = Widget.new(xSize+1, ySize+1, event)
  w.backgroundColor = color
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
function Label.new(xSize, text)
  local w = Widget.new(xSize, 1, nil)
  w.text = text
  w.draw = function(self)
    w:clear()
    local text = self.text
    if string.len(text) > self.xSize then
      text = string.sub(text, 1, self.xSize)
    end
    local dx = math.floor((self.xSize - string.len(self.text)) / 2)
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
function ShadowedFrame.new(xSize, ySize, color, double)
  local w = ShadowedWidget.new(xSize+2, ySize+2, nil, color)
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
  return string.len(text)+2, 3
end


local SimpleButton = {}
function SimpleButton.new(xSize, ySize, event, text, color)
  local w = Widget.new(xSize, ySize, event)
  w.backgroundColor = color
  w.draw = function(self)
    --local oldBg = gpu.getBackground()
    --gpu.setBackground(self.buttonColor)
    self:clear()
    self:drawChildren()
    --gpu.setBackground(oldBg)
  end
  w:addChild(Label.new(xSize, text), 0, math.floor(ySize/2))
  return w
end


local ShadowedButton = {}
function ShadowedButton.new(xSize, ySize, event, text, color)
  local w = ShadowedWidget.new(xSize, ySize, event, color)
  w:addChild(Label.new(xSize, text), 0, math.floor(ySize/2))
  return w
end
function ShadowedButton.dimensions(text)
  return string.len(text)+1, 2
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

  local oldTranslateEvent = w.translateEvent
  w.translateEvent = function(self, event)
    local ev = oldTranslateEvent(self, event)
    if ev == nil then
      return
    end
    if ev == "less" then
      w.sb_value = w.sb_value - w.sb_step
    end
    if ev == "more" then
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
  w.pullEvent = function(self)
    while true do
      local ev = table.pack(event.pull("touch"))
      ev = self:translateEvent(ev)
      if ev ~= nil then
        return ev
      end
    end
  end
  return w
end


local Dialog = {}
function Dialog.new(xSize, ySize, parent)
  local w = ShadowedFrame.new(xSize, ySize, 0x404040, false)

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
    self:draw()
    local ev
    while true do
      ev = table.pack(event.pull("touch"))
      ev = self:translateEvent(ev)
      if ev ~= nil then
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
  local textWidth = string.len(text)
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


export = {
  Label = Label,
  Frame = Frame,
  ShadowedFrame = ShadowedFrame,
  Button = Button,
  SimpleButton = SimpleButton,
  ShadowedButton = ShadowedButton,
  SpinBox = SpinBox,
  Screen = Screen,
  Dialog = Dialog,
  MessageBox = MessageBox,
}
return export