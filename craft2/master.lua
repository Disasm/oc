local module_cache
return function()
  if module_cache then return module_cache end
  local master = {}
  module_cache = master

  local fser = require("libs/file_serialization")
  local filesystem = require("filesystem")
  local rpc = require("libs/rpc3")
  local wrap_transposer = require("craft2/wrap_transposer")
  local wrap_chest = require("craft2/wrap_chest")
  local local_item_database = require("craft2/item_db")()
  local hosts_ok, hosts = pcall(require, "hosts")
  if not hosts_ok then hosts = {} end
  local config = require("craft2/config")
  local gpu = require("component").gpu
  local event = require("event")
  local crafting = require("craft2/crafting")()
  local computer = require("computer")
  local item_storage = require("craft2/item_storage")()


  local remote_databases = {}
  local remote_terminals = {}

  master.notify = function(ok)
    for _, terminal in pairs(remote_terminals) do
      if ok then
        terminal.notifications.play_major_chord(1, 0.2)
      else
        terminal.notifications.play_minor_chord(1, 0.2)
      end
    end
  end
  master.log = {}
  master.log.inspect = require("serialization").serialize
  local log_file

  local local_terminal_initialized = false

  function master.log.message(obj)
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
    if not local_terminal_initialized then
      gpu.setForeground(obj.color)
      print(obj.text)
      gpu.setForeground(0xffffff)
    end
    if config.write_log then
      log_file:write(obj.text.."\n")
    end
    for _, t in ipairs(remote_terminals) do
      t.log_message(obj)
    end
  end
  function master.log.info(text)
    master.log.message({ level = "info", text = text })
  end
  function master.log.warn(text)
    master.log.message({ level = "warning", text = text })
  end
  function master.log.error(text)
    master.log.message({ level = "error", text = text })
  end
  function master.log.dbg(text)
    master.log.message({ level = "debug", text = text })
  end
  local l = master.log

  local function add_stack_to_databases(stack)
    local new_id = local_item_database.add(stack)
    for _, d in ipairs(remote_databases) do
      d.set(new_id, stack)
    end
    return new_id
  end

  function master.process_istack(istack)
    if istack.unknown_stack then
      local new_id = add_stack_to_databases(istack.unknown_stack)
      return { istack[1], new_id }
    else
      return istack
    end
  end

  master.tasks = {}
  local previous_tasks_serialized = "INVALID"
  local function send_tasks_if_changed()
    local new_tasks_serialized = l.inspect(master.tasks)
    if new_tasks_serialized ~= previous_tasks_serialized then
      previous_tasks_serialized = new_tasks_serialized
      for _, t in ipairs(remote_terminals) do
        t.set_tasks(master.tasks)
      end
    end
  end

  local master_is_quitting = false
  local rpc_interface = {}
  local pending_commands = {}
  function rpc_interface.enqueue_command(cmd)
    if master_is_quitting then
      error("Master is offline.")
    end
    table.insert(pending_commands, cmd)
  end
  function rpc_interface.get_stored_item_counts(ids)
    return item_storage.get_stored_item_counts(ids)
  end
  function rpc_interface.get_craft_machines()
    return crafting.get_machines()
  end
  function rpc_interface.get_recipes_strings(item_id)
    local strings = {}
    for index, recipe in pairs(crafting.get_recipes(item_id)) do
      table.insert(strings, crafting.recipe_readable(recipe))
    end
    return strings
  end
  function rpc_interface.remove_recipe(item_id, recipe_index)
    crafting.remove_recipe(item_id, recipe_index)
  end

  function master.on_chest_failure(chest1, chest2)
    l.warn("Chest failure!")
    if chest1 then
      chest1.rescue_from_chest_error()
    end
    if chest2 then
      chest2.rescue_from_chest_error()
    end
    l.warn("Let's hope it's all right now.")
  end

  local function process_task(task)
    if task.name == "incoming" then
      l.dbg("Iterating over incoming chests")
      for _, chest in ipairs(master.chests) do
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
      if not master.role_to_chest["output"] then
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
      return item_storage.process_output_task(master.role_to_chest["output"], task)
    elseif task.name == "craft" then
      return crafting.craft_all(task)
    elseif task.name == "craft_one" then
      return crafting.craft_one(task)
    elseif task.name == "craft_incomplete" then
      return crafting.craft_incomplete_recipe(task)
    else
      l.error("Unknown task")
      return true
    end
  end

  local next_task_id = 1
  local tick_interval = 1
  local tick_interval_after_error = 10

  local pending_machine_output = {}
  master.expect_machine_output = function(expectations)
    local result = {}
    local all_ok = true
    if expectations then
      for id, count in pairs(expectations) do
        if pending_machine_output[id] and pending_machine_output[id] > 0 then
          result[id] = math.min(count, pending_machine_output[id])
          pending_machine_output[id] = pending_machine_output[id] - result[id]
        end
        if not (result[id] and result[id] == count) then
          all_ok = false
        end
      end
    end
    if all_ok and expectations then return true, result end
    for _, chest in ipairs(master.chests) do
      if chest.role == "machine_output" then
        local ok, result = item_storage.load_all_from_chest(chest)
        if not ok then return false end
        for id, count in pairs(result) do
          pending_machine_output[id] = (pending_machine_output[id] or 0) + count
        end
      end
    end
    if not expectations then
      for id, count in pairs(pending_machine_output) do
        result[id] = count
        pending_machine_output[id] = 0
      end
    end
    return true, result
  end

  master.add_task = function(task)
    task.id = next_task_id
    next_task_id = next_task_id + 1
    table.insert(master.tasks, task)
    l.dbg("Task added: "..l.inspect(task))
    send_tasks_if_changed()
  end

  local function tick()
    local is_ok, err = xpcall(function()
      while #pending_commands > 0 do
        local cmd = pending_commands[1]
        table.remove(pending_commands, 1)
        if cmd.action == "add_task" then
          cmd.task.from_terminal = true
          master.add_task(cmd.task)
        elseif cmd.action == "remove_task" then
          local ok = false
          for i, task in ipairs(master.tasks) do
            if task.id == cmd.task_id then
              table.remove(master.tasks, i)
              l.dbg("Task is removed by user.")
              ok = true
              break
            end
          end
          if not ok then
            l.error("Cannot remove task: task not found.")
          end
          send_tasks_if_changed()
        elseif cmd.action == "commit_recipe" then
          for i, task in ipairs(master.tasks) do
            if task.name == "craft_incomplete" then
              if cmd.accept then
                local recipe = task.recipe
                recipe.to = {}
                local any = false
                for id, count in pairs(task.output) do
                  if count > 0 then
                    table.insert(recipe.to, {count, id})
                    any = true
                  end
                end
                if any then
                  for id, count in pairs(task.output) do
                    if count > 0 then
                      crafting.add_recipe(id, recipe)
                    end
                  end
                else
                  l.error("Recipe has no output.")
                end
              else
                l.info("Recipe is discarded.")
              end
              table.remove(master.tasks, i)
              break
            end
          end
        elseif cmd.action == "quit" then
          master_is_quitting = true
          l.info("Master is now offline.")
          if cmd.reboot then
            l.info("Rebooting.")
            computer.shutdown(true)
          end
          return
        elseif cmd.action == "throw_error" then
          error("No, it's YOUR fault.")
        else
          l.error("Invalid action.")
        end
      end

      table.sort(master.tasks, function(a,b) return (a.priority or 0) > (b.priority or 0) end)
      local tasks_left = {}
      for i, task in ipairs(master.tasks) do
        l.dbg("Running task: "..l.inspect(task))
        if process_task(task) then
          l.dbg("Task is completed.")
          if task.from_terminal then
            master.notify(true)
          end
        else
          table.insert(tasks_left, task)
        end
      end
      master.tasks = tasks_left
      send_tasks_if_changed()
      for _, chest in ipairs(master.chests) do
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
      l.error(err.traceback)
      if config.write_log then
        log_file:write(err.traceback.."\n")
      end
      if not master_is_quitting then
        event.timer(tick_interval_after_error, tick)
      end
    end
  end

  function master.run()
    l.info("Master is starting...")
    for _, host in ipairs(config.slaves or {}) do
      table.insert(remote_databases, rpc.connect(hosts[host]).item_database)
    end
    for _, host in ipairs(config.terminals or {}) do
      local v = rpc.connect(hosts[host])
      table.insert(remote_databases, v.item_database)
      table.insert(remote_terminals, v.terminal)
    end
    if config.crafter then
      master.crafter = rpc.connect(hosts[config.crafter])
    end

    if config.write_log then
      log_file = filesystem.open("/var/log/craft2.log", "a")
      if not log_file then
        error("can't open log file")
      end
    end

    l.dbg("Loading topology")
    local topology_data = fser.load(require("craft2/paths").topology)
    if not topology_data then
      l.warn("No topology file. Running rebuild...")
      topology_data = require("craft2/master_rebuild")()
    end
    master.transposers = {}
    master.chests = {}
    for i, d in ipairs(topology_data.transposers) do
      local interface
      if d.modem_address then
        interface = rpc.connect(d.modem_address).transposers_interface
      else
        -- local interface
        interface = require("craft2/transposers_interface")
      end
      table.insert(master.transposers, wrap_transposer(interface, d.transposer_address))
    end
    master.chests_count = #(topology_data.chests)
    for i, d in ipairs(topology_data.chests) do
      table.insert(master.chests, wrap_chest(i, d))
    end
    l.dbg("Calculating final topology...")

    master.role_to_chest = {}

    for _, chest in ipairs(master.chests) do
      if chest.role ~= "storage" and chest.role ~= "machine_output" then
        if master.role_to_chest[chest.role] then
          l.warn(string.format("Multiple chests for role: %s", chest.role))
        else
          master.role_to_chest[chest.role] = chest
        end
      end
    end
    for _, chest in ipairs(master.chests) do
      chest.find_transposers_for_adjacent_chests()
    end
    for _, chest in ipairs(master.chests) do
      chest.find_paths_to_other_chests()
    end

    if rpc.is_available then
      rpc.bind(rpc_interface)
    end
    local local_terminal = require("craft2/terminal")(rpc_interface)
    table.insert(remote_terminals, local_terminal.terminal)
    local_terminal_initialized = true

    master.expect_machine_output() -- clean on startup

    event.timer(tick_interval, tick)
    l.info("Master is now live.")
    master.notify(true)

  end

  return master
end