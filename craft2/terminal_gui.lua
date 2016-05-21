local input = require("libcraft/craft_input")
local input2 = require("craft2/input2")
local item_db = require("craft2/item_db")()
local filesystem = require("filesystem")
local serialization = require("serialization")
local shell = require("shell")

local master
local master_enqueue = function(cmd)
  print("master.enqueue_command("..serialization.serialize(cmd)..")")
end

local logFile = filesystem.open("/log.txt", "a")
local oldPrint = print
local print = function(...)
  oldPrint(...)
  if logFile ~= nil then
    local t = table.pack(...)
    for i = 1,t.n do
      if i > 1 then
        logFile:write(" ")
      end
      logFile:write(t[i])
    end
    logFile:write("\n")
  end
end

-- options: onlyPresent, hasCount
function inputItem(options)
  local ids
  local counts
  while true do
    print("Enter item name (empty to exit):")
    local name = input.getString()
    if name == "" then
      return
    end

    ids = item_db.find_inexact(name)

    counts = master.get_stored_item_counts(ids)
    if options.onlyPresent then
      local i = 1
      while i <= #ids do
        local count = counts[ids[i]] or 0
        if count == 0 then
          counts[ids[i]] = nil
          table.remove(ids, i)
        else
          i = i + 1
        end
      end
    end

    if #ids > 0 then
      break
    end

    print("Item not found. Try again.")
  end

  local menu_items = {}
  for i = 1,#ids do
    local item = {}
    item.id = ids[i]
    local s = item_db.get(item.id)
    local count = counts[item.id] or 0
    if count == 0 then
      item.color = 0xffff30
    else
      item.color = 0x30ff30
    end
    item.label = s.label.." ("..count..")"
    table.insert(menu_items, item)
  end
  local _, item = input2.show_number_menu("Select item", menu_items)
  if item == nil then
    return
  end
  local id = item.id
  local s = item_db.get(id)

  local n
  if options.hasCount then
    while true do
      print("Enter item count (enter to cancel):")
      n = input.getNumber()
      if n == nil then
        return
      end
      if (options.onlyPresent and n > counts[id]) or (n < 1) then
        print("Invalid count.")
      else
        break
      end
    end
  end

  return id, n, s
end

function getItemsDialog(craftIfNeeded)
  local id, n, s = inputItem({ onlyPresent = not craftIfNeeded, hasCount = true })
  if id ~= nil then
    master_enqueue({action="add_task", task={name="output", item_id=id, count=n}})
  end
end

function cleanIncoming()
  master_enqueue({action="add_task", task={name="incoming"}})
end

function viewRecipes()
  local id, count, stack = inputItem({ onlyPresent = false, hasCount = false })
  if not id then return end

  local function main()
    local strings = master.get_recipes_strings(id)
    if #strings > 0 then
      print(string.format("Recipes for %s: \n", stack.label))
      for index, str in pairs(strings) do
        print(string.format("%d. %s", index, str))
      end
      local function removeRecipe()
        print("Enter recipe index (enter to cancel):")
        local n = input.getNumber()
        if n == nil then
          return
        end
        print(string.format("Are you sure you want to delete this recipe?"))
        print(strings[n])
        input2.confirm(nil, function()
          master.remove_recipe(id, n)
          main()
        end)
      end
      input2.show_char_menu("Recipe actions", {
        { char="r", label="Remove recipe", fn=removeRecipe },
      })
    else
      print(string.format("No recipes for %s.", stack.label))
    end

  end
  main()

end


string_lpad = function(str, len, char)
  if char == nil then char = ' ' end
  if string.len(str) > len then
    str = string.sub(str, 0, len)
  end
  return str .. string.rep(char, len - #str)
end

function addRecipe()
  local machines = {}
  for name, _ in pairs(master.get_craft_machines()) do
    table.insert(machines, { label = name })
  end
  local _, action = input2.show_number_menu("Select machine", machines)
  local machine = action.label
  local is_craft = (machine == "craft")
  local stacks = {}
  local function printStacks()
    print("")
    if is_craft then
      for i = 1, 9 do
        local s = ""
        if stacks[i] then
          s = item_db.istack_to_string(stacks[i])
        end
        io.write(string_lpad(string.format("[%d] %s", i, s), 20))
        if i % 3 == 0 then
          io.write("\n")
        end
      end
    else
      local any = false
      for i, stack in pairs(stacks) do
        print(string.format("[%d] %s", i, item_db.istack_to_string(stack)))
        any = true
      end
      if not any then
        print("No stack input yet.")
      end
    end
    print("")
  end
  printStacks()
  local function add()
    local item_id, count = inputItem({ hasCount = true })
    if not item_id then return end
    if is_craft then
      while true do
        printStacks()
        print("Enter crafting slot (enter to cancel):")
        local n = input.getNumber()
        if n == nil then
          printStacks()
          return
        end
        if n < 1 or n > 9 then
          print("Invalid crafting slot.")
        else
          stacks[n] = { count, item_id }
          print("Added.")
        end
      end
    else
      local n = 1
      while stacks[n] do
        n = n + 1
      end
      stacks[n] = { count, item_id }
      print("Added.")
      printStacks()
    end
  end

  local function rem()
    print("Enter crafting slot (enter to cancel):")
    local n = input.getNumber()
    if n then
      if is_craft then
        stacks[n] = nil
      else
        table.remove(stacks, n)
      end
    end
    printStacks()
  end
  local function commit(ok)
    master_enqueue({ action="commit_recipe", accept=ok })
  end
  local function save()
    master_enqueue({
      action="add_task",
      task={
        name="craft_incomplete",
        recipe={
          machine=machine,
          from=stacks
        }
      }
    })
    input2.show_char_menu("Wait for the output!", {
      { char="a", label="Accept recipe", fn=function() commit(true); return true end  },
      { char="d", label="Discard recipe", fn=function() commit(false); return true end  },
    }, { no_quit=true })
  end
  input2.show_char_menu("Recipe editor", {
    { char="a", label="Add item", fn=add },
    { char="r", label="Remove item", fn=rem },
    { char="s", label="Save", fn=save },
  })
end

function recipesMenu()
  input2.show_char_menu("Recipes", {
    { char="v", label="View recipes", fn=viewRecipes },
    { char="a", label="Add recipe", fn=addRecipe },
  })
end

function killTask()
  print("Enter task ID (enter to cancel):")
  local id = input.getNumber()
  if id == nil then
    return
  end
  master_enqueue({action="remove_task", task_id=id})
end

return function(master_interface)
  local isEmulator = require("libs/emulator").isEmulator
  if not isEmulator then
    master = master_interface
    master_enqueue = function(x)
      if pcall(h.master.enqueue_command, x) then
        print("Command added")
      else
        print("Master is not responding")
      end
      print("")
    end
  end

  input2.show_char_menu("Main menu", {
    { char="g", label="Get items", fn=getItemsDialog },
    { char="c", label="Get items or craft", fn=function() getItemsDialog(true) end },
    { char="i", label="Clean incoming", fn=cleanIncoming },
    { char="k", label="Kill task", fn=killTask },
    { char="u", label="Update", fn=function() shell.execute("up") end },
    { char="b", label="Reboot master server", fn=function() master_enqueue({action="quit", reboot=true}) end },
    { char="r", label="Manage recipes", fn=recipesMenu },
  })

end
