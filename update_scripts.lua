local shell = require("shell")
url = "https://raw.githubusercontent.com/Disasm/oc/master/"
files = { "base64", "g", "goto", "movement", "tar", "update_scripts", "craft", "libcraft/craft", "libcraft/craft_chests", "libcraft/craft_db", "libcraft/craft_input" }
for i = 1, #files do 
  shell.execute("rm \""..files[i]..".lua\"")
  shell.execute("wget \""..url..files[i]..".lua\"")
end
