local event = require("event")
local computer = require("computer")

function on_added(e, addr, component_name)
  if component_name == "keyboard" then 
    print "Keyboard added! We're in danger!"
    computer.addUser("Riateche")
    computer.addUser("disasm")
  end
end

function on_removed(e, addr, component_name)
  if component_name == "keyboard" then 
    print "Keyboard removed! Public mode enabled."
    computer.removeUser("Riateche")
    computer.removeUser("disasm")
  end
end

event.listen("component_added", on_added)
event.listen("component_removed", on_removed)
