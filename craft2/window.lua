local component = require("component")
local gpu = component.gpu
local text = require("text")
local term = require("term")
local unicode = require("unicode")

local window = {}
function window.create(x, y, width, height)
  local t = {}
  t.x = x
  t.y = y
  t.w = width
  t.h = height
  t.write = function(self, s)
    for line in text.wrappedLines(s, self.w, self.w) do
      gpu.copy(self.x, self.y+1, self.w, self.h-1, 0, -1)
      gpu.fill(self.x, self.y+self.h-1, self.w, 1, " ")
      gpu.set(self.x, self.y+self.h-1, line)
      term.setCursor(self.x+unicode.wlen(line), self.y+self.h-1)
    end
  end
  t.clear = function(self)
    gpu.fill(self.x, self.y, self.w, self.h, " ")
  end
  return t
end

return window
