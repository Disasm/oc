local file_serialization = require("file_serialization")
local util = require("stack_util")

db = {}

function db:load()
  self.items = file_serialization.load("/stack_db.txt")
  if self.items == nil then
    self.items = {}
  end
  self.itemMap = {}
  for k,v in pairs(self.items) do
    self.itemMap[util.stackHash(v)] = true
  end
  table.sort(self.items, function(a,b) return a.label > b.label end)
end

function db:save()
  file_serialization.save("/stack_db.txt", self.items)
end

function db:add(stack)
  if self.itemMap[util.stackHash(stack)] == nil then
    self.itemMap[util.stackHash(stack)] = true
    self.items[#self.items+1] = util.makeStack(stack)
    table.sort(self.items, function(a,b) return a.label > b.label end)
    self:save()
  end
end

function db:getAll()
  return self.items
end

return db
