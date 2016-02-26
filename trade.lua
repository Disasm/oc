local component = require("component")
local file_serialization = require("libcraft/file_serialization")
local gpu = component.gpu
term = require("term")

package.loaded["gui"] = nil
_G["gui"] = nil
gui = require("gui")

gpu.setBackground(0x000000)
gpu.setForeground(0xffffff)

local s = gui.Screen.new(0x0000a0)
s:addChild(gui.SimpleButton.new(10, 1, "exit", "exit", 0xc00000), 5, 7)
s:addChild(gui.Button.new(10, 3, "btn", "show", false), 27, 20)
s:addChild(gui.Label.new(11, "label"), 10, 4)
--s:addChild(gui.Frame.new(31, 10, 0x00c000), 20, 5):setColor(0x00c000)
local t = {{123, "text1"}, {456, "text2  !!!"},
{124, "text1"}, {125, "text1"}, {126, "text1"},
{127, "text1"}, {128, "text1"}, {129, "text1"},
{130, "text1"}, {131, "text1"}, {132, "text1"},
{133, "text1"}, {134, "text1"}, {135, "text1"}}
s:addChild(gui.Table.new(31, 10, t, {5,10}), 20, 5):setColor(0x00c000)
s:addChild(gui.ShadowedButton.new(10, 1, "exit", "exit", 0xc00000), 5, 12)
s:addChild(gui.LargeSpinBox.new(5, 1, 0, 4096, 4), 20, 1):setColor(0x00c0c0)

s:redraw()

while true do
  local ev = s:pullEvent()
  if ev == "btn" then
    --local d = gui.Dialog.new(43, 10, s)
    local d = gui.MessageBox.new("This is MessageBox", nil, s)
    d:setColor(0xcc0000)
    --d:addChild(Button.new(11, 3, "close", "Close", false), 5, 3)
    d:exec()
  end
  if ev == "exit" then
    gpu.setBackground(0x000000)
    gpu.setForeground(0xffffff)
    term.setCursor(1,1)
    break
  end
  if type(ev) == "table" then
    term.setCursor(1,1)
    print(table.unpack(ev))
  end
end

