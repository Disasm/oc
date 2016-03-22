local fser = require("libs/file_serialization")
local rpc = require("libs/rpc2")
local wrap_transposer = require("craft2/wrap_transposer").wrap_transposer
local wrap_chest = require("craft2/wrap_chest").wrap_chest
local local_item_database = require("craft2/item_database")
local hosts = require("hosts")
local config = require("craft2/config")


local r = {}

local remote_databases = {}
for _, host in ipairs(config.slaves) do 
  table.insert(remote_databases, rpc.connect(hosts[host], nil, nil, "ping_once").item_database)
end
for _, host in ipairs(config.terminals) do 
  table.insert(remote_databases, rpc.connect(hosts[host], nil, nil, "ping_once").item_database)
end

function r.process_istack(istack)
  if istack.unknown_stack then 
    local new_id = local_item_database.add(istack.unknown_stack)
    for _, d in ipairs(remote_databases) do 
      d.set(new_id, istack.unknown_stack)
    end 
    return { new_id, istack[1] }
  else
    return istack
  end
end



function r.run()
  

  print("Loading topology")
  local topology_data = fser.load("/home/craft2/topology")
  if not topology_data then 
    print("No topology file. Running rebuild...")
    topology_data = require("craft2/master_rebuild").run()
  end
  r.transposers = {}
  local chests = {}
  for i, d in ipairs(topology_data.transposers) do 
    local interface
    if d.modem_address then 
      interface = rpc.connect(d.modem_address, nil, nil, "ping_once").transposers_interface
    else 
      -- local interface 
      interface = require("craft2/transposers_interface")
    end
    table.insert(r.transposers, wrap_transposer(interface, d.transposer_address))
  end
  for i, d in ipairs(topology_data.chests) do 
    table.insert(chests, wrap_chest(i, d))    
  end
 
  
  print("Nothing to do here yet!")
  
end 
return r
