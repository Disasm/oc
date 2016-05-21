local config = require("craft2/config")

if config.role == "slave" then
  require("craft2/slave")()
elseif config.role == "terminal" then
  require("craft2/terminal")()
elseif config.role == "master" then
  local cmd_args = {...}
  if #cmd_args > 0 then
    local command = cmd_args[1]
    if command == "rebuild" then
      require("craft2/master_rebuild")()
--    elseif command == "import_old_recipes" then
--      require("craft2/import_old_recipes").run(cmd_args[2])
    else
      print("Unknown command!")
      error()
    end
  else
    require("craft2/master")().run()
  end
else
  error("Invalid role in config")
end




