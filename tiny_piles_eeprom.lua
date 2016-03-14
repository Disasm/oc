local isBios = false
if component then
    -- bios
    isBios = true
else
    -- OpenOS
    component = require("component")
    computer = component.computer
end

local sides = {
  down = 0,
  top = 1,
  back = 2,
  front = 3,
  right = 4,
  left = 5,
}

function sleep(timeout)
  local deadline = computer.uptime() + timeout
  repeat
    computer.pullSignal(0.1)
  until computer.uptime() >= deadline
end
if not isBios then
    sleep = os.sleep
end


robot = component.proxy(component.list("robot")())
ic = component.proxy(component.list("inventory_controller")())
craft = component.proxy(component.list("crafting")()).craft

function clear()
  for i = 1, 16 do
    if robot.count(i) > 0 then
      robot.select(i)
      robot.drop(sides.down)
    end
  end
end

local side = sides.down

function pull_items(slots, count, target_slot)
  robot.select(target_slot)
  local required_count = count - robot.count(target_slot)
  for i, slot in ipairs(slots) do
    if required_count <= 0 then
      return true
    end
    ic.suckFromSlot(side, slot, required_count)
    required_count = count - robot.count(target_slot)
    if required_count <= 0 then
      return true
    end
  end

  computer.beep()
  return false
end

craft_table_slots = {1, 2, 3, 5, 6, 7, 9, 10, 11}

function process()
  local counts = {}
  local slots = {}
  local n = ic.getInventorySize(side)
  for i = 1, n do
    local stack = ic.getStackInSlot(side, i)
    if stack then
      counts[stack.label] = (counts[stack.label] or 0) + stack.size
      if not slots[stack.label] then slots[stack.label] = {} end
      local cnt = #(slots[stack.label])
      slots[stack.label][cnt + 1] = i
    end
  end
  for label, count in pairs(counts) do
    if string.find(label, "Tiny Pile of") ~= nil then
      local craft_count = math.floor(count / 9)
      if craft_count > 64 then craft_count = 64 end
      if craft_count > 0 then
        clear()
        local current_slots = slots[label]
        for i, target_slot in ipairs(craft_table_slots) do
          if not pull_items(current_slots, craft_count, target_slot) then
            clear()
            return
          end
        end
        robot.select(16)
        craft(craft_count)
        robot.drop(sides.front)
      end
    end
  end
end


while true do
  process()
  sleep(60)
end
