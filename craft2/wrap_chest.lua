
local fser = require("libs/file_serialization")

return { wrap_chest = function(chest_id, chest_data)
  local master = require("craft2/master_main")
  local item_db = require("craft2/item_database")
  local function max_stack(item_id)
    return item_db.get(item_id).maxSize
  end
  local l = master.log
  local r = {
    id = chest_id,
    role = chest_data.role,
    slots_count = chest_data.slots_count,
    transposers = {}
  }
  r.can_transfer = (r.role == "storage")
  local content_cache_filename = require("craft2/paths").content_cache .. string.format("%03d", r.id)
  local content_cache_modified = false
  r.content_cache_enabled = (r.role == "storage")

  for i, d in ipairs(chest_data.transposers) do
    local entry = { transposer = master.transposers[d.transposer_id], side = d.side }
    if not r.main_transposer and not entry.transposer.interface.modem_address then
      -- first local transposer is assigned as main
      r.main_transposer = entry
    end
    table.insert(r.transposers, entry)
  end
  if not r.main_transposer then -- all transposers are remote
    r.main_transposer = r.transposers[1]
  end

  function r.get_stack(slot)
    if slot < 1 or slot > r.slots_count then
      error("chest.get_stack: slot out of bounds")
    end
    return r.main_transposer.transposer.get_stack(r.main_transposer.side, slot)
  end

  function r.refresh_cache(slot)
    if not r.content_cache_enabled then
      return
    end
    if slot == nil then
      for i = 1, r.slots_count do
        r.get_istack(i, true)
      end
      r.save_cache()
    else
      r.get_istack(slot, true)
    end
  end
  function r.save_cache()
    -- l.dbg("save cache "..tostring(r.id).." "..tostring(r.content_cache_enabled).." "..tostring(content_cache_modified))
    if r.content_cache_enabled and content_cache_modified then
      -- l.dbg("save cache ok")
      l.dbg("save cache "..tostring(r.id))
      fser.save(content_cache_filename, r.content_cache)
      content_cache_modified = false
    end
  end
  function r.get_istack(slot, no_cache)
    if slot < 1 or slot > r.slots_count then
      error("chest.get_stack: slot out of bounds")
    end
    if not r.content_cache_enabled or no_cache then
      local v = r.main_transposer.transposer.get_istack(r.main_transposer.side, slot)
      v = master.process_istack(v)
      if r.content_cache_enabled then
        r.content_cache[slot] = v
        content_cache_modified = true
      end
      return v
    else
      return r.content_cache[slot]
    end
  end
  function r.free_slots_count()
    local v = 0
    for i = 3, r.slots_count do
      if r.get_istack(i)[1] == 0 then
        v = v + 1
      end
    end
    return v
  end
  function r.space_in_existing_slots(item_id)
    if item_id == nil then error("nil!") end
    local total_free_space = 0
    for i = 3, r.slots_count do
      local stack = r.get_istack(i)
      if stack[2] == item_id then
        local mx = max_stack(item_id)
        local free_space = mx - stack[1]
        total_free_space = total_free_space + free_space
      end
    end
    return total_free_space

  end


  function r.get_items_count(slot)
    if slot < 1 or slot > r.slots_count then
      error("chest.get_stack: slot out of bounds")
    end
    return r.main_transposer.transposer.get_items_count(r.main_transposer.side, slot)
  end

  function r.direct_transfer_to(other_chest, count, source_slot, sink_slot)
    local previous_count = r.get_istack(source_slot)[1]
    local target_count = previous_count - count
    l.dbg(string.format("direct transfer %d.%d -> %d.%d", r.id, source_slot, other_chest.id, sink_slot))
    if r.id == other_chest.id then
      local t = r.main_transposer
      t.transposer.transfer(t.side, t.side, count, source_slot, sink_slot)
    else
      local t = r.transposers_for_adjacent_chests[other_chest.id]
      if not t then return false end
      t.transposer.transfer(t.side1, t.side2, count, source_slot, sink_slot)
    end
    -- refresh cache for these 2 slots
    if r.content_cache_enabled then
      r.get_istack(source_slot, true)
    end
    if other_chest.content_cache_enabled then
      other_chest.get_istack(sink_slot, true)
    end
    l.dbg(string.format("target_count=%d result_count=%d", target_count, r.get_istack(source_slot)[1]))
    return r.get_istack(source_slot)[1] == target_count
  end

  function r.transfer_to(other_chest, count, source_slot, sink_slot)
    l.dbg(string.format("chest(%d).transer_to(%d, %d, %d, %s)", r.id, other_chest.id, count, source_slot, tostring(sink_slot)))
    if count <= 0 then
      l.warn("chest.transer_to: invalid count")
      return false
    end
    local item_id = r.get_istack(source_slot)[2]
    local current_source_count = r.get_istack(source_slot)[1]
    if current_source_count == 0 then
      l.warn("chest.transer_to: source stack is empty")
      return false
    end
    local path = r.paths_to_chests[other_chest.id]
    if #path == 1 then path = { r.id, r.id } end
    local current_step = 1
    local current_slot = source_slot
    for current_step = 1, (#path-1) do
      local current_chest = master.chests[path[current_step]]
      if current_step + 1 == #path then -- last step
        local target_count_left = current_source_count - count
        local source_stack = current_chest.get_istack(current_slot)
        l.dbg("source_stack: "..l.inspect(source_stack))
        -- l.dbg("original_source_stack: "..l.inspect(original_source_stack))
        l.dbg(string.format("current %d.%d", current_chest.id, current_slot))
        if source_stack[1] ~= current_source_count or source_stack[2] ~= item_id then
          l.warn("chest.transer_to: stack is lost!")
          master.on_chest_failure(current_chest)
          return false
        end
        local function try_final_transfer(slot)
          current_chest.direct_transfer_to(other_chest, source_stack[1] - target_count_left, current_slot, slot)
          source_stack = current_chest.get_istack(current_slot)
          return (source_stack[1] == target_count_left)
        end

        if sink_slot == nil then
          -- first, try to merge into filled slots
          for i = 3, other_chest.slots_count do
            local stack = other_chest.get_istack(i)
            if stack[2] == source_stack[2] then
              if try_final_transfer(i) then return true end
            end
          end
          -- 2nd, try to put into empty slots
          for i = 3, other_chest.slots_count do
            local stack = other_chest.get_istack(i)
            if stack[1] == 0 then
              if try_final_transfer(i) then return true end
            end
          end
          l.warn("chest.transer_to: last transfer failed (probably no free slots)")
        else
          if try_final_transfer(sink_slot) then return true end
          l.warn("chest.transer_to: last transfer failed (slot is probably taken)")
        end
        master.on_chest_failure(current_chest, other_chest)
        return false
      else
        local next_chest_id = path[current_step + 1]
        local sink_chest = master.chests[next_chest_id]
        local result = current_chest.direct_transfer_to(sink_chest, count, current_slot, 1)
        if not result then
          l.warn("chest.transer_to: intermediate transfer failed")
          l.warn(string.format("from: %d.%d", current_chest.id, current_slot))
          l.warn(string.format("to: %d.%d", sink_chest.id, 1))
          master.on_chest_failure(current_chest, sink_chest)
          return false
        end
        current_slot = 1
        current_source_count = count
      end
    end
  end

  if r.content_cache_enabled then
    r.content_cache = fser.load(content_cache_filename)
    if not r.content_cache then
      l.info(string.format("Refreshing cache for chest %d / %d", r.id, master.chests_count))
      r.content_cache = {}
      r.refresh_cache()
    end
  end

  function r.find_transposers_for_adjacent_chests()
    r.transposers_for_adjacent_chests = {}
    for i, chest in ipairs(master.chests) do
      local found = false
      for _, item in ipairs(r.transposers) do
        for _, item2 in ipairs(chest.transposers) do
          if item.transposer == item2.transposer then
            local v = { transposer = item.transposer, side1 = item.side, side2 = item2.side }
            r.transposers_for_adjacent_chests[i] = v
            found = true
            break
          end
        end
        if found then break end
      end
    end
  end



  function r.find_paths_to_other_chests()
    -- https://ru.wikipedia.org/wiki/%D0%90%D0%BB%D0%B3%D0%BE%D1%80%D0%B8%D1%82%D0%BC_%D0%94%D0%B5%D0%B9%D0%BA%D1%81%D1%82%D1%80%D1%8B
    local vertices_count = #(master.chests)
    local start_vertix = r.id
    local visited_vertices = {}
    local distances = {}
    local paths = {}
    for i = 1, vertices_count do
      if i == start_vertix then
        distances[i] = 0
        paths[i] = { i }
      else
        distances[i] = math.huge
      end
    end
    while true do
      local min_distance = nil
      local min_distance_vertix = nil
      for i = 1, vertices_count do
        if not visited_vertices[i] then
          if min_distance == nil or distances[i] < min_distance then
            min_distance = distances[i]
            min_distance_vertix = i
          end
        end
      end
      if min_distance_vertix == nil then break end
      visited_vertices[min_distance_vertix] = true
      for i = 1, vertices_count do
        if not visited_vertices[i] then
          local t = master.chests[min_distance_vertix].transposers_for_adjacent_chests[i]
          if t then
            local cost
            if t.transposer.interface.modem_address then
              cost = 4
            else
              cost = 1
            end
            local new_distance = min_distance + cost
            if new_distance < distances[i] then
              distances[i] = new_distance
              paths[i] = {}
              if not paths[min_distance_vertix] then
                error("paths[min_distance_vertix] is nil")
              end
              for _, item in ipairs(paths[min_distance_vertix]) do
                table.insert(paths[i], item)
              end
              table.insert(paths[i], i)
            end
          end
        end
      end
    end

    --print(string.format("Paths from chest %d", r.id))
    --for i = 1, vertices_count do
    --  print(string.format("to %d: %s (d=%d)", i, l.inspect(paths[i]), distances[i]))
    --end
    r.paths_to_chests = paths
    r.distances_to_chests = distances
  end

  function r.ensure_first_slot_free()
    if r.content_cache_enabled and r.get_istack(1, true)[1] > 0 then
      for slot = 3, r.slots_count do
        if r.get_istack(slot)[1] == 0 then
          r.direct_transfer_to(r, r.get_istack(1, true)[1], 1, slot)
          r.get_istack(slot, true)
          break
        end
      end
    end
    local current_slot = 2
    while r.get_istack(1, true)[1] > 0 do
      current_slot = current_slot + 1
      if current_slot > r.slots_count then
        error("Fatal error: chest is full")
      end
      r.direct_transfer_to(r, r.get_istack(1, true)[1], 1, current_slot)
      if r.content_cache_enabled then
        r.get_istack(current_slot, true)
      end
    end
  end

  function r.rescue_from_chest_error()
    r.ensure_first_slot_free()
    if r.content_cache_enabled then
      r.refresh_cache()
      r.save_cache()
    end
  end
  r.ensure_first_slot_free()

  return r
end }
