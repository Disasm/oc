return { run = function()

  local config = require("craft2/config")
  local marker_items = require("craft2/marker_items")
  local rpc = require("libs/rpc2")
  local hosts = require("hosts")
  local fser = require("libs/file_serialization")
  local sides = require("sides")
  local shell = require("shell")

  local transposers_interface = require("craft2/transposers_interface")
  local wrap_transposer = require("craft2/wrap_transposer").wrap_transposer

  local components = {}
  table.insert(components, transposers_interface)
  for i, host in ipairs(config.slaves) do
    local v = rpc.connect(hosts[host], nil, nil, "ping_once").transposers_interface
    v.modem_address = hosts[host]
    table.insert(components, v)
  end

  local transposers = {} -- list of { interface, transposer_address }
  print("Rebuilding topology has begun.")
  print("Removing content cache...")
  shell.execute(string.format("rm -r %s", require("craft2/paths").content_cache))

  print("Enumerating transposers...")
  for interface_id, interface in ipairs(components) do
    for _, address in ipairs(interface.get_transposers()) do
      print(string.format("%s (host: %d)", address, interface_id))
      table.insert(transposers, wrap_transposer(interface, address))
    end
  end
  print("Checking chests...")
  local probe_location = nil
  local transposer_to_side_to_chest = {}
  for i, t in ipairs(transposers) do
    transposer_to_side_to_chest[i] = {}
  end
  for i, t in ipairs(transposers) do
    for side = 0, 5 do
      local slots_count = t.get_slots_count(side)
      if slots_count ~= nil then
        print(string.format("Found chest (transposer: %d, side: %s, slots: %d)", i, sides[side], slots_count))
        local current_slot = 2 -- we don't want to use 1st and 2nd slot
        while t.get_items_count(side, 1) > 0 do
          if current_slot == 1 then -- first iteration
            print("First slot is not empty! Correcting.")
          end
          current_slot = current_slot + 1
          if current_slot > slots_count then
            error("Fatal error: can't free first slot")
          end
          t.transfer(side, side, nil, 1, current_slot)
        end
        if probe_location == nil then
          if marker_items.stack_to_chest_role(t.get_stack(side, 2)) == "incoming" then
            probe_location = { transposer = i, side = side, slot = 2 }
            print("Probe found")
          end
        end
      else
        -- no inventory here
        transposer_to_side_to_chest[i][side] = -1
      end
    end
  end
  if not probe_location then
    error("No probe found. Place 1 stick in 2nd slot of incoming chest.")
  end
  print("Running probe cycle...")
  local chests = {}
  local transposers_that_began_cycle = {}
  local transposers_that_began_cycle_count = 0

  local function run_probe_cycle(transposer, side)
    transposers_that_began_cycle[transposer] = true
    transposers_that_began_cycle_count = transposers_that_began_cycle_count + 1
    print(string.format("Examining transposer %d / %d", transposers_that_began_cycle_count, #transposers))
    if transposers[transposer].get_items_count(side, 1) == 0 then
      error("Probe is lost :(")
    end
    local initial_side = side
    while true do
      -- probe is at side'th side;
      -- we need to find out chest id
      local chest_id = transposer_to_side_to_chest[transposer][side]
      if not chest_id then
        -- need to scan all transposers
        local chest_transposers = {}
        for i, t in ipairs(transposers) do
          for other_side = 0, 5 do
            if transposer_to_side_to_chest[i][other_side] ~= -1 then -- if there's inventory
              if t.get_items_count(other_side, 1) > 0 then
                if transposer_to_side_to_chest[i][other_side] ~= nil then -- if we have chest id
                  chest_id = transposer_to_side_to_chest[i][other_side]
                  break
                else
                  table.insert(chest_transposers, { transposer_id = i, side = other_side })
                end
              end
            end
          end
          if chest_id then break end
        end
        if not chest_id then
          -- completely new chest
          local slots_count = transposers[transposer].get_slots_count(side)
          local role = nil
          if probe_location.transposer == transposer and probe_location.side == side then
            role = "incoming"
          elseif slots_count == 5 then
            role = "machine_output"
          else
            local stack2 = transposers[transposer].get_stack(side, 2)
            role = marker_items.stack_to_chest_role(stack2)
          end
          local chest = {
            transposers = chest_transposers,
            role = role,
            slots_count = slots_count
          }
          table.insert(chests, chest)
          chest_id = #chests
          print(string.format("Chest %d (role: %s, transposers: %d)", chest_id, chest.role, #(chest.transposers)))
          for i, item in ipairs(chest_transposers) do
            transposer_to_side_to_chest[item.transposer_id][item.side] = chest_id
          end
        end
      end
      for i, item in ipairs(chests[chest_id].transposers) do
        if not transposers_that_began_cycle[item.transposer_id] then
          run_probe_cycle(item.transposer_id, item.side)
        end
      end
      local new_side = side
      while true do
        new_side = new_side + 1
        if new_side == 6 then new_side = 0 end
        if transposer_to_side_to_chest[transposer][new_side] ~= -1 then
          -- there is an inventory on this side
          break
        else
          -- no inventory
        end
      end
      transposers[transposer].transfer(side, new_side, nil, 1, 1)
      side = new_side
      if side == initial_side then
        break
      end
    end
  end
  -- move to 1st slot
  transposers[probe_location.transposer].transfer(probe_location.side, probe_location.side, nil, probe_location.slot, 1)
  run_probe_cycle(probe_location.transposer, probe_location.side)
  -- move back
  transposers[probe_location.transposer].transfer(probe_location.side, probe_location.side, nil, 1, probe_location.slot)

  local topology_data = { transposers = {}, chests = chests }
  for i, t in ipairs(transposers) do
    local v = { transposer_address = t.address, modem_address = t.interface.modem_address }
    table.insert(topology_data.transposers, v)
  end
  fser.save(require("craft2/paths").topology, topology_data)
  print("Topology scan completed.")
  return topology_data

end }
