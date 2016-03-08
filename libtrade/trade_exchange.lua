local file_serialization = require("file_serialization")
local trade_db = require("trade_db")
local util = require("stack_util")
local tr = require("tr")

function gcd(a, b)
  if b ~= 0 then
    return gcd(b, a%b)
  else
    return math.abs(a)
  end
end

function copyLot(lot)
  local lot_copy = {}
  for k,v in pairs(lot) do
    lot_copy[k] = v
  end
  lot_copy.from = util.makeStack(lot.from)
  lot_copy.to = util.makeStack(lot.to)
  return lot_copy
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

  lot.from = util.makeStack(fromStack, math.floor(fromStack.size / n))
  lot.to = util.makeStack(toStack, math.floor(toStack.size / n))
  lot.count = count * n
  lot.username = username
  self.lots[lot.id] = lot

  self:save()
end

function ex:deleteLot(lotId)
  self.lots[lotId] = nil
end

function ex:getLot(lotId)
  local lot = self.lots[lotId]
  if lot == nil then
    return nil
  end

  local lot_copy = {}
  for k,v in pairs(lot) do
    lot_copy[k] = v
  end
  return lot_copy
end

function ex:countUserLots(username)
  local cnt = 0
  for id,lot in pairs(self.lots) do
    if type(id) == "number" then
      if lot.username == username then
        cnt = cnt + 1
      end
    end
  end
  return cnt
end

function ex:getAllLots(real_counts)
  real_counts = not not real_counts
  r = {}
  for id,lot in pairs(self.lots) do
    if type(id) == "number" then
      if real_counts then
        local real_count = self:getRealExchangeCount(id)
        if real_count > 0 then
          local lot_copy = copyLot(lot)
          lot_copy.count = real_count
          r[#r+1] = lot_copy
        end
      else
        r[#r+1] = copyLot(lot)
      end
    end
  end
  return r
end

function ex:exchange(lotId, username2, count)
  local lot = self.lots[lotId]
  if lot == nil then
    error(tr("No such lot"))
  end
  if username2 == lot.username then
    return
  end
  if count <= 0 or count > lot.count then
    error(tr("exchange(): Invalid parameters"))
  end
  local fromStack = util.makeStack(lot.from, lot.from.size * count)
  local toStack = util.makeStack(lot.to, lot.to.size * count)
  if trade_db:getStackSize(username2, toStack) < toStack.size then
    error(tr("Buyer has insufficient items"))
  end
  if trade_db:getStackSize(lot.username, fromStack) < fromStack.size then
    error(tr("Seller has insufficient items"))
  end
  if trade_db:getFreeSpaceForStack(username2, fromStack) < fromStack.size then
    error(tr("Buyer has insufficient space"))
  end
  if trade_db:getFreeSpaceForStack(lot.username, toStack) < toStack.size then
    error(tr("Seller has insufficient space"))
  end

  trade_db:removeStack(lot.username, fromStack)
  trade_db:removeStack(username2, toStack)

  trade_db:addStack(lot.username, toStack)
  trade_db:addStack(username2, fromStack)

  lot.count = lot.count - count
  if lot.count <= 0 then
    self.lots[lotId] = nil
  end
  self:save()
end


-- Exchange count that owner can exchange given his items and free space
function ex:getRealExchangeCount(lotId)
  local lot = self.lots[lotId]
  if lot == nil then
    return 0
  end

  local fromStack = util.makeStack(lot.from)
  local toStack = util.makeStack(lot.to)

  local cnt1 = trade_db:getStackSize(lot.username, fromStack)
  local free1 = trade_db:getFreeSpaceForStack(lot.username, toStack)

  local n1 = math.floor(cnt1 / fromStack.size)
  local n2 = math.floor(free1 / toStack.size)
  return math.min(n1, n2)
end


-- Exchange count that other user can exchange given his and owner's items and free space
function ex:getMaxExchangeCount(lotId, username2)
  local lot = self.lots[lotId]
  if lot == nil then
    return 0
  end
  if username2 == lot.username then
    return 0
  end

  local fromStack = util.makeStack(lot.from)
  local toStack = util.makeStack(lot.to)

  local cnt1 = trade_db:getStackSize(username2, toStack)
  local cnt2 = trade_db:getStackSize(lot.username, fromStack)
  local free1 = trade_db:getFreeSpaceForStack(username2, fromStack)
  local free2 = trade_db:getFreeSpaceForStack(lot.username, toStack)

  local n1 = math.floor(cnt1 / toStack.size)
  local n2 = math.floor(cnt2 / fromStack.size)
  local n3 = math.floor(free1 / fromStack.size)
  local n4 = math.floor(free2 / toStack.size)
  return math.min(math.min(n1, n2), math.min(n3, n4))
end

return ex
