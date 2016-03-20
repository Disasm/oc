return { run = function() 

  local config = require("craft2/config")
  local marker_items = require("craft2/marker_items")
  local rpc = require("libs/rpc")
  local hosts = require("hosts")
  local fser = require("libs/file_serialization")
  local sides = require("sides")

  local transposers_interface = require("craft2/transposers_interface")

  local function wrap_transposer(interface, address) 
    local r = { interface=interface, address=address }
    function r.get_slots_count(side) 
      return r.interface.get_slots_count(r.address, side)
    end
    function r.get_stack(side, slot) 
      return r.interface.get_stack(r.address, side, slot)
    end
    function r.get_items_count(side, slot)
      return r.interface.get_items_count(r.address, side, slot)    
    end
    function r.transfer(source_side, sink_side, count, source_slot, sink_slot) 
      if count == nil then count = math.huge end 
      return r.interface.transfer(r.address, source_side, sink_side, count, source_slot, sink_slot)
    end  
    return r
  end

  local components = {}
  table.insert(components, transposers_interface)
  for i, host in ipairs(config.slaves) do 
    local v = rpc.connect(hosts[host], nil, nil, "ping_once")
    table.insert(components, v)
  end
   
  local transposers = {} -- list of { interface, transposer_address }
  print("Rebuilding topology has begun.")
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
        print("Found chest ", i, side, slots_count)
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
  
  local function run_probe_cycle(transposer, side)
    print("run_probe_cycle1", transposer, sides[side])         
    transposers_that_began_cycle[transposer] = true
    if transposers[transposer].get_items_count(side, 1) == 0 then 
      error("Probe is lost :(")
    end
    local initial_side = side
    while true do 
      print("run_probe_cycle2", transposer, sides[side])
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
          local stack2 = transposers[transposer].get_stack(side, 2)
          local chest = { 
            transposers = chest_transposers, 
            role = marker_items.stack_to_chest_role(stack2),
            slots_count = transposers[transposer].get_slots_count(side)
          }
          table.insert(chests, chest)
          chest_id = #chests 
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
          print("Next inventory at__", transposer, sides[new_side])
          break 
        else 
          print("No inventory at____", transposer, sides[new_side])
        end
      end
      transposers[transposer].transfer(side, new_side, nil, 1, 1) 
      side = new_side 
      if side == initial_side then 
        print("Return at ", transposer, sides[side])
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
    local v = { transposer_address = t.address, modem_address = t.interface.address }
    table.insert(topology_data.transposers, v) 
  end
  fser.save("/home/craft2/topology", topology_data) 
  print("Topology scan completed.")
  
  print(string.format("Chests count: %d", #chests))
  fser.save("/tmp/chests.txt", chests) 
  fser.save("/tmp/map2.txt", transposer_to_side_to_chest)
end }
