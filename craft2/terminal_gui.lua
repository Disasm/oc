local input = require("libcraft/craft_input")
local input2 = require("craft2/input2")
local db = require("craft2/item_database")
local filesystem = require("filesystem")
local util = require("libs/stack_util")
local serialization = require("serialization")
local term = require("term")
local shell = require("shell")
local gpu = require("component").gpu

local master = nil
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
  local ids = nil
  local counts = nil
  while true do
    print("Enter item name (empty to exit):")
    local name = input.getString()
    if name == "" then
      return
    end

    ids = db.find_inexact(name)

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
    local s = db.get(item.id)
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
  local s = db.get(id)

  local n = nil
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
      function removeRecipe()
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
      input2.show_char_menu(nil, {
        { char="r", label="Remove recipe", fn=removeRecipe },
      })
    else
      print(string.format("No recipes for %s.", stack.label))
    end

  end
  main()

end

function addRecipe()

end

function recipesMenu()
  input2.show_char_menu("What do you want? Select one.", {
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

return function()
  local isEmulator = require("libs/emulator").isEmulator
  if not isEmulator then
    local rpc = require("libs/rpc2")
    local hosts = require("hosts")
    local h = rpc.connect(hosts.master)
    master = h.master
    master_enqueue = function(x)
      if pcall(h.master.enqueue_command, x) then
        print("Command added")
      else
        print("Master is not responding")
      end
      print("")
    end
  end

  input2.show_char_menu("What do you want? Select one.", {
    { char="g", label="Get items", fn=getItemsDialog },
    { char="c", label="Get items or craft", fn=function() getItemsDialog(true) end },
    { char="i", label="Clean incoming", fn=cleanIncoming },
    { char="k", label="Kill task", fn=killTask },
    { char="u", label="Update", fn=function() shell.execute("up") end },
    { char="b", label="Reboot master server", fn=function() master_enqueue({action="quit", reboot=true}) end },
    { char="r", label="Manage recipes", fn=recipesMenu },
  })

end
