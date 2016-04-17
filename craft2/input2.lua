local input = require("libcraft/craft_input")
local gpu = require("component").gpu

local input2 = {}

input2.color_print = function(text, color)
  local oldFg
  if color then
    oldFg = gpu.getForeground()
    gpu.setForeground(color)
  end
  print(text)
  if color then
    gpu.setForeground(oldFg)
  end
end

input2.show_char_menu = function(label, actions, config)
  if not (config and config.no_quit) then
    table.insert(actions, { char="q", label="Quit", fn=function() return true end })
  end
  while true do
    if label then
      print("")
      print(string.rep("=", string.len(label)))
      print(label)
      print(string.rep("=", string.len(label)))
    end
    for _, action in pairs(actions) do
      input2.color_print(string.format("%s: %s", action.char, action.label), action.color)
    end
    while true do
      local ch = input.getChar()
      local char_ok = false
      for _, action in pairs(actions) do
        if ch == action.char then
          char_ok = true
          print("")
          input2.color_print(string.format("[ %s: %s ]", action.char, action.label), action.color)
          print("")
          if action.fn() then
            return
          end
          break
        end
      end
      if char_ok then break end
    end
  end
end

input2.show_number_menu = function(label, actions)
  if label then
    print("")
    print(string.rep("=", string.len(label)))
    print(label)
    print(string.rep("=", string.len(label)))
  end
  while true do
    if #actions == 1 then
      print("AUTOMATICALLY SELECTED:")
      input2.color_print(string.format("%s", actions[1].label), actions[1].color)
      return 1, actions[1]
    end
    for i, action in pairs(actions) do
      input2.color_print(string.format("%d. %s", i, action.label), action.color)
    end
    local index = input.getNumber()
    if index == nil then
      return nil
    end
    if (index < 1) or (index > #actions) then
      print("Invalid value")
    else
      print("")
      local action = actions[index]
      input2.color_print(string.format("[ %d. %s ]", index, action.label), action.color)
      print("")
      return index, action
    end
  end
end

input2.confirm = function(label, callback)
  input2.show_char_menu(label, {
    { char="y", label="Yes", fn=function() callback(); return true end },
    { char="n", label="No", fn=function() return true end },
  }, { no_quit=true })

end

return input2