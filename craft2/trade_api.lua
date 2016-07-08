local module_cache
return function()
  if module_cache then return module_cache end
  local storage = {}
  module_cache = storage

  local master = require("craft2/master")()
  local item_storage = require("craft2/item_storage")()
  local item_db = require("craft2/item_db")()

  function storage.scan()
  end

  function storage.getStackSize(stack)
    local id = item_db.stack_to_id(stack)
    return item_storage.get_item_real_count(id)
  end

  function storage.getMaxStackSize(stack)
    local id = item_db.stack_to_id(stack)
    local s = item_db.get(id, true)
    if s then
      return s.maxSize
    else
      return 1
    end
  end

  local outputChest = nil
  function getOutputChest()
    if outputChest then
      return outputChest
    end
    for _, chest in ipairs(master.chests) do
      if chest.role == "incoming" then
        outputChest = chest
        return chest
      end
    end
  end

  function storage.getOutputInventorySize()
    local chest = getOutputChest()
    return chest.slots_count - 1
  end

  function storage.getStackInOutputSlot(slot)
    local chest = getOutputChest()
    if slot >= 2 then
      slot = slot + 1
    end
    return chest.get_stack(slot)
  end

  function storage.moveToOutput(stack)
    local id = item_db.stack_to_id(stack)
    local ok = item_storage.load_to_chest(getOutputChest(), nil, id, stack.size)
    return ok
  end

  function storage.moveToStorage(slot)
    local chest = getOutputChest()
    if slot >= 2 then
      slot = slot + 1
    end
    local ok = item_storage.load_from_chest(chest, slot, nil, {})
    return ok
  end

  function storage.moveAllToStorage()
    local ok = item_storage.load_all_from_chest(getOutputChest(), nil)
    return ok
  end

  function storage.getFreeSlotCount()
    local cnt = 0
    for _, chest in ipairs(master.chests) do
      if chest.role == "storage" then
        cnt = cnt + chest.free_slots_count()
      end
    end
    return cnt
  end

  function storage.dump()
    error("not implemented")
  end

  return storage
end
