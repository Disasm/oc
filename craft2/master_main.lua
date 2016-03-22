local fser = require("libs/file_serialization")
local rpc = require("libs/rpc2")
local wrap_transposer = require("craft2/wrap_transposer").wrap_transposer
local wrap_chest = require("craft2/wrap_chest").wrap_chest
local local_item_database = require("craft2/item_database")
local hosts = require("hosts")
local config = require("craft2/config")
local gpu = require("component").gpu
local event = require("event")
local r = {}

local remote_databases = {}
local remote_terminals = {}
for _, host in ipairs(config.slaves) do 
  table.insert(remote_databases, rpc.connect(hosts[host], nil, nil, "ping_once").item_database)
end
for _, host in ipairs(config.terminals) do 
  local v = rpc.connect(hosts[host], nil, nil, "ping_once")
  table.insert(remote_databases, v.item_database)
  table.insert(remote_terminals, v.terminal)
end

r.log = {} 
r.log.inspect = require("serialization").serialize 
function r.log.message(obj) 
  if obj.level == "warning" then  
    obj.color = 0xffff00
  elseif obj.level == "error" then 
    obj.color = 0xff0000
  elseif obj.level == "debug" then 
    obj.color = 0xb0b0b0
  else 
    obj.color = 0xffffff
  end 
  gpu.setForeground(obj.color)
  print(obj.text)
  gpu.setForeground(0xffffff)
  for _, t in ipairs(remote_terminals) do 
    t.log_message(obj) 
  end 
end 
function r.log.info(text) 
  r.log.message({ level = "info", text = text })
end 
function r.log.warn(text) 
  r.log.message({ level = "warning", text = text })
end 
function r.log.error(text) 
  r.log.message({ level = "error", text = text })
end 
function r.log.dbg(text) 
  r.log.message({ level = "debug", text = text })
end 
local l = r.log


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
  l.info("Master is starting...")

  l.dbg("Loading topology")
  local topology_data = fser.load("/home/craft2/topology")
  if not topology_data then 
    l.warning("No topology file. Running rebuild...")
    topology_data = require("craft2/master_rebuild").run()
  end
  r.transposers = {}
  r.chests = {}
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
    table.insert(r.chests, wrap_chest(i, d))    
  end
  l.dbg("Calculating final topology...")
  for _, chest in ipairs(r.chests) do 
    chest.find_transposers_for_adjacent_chests()
  end
  for _, chest in ipairs(r.chests) do 
    chest.find_paths_to_other_chests()
  end  
  
  local tasks = {} 
  local previous_tasks_serialized = l.inspect(tasks)
  function send_tasks_if_changed()
    local new_tasks_serialized = l.inspect(tasks)
    if new_tasks_serialized ~= previous_tasks_serialized then 
      previous_tasks_serialized = new_tasks_serialized
      print("Tasks: "..new_tasks_serialized)
      for _, t in ipairs(remote_terminals) do 
        t.set_tasks(tasks) 
      end 
    end     
  end 
  
  local master_is_quitting = false 
  local rpc_interface = {} 
  local pending_commands = {}
  function rpc_interface.command(cmd) 
    if master_is_quitting then 
      error("Master is offline.")
    end 
    table.insert(pending_commands, cmd)
  end 
  rpc.bind({ master = rpc_interface })
  
  local item_storage = require("craft2/item_storage").create_storage()
  
  function process_task(task) 
    if task.name == "empty_incoming" then 
      for _, chest in ipairs(r.chests) do 
        if chest.role == "incoming" then 
          if not item_storage.load_all_from_chest(chest) then 
            return false 
          end 
        end 
      end 
      return true 
    else
      l.error("Unknown task")
      task.status = "error"
      task.status_message = "Unknown task"
      return false
    end 
  end 
  
  local next_task_id = 1 
  
  function tick()
    while #pending_commands > 0 do 
      local cmd = pending_commands[1]
      table.remove(pending_commands, 1)
      if cmd.action == "add_task" then 
        cmd.task.id = next_task_id
        next_task_id = next_task_id + 1
        table.insert(tasks, cmd.task)
        l.dbg("Task added: "..l.inspect(cmd.task))
        send_tasks_if_changed()
      elseif cmd.action == "remove_task" then 
        local ok = false 
        for i, task in ipairs(tasks) do 
          if task.id == cmd.task_id then 
            table.remove(tasks, i)
            l.dbg("Task is removed by user.")
            break
          end 
        end 
        if not ok then 
          l.error("Cannot remove task: task not found.")
        end 
        send_tasks_if_changed()
      elseif cmd.action == "quit" then 
        master_is_quitting = true       
        l.info("Master is now offline.")
        return 
      end 
    end 

    table.sort(tasks, function(a,b) return (a.priority or 0) > (b.priority or 0) end)
    for i, task in ipairs(tasks) do 
      l.dbg("Running task: "..l.inspect(task))
      if process_task(task) then 
        table.remove(tasks, i)
        l.dbg("Task is completed.")
        break
      end 
    end 
    send_tasks_if_changed()
    for _, chest in ipairs(r.chests) do 
      chest.save_cache()
    end  
    if master_is_quitting then 
      l.info("Master is now offline.")
    else       
      event.timer(1, tick)
    end 
  end 
  event.timer(1, tick)
  l.info("Master is now live.")
  
end 
return r
