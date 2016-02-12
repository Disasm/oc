local shell = require("shell")
url = "https://raw.githubusercontent.com/Disasm/oc/master/"
files = { "g", "goto", "libs/movement", "update_scripts", "craft", "libcraft/craft", "libcraft/craft_chests", "libcraft/craft_db", "libcraft/craft_input" }
for i = 1, #files do 
  local name = files[i]..".lua"
  shell.execute("rm \""..name.."\"")
  shell.execute("wget \""..url..name.."\" \""..name.."\"")
end
