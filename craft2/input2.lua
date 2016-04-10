local input = require("libcraft/craft_input")

local input2 = {}

input2.menu = function(label, actions)
  while true do
    print(label)
    for _, action in actions do
      print(string.format("%s: %s", action.char, action.label))
    end
    while true do
      local ch = input.getChar()


  end

end



return input2