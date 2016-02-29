local file_serialization = require("file_serialization")
local item_db = require("trade_db")
local tr = require("tr")

local makeStack = item_db.makeStack

function gcd(a, b)
  if b ~= 0 then
    return gcd(b, a%b)
  else
    return math.abs(a)
  end
end

local ex = {}

function ex:load()
  self.lots = file_serialization.load("/user_lots.txt")
  if self.lots == nil then
    self.lots = {}
    self.lots.n = 0
  end
end

function ex:save()
  file_serialization.save("/user_lots.txt", self.lots)
end

function ex:addLot(username, fromStack, toStack, count)
  local lot = {}
  self.lots.n = self.lots.n + 1
  lot.id = self.lots.n
  
  local n = gcd(fromStack.size, toStack.size)
  
  lot.from = makeStack(fromStack, math.floor(fromStack.size / n))
  lot.to = makeStack(toStack, math.floor(toStack.size / n))
  lot.count = count * n
  lot.username = username
  self.lots[lot.id] = lot
end

function ex:exchange(lotId, username2, count)
  local lot = self.lots[lotId]
  if lot == nil then
    error(tr("No such lot"))
  end
  if username2 == lot.username then
    return
  end
  if count <= 0 then
    error(tr("exchange()s: Invalid parameters"))
  end
  local fromStack = makeStack(lot.from, lot.from.size * count)
  local toStack = makeStack(lot.to, lot.to.size * count)
  if item_db:getStackSize(username2, fromStack) < fromStack.size then
    error(tr("Buyer has insufficient items"))
  end
  if item_db:getStackSize(lot.username, toStack) < toStack.size then
    error(tr("Seller has insufficient items"))
  end
  if item_db:getFreeSpaceForStack(username2, toStack) < toStack.size then
    error(tr("Buyer has insufficient space"))
  end
  if item_db:getFreeSpaceForStack(lot.username, fromStack) < fromStack.size then
    error(tr("Seller has insufficient space"))
  end
end

function ex:getMaxExchangeCount(lotId, username2)
  local lot = self.lots[lotId]
  if lot == nil then
    return 0
  end
  if username2 == lot.username then
    return 0
  end
  
  local fromStack = makeStack(lot.from)
  local toStack = makeStack(lot.to)
  
  local cnt1 = item_db:getStackSize(username2, fromStack)
  local cnt2 = item_db:getStackSize(lot.username, toStack)
  local free1 = item_db:getFreeSpaceForStack(username2, toStack)
  local free2 = item_db:getFreeSpaceForStack(lot.username, fromStack)
  
  local n1 = math.floor(cnt1 / fromStack.size)
  local n2 = math.floor(cnt2 / toStack.size)
  local n3 = math.floor(free1 / toStack.size)
  local n4 = math.floor(free2 / fromStack.size)
  return math.min(math.min(n1, n2), math.min(n3, n4))
end

return ex
