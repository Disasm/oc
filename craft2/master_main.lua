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
local crafting = require("craft2/crafting")

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
    if not config.enable_debug_log then
      return
    end
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

function add_stack_to_databases(stack)
  local new_id = local_item_database.add(stack)
  for _, d in ipairs(remote_databases) do
    d.set(new_id, stack)
  end
  return new_id
end

function r.process_istack(istack)
  if istack.unknown_stack then
    local new_id = add_stack_to_databases(istack.unknown_stack)
    return { istack[1], new_id }
  else
    return istack
  end
end



function r.run()

-- TEMPORARY
local filesystem = require("filesystem")
local db_fail_count = 0
local checked_hashes = {}

local function convert_stack(stack)
  local id = local_item_database.stack_to_id(stack)
  if not id then
    error("item not found in database: "..stack.label)
  end
  return { stack.size, id }
end

local success_count = 0
local input_path = "/home/tmp/recipes"
for input_file in filesystem.list(input_path) do
  data = fser.load(input_path.."/"..input_file)
  if not data then
    error("file load failed: "..input_file)
  end
  recipe = {}
  recipe.machine = data.machine_type or "craft"
  recipe.to = { convert_stack(data.to) }
  recipe.from = {}
  for i = 1, 9 do
    if data.from[i] then
      recipe.from[i] = convert_stack(data.from[i])
    end
  end
  crafting.add_recipe(recipe.to[1][2], recipe)
end


-- END OF TEMPORARY




  l.info("Master is starting...")

  l.dbg("Loading topology")
  local topology_data = fser.load(require("craft2/paths").topology)
  if not topology_data then
    l.warn("No topology file. Running rebuild...")
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
  r.chests_count = #(topology_data.chests)
  for i, d in ipairs(topology_data.chests) do
    table.insert(r.chests, wrap_chest(i, d))
  end
  l.dbg("Calculating final topology...")
  local outcoming_chest = nil
  for _, chest in ipairs(r.chests) do
    if chest.role == "output" then
      if outcoming_chest == nil then
        outcoming_chest = chest
      else
        l.warn("Multiple outcoming chests found.")
      end
    end
    chest.find_transposers_for_adjacent_chests()
  end
  for _, chest in ipairs(r.chests) do
    chest.find_paths_to_other_chests()
  end

  r.tasks = {}
  local previous_tasks_serialized = l.inspect(r.tasks)
  function send_tasks_if_changed()
    local new_tasks_serialized = l.inspect(r.tasks)
    if new_tasks_serialized ~= previous_tasks_serialized then
      previous_tasks_serialized = new_tasks_serialized
      print("Tasks: "..new_tasks_serialized)
      for _, t in ipairs(remote_terminals) do
        t.set_tasks(r.tasks)
      end
    end
  end

  local master_is_quitting = false
  local rpc_interface = {}
  local pending_commands = {}
  local item_storage = require("craft2/item_storage").create_storage()
  function rpc_interface.enqueue_command(cmd)
    if master_is_quitting then
      error("Master is offline.")
    end
    table.insert(pending_commands, cmd)
  end
  function rpc_interface.get_stored_item_counts(ids)
    return item_storage.get_stored_item_counts(ids)
  end
  rpc.bind({ master = rpc_interface })


  function r.on_chest_failure()
    l.warn("Chest failure!")
    for i, chest in ipairs(r.chests) do
      l.warn(string.format("Checking chest %d / %d", i, #(r.chests)))
      chest.rescue_from_chest_error()
    end
    l.warn("Done.")
  end

  function process_task(task)
    if task.name == "incoming" then
      l.dbg("Iterating over incoming chests")
      for _, chest in ipairs(r.chests) do
        if chest.role == "incoming" then
          l.dbg("Processing incoming chest "..chest.id)
          if not item_storage.load_all_from_chest(chest, task) then
            return false
          end
        end
      end
      l.dbg("Incoming task completed")
      return true
    elseif task.name == "output" then
      if not outcoming_chest then
        l.error("Output task: no outcoming chest!")
        return true
      end
      if type(task.item_id) ~= "number" then
        l.error("Output task: item_id is not a number!")
        return true
      end
      if type(task.count) ~= "number" then
        l.error("Output task: count is not a number!")
        return true
      end
      if task.count < 1 then
        l.error("Output task: count is not positive enough.")
        return true
      end
      return item_storage.process_output_task(outcoming_chest, task)
    else
      l.error("Unknown task")
      return true
    end
  end

  local next_task_id = 1
  local tick_interval = 1
  local tick_interval_after_error = 10

  r.add_task = function(task)
    task.id = next_task_id
    next_task_id = next_task_id + 1
    table.insert(r.tasks, task)
    l.dbg("Task added: "..l.inspect(task))
    send_tasks_if_changed()
  end

  function tick()
    local is_ok, err = xpcall(function()
      while #pending_commands > 0 do
        local cmd = pending_commands[1]
        table.remove(pending_commands, 1)
        if cmd.action == "add_task" then
          r.add_task(cmd.task)
        elseif cmd.action == "remove_task" then
          local ok = false
          for i, task in ipairs(r.tasks) do
            if task.id == cmd.task_id then
              table.remove(r.tasks, i)
              l.dbg("Task is removed by user.")
              ok = true
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
        elseif cmd.action == "throw_error" then
          error("No, it's YOUR fault.")
        else
          l.error("Invalid action.")
        end
      end

      table.sort(r.tasks, function(a,b) return (a.priority or 0) > (b.priority or 0) end)
      local tasks_left = {}
      for i, task in ipairs(r.tasks) do
        l.dbg("Running task: "..l.inspect(task))
        if process_task(task) then
          l.dbg("Task is completed.")
        else
          table.insert(tasks_left, task)
        end
      end
      r.tasks = tasks_left
      send_tasks_if_changed()
      for _, chest in ipairs(r.chests) do
        chest.save_cache()
      end
      if not master_is_quitting then
        event.timer(tick_interval, tick)
      end
    end, function(err)
      return { message = tostring(err), traceback = debug.traceback() }
    end)
    if not is_ok then
      l.error("Error: "..err.message)
      print(err.traceback)
      if not master_is_quitting then
        event.timer(tick_interval_after_error, tick)
      end
    end
  end
  event.timer(tick_interval, tick)
  l.info("Master is now live.")

end
return r
