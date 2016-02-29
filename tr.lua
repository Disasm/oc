local file_serialization = require("file_serialization")

tr = {}

function tr:load()
  self.map = file_serialization.load("/tr.txt")
  if self.map == nil then
    self.map = {}
  end
end

function tr:save()
  file_serialization.save("/tr.txt", self.map, true)
end

function tr:translate(str)
  if self.map == nil then
    self:load()
  end
  local t = self.map[str]
  if t == nil then
    t = str
    self.map[str] = t
    self:save()
  end
  return t
end

tr = setmetatable(tr, {
  __call = function(t, str)
    return t:translate(str)
  end
})

return tr
