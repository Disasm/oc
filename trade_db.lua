local file_serialization = require("file_serialization")
local util = require("stack_util")

local stacksPerUser = 5

function stackHash(stack)
  return stack.name.."_"..stack.label
end

function makeStack(stack, newSize)
  newStack = {}
  for k,v in pairs(stack) do
    newStack[k] = v
  end
  if newSize ~= nil then
    newStack.size = newSize
  end
  return newStack
end

local db = {}

db.makeStack = makeStack

function db:load()
  self.items = file_serialization.load("/user_items.txt")
  if self.items == nil then
    self.items = {}
  end
end

function db:save()
  file_serialization.save("/user_items.txt", self.items)
end

function db:getAllUserStacks(username)
  local items = self.items[username]
  if items == nil then
    return {}
  end
  local r = {}
  for _,stack in ipairs(items) do
    r[#r+1] = util.makeStack(stack)
  end
  return r
end

function db:getStackSize(username, stack)
  local items = self.items[username]
  if items == nil then
    return 0
  end
  local s = items[stackHash(stack)]
  if s == nil then
    return 0
  else
    return s.size
  end
end

function db:addStack(username, stack)
  local items = self.items[username]
  if items == nil then
    items = {}
    self.items[username] = items
  end

  local hash = stackHash(stack)
  local s = items[hash]
  if s == nil then
    s = makeStack(stack)
  else
    s = makeStack(s, s.size + stack.size)
  end
  if s.size > 0 then
    items[hash] = s
  else
    items[hash] = nil
  end
  self:save()
end

function db:removeStack(username, stack)
  s = makeStack(stack, -stack.size)
  self:addStack(username, s)
end

function db:getFreeSpaceForStack(username, stack)
  local items = self.items[username]
  if items == nil then
    items = {}
    self.items[username] = items
  end

  local hash = stackHash(stack)

  local n = 0
  for h,s in pairs(items) do
    if h ~= hash then
      n = n + math.ceil(s.size / 64)
    end
  end
  if n >= stacksPerUser then
    return 0
  end

  local free = (stacksPerUser - n) * 64
  if items[hash] == nil then
    return free
  else
    free = free - items[hash].size
    if free < 0 then
      return 0
    else
      return free
    end
  end
end

return db
