print("Welcome to Craft 2")
print("")

local config = require("craft2/config")

if config.role == "slave" then 
  require("craft2/slave").run()
elseif config.role == "master" then 
  cmd_args = {...}
  if #cmd_args > 0 then
    local command = cmd_args[1]
    if command == "rebuild" then 
      require("craft2/master_rebuild").run()
    else 
      print("Unknown command!")
      error()
    end
  else
    require("craft2/master_main").run()
  end
else 
  error("Invalid role in config")
end




