local component = require("component")
local transposer = component.transposer 

local file_serialization = require("file_serialization")
local sides = require("sides")
local util = require("stack_util")
local event = require("event")
local unicode = require("unicode")

local itemDb = file_serialization.load("/db.txt") or {}
local itemDbHash = {}
for i, v in ipairs(itemDb) do 
  itemDbHash[util.stackHash(v)] = true
end

function addItemToDb(stack)
  local s = util.makeStack(stack)
  local h = util.stackHash(s)
  if itemDbHash[h] == nil then
    itemDbHash[h] = true 
    itemDb[#itemDb+1] = s
    print("Added: "..h)
  else
    print("Already exists: "..h)
  end
end


function waitYesNo()
    while true do
        local e, addr, ch, code, player = event.pull("key_down")
        ch = unicode.char(ch)
        if ch == 'y' then
            return 'y'
        end
        if ch == 'n' then
            return 'n'
        end
    end
end



local count = transposer.getInventorySize(sides.bottom)
while true do 
  for i = 1, count do 
    local stack = transposer.getStackInSlot(sides.bottom, i)      
    if stack then 
      addItemToDb(stack)
    end 
  end
  file_serialization.save("/db.txt", itemDb)
  component.computer.beep()
  print("Continue? [y/n]")
  if waitYesNo() == 'n' then break end 
end 
