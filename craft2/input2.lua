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
    if label then print(label) end
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
  while true do
    if #actions > 1 then
      print(label.." (Enter to cancel)")
    end
    for i, action in pairs(actions) do
      input2.color_print(string.format("%s. %s", i, action.label), action.color)
    end
    if #actions == 1 then
      return 1, actions[1]
    end
    i = input.getNumber()
    if i == nil then
      return nil
    end
    if (i < 1) or (i > #actions) then
      print("Invalid value")
    else
      print("")
      local action = actions[i]
      input2.color_print(string.format("[ %s. %s ]", i, action.label), action.color)
      print("")
      return i, action
    end
  end
end

input2.confirm = function(label, callback)
  input2.show_char_menu(label, {
    { char="y", label="Yes", fn=function() callback(); return true end },
    { char="n", label="No", fn=function() return true end },
  })

end

return input2