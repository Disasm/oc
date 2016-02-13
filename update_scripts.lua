local shell = require("shell")
url = "http://www.idzaaus.org/static/tmp/oc/"
files = { "g", "goto", "libs/movement", "update_scripts", "craft", "libcraft/craft", "libcraft/craft_chests", "libcraft/craft_db", "libcraft/craft_input", "libcraft/file_serialization" }
for i = 1, #files do 
  local name = files[i]..".lua"
  shell.execute("rm \""..name.."\"")
  shell.execute("wget \""..url..name.."\" \""..name.."\"")
end

package.loaded = nil
_G = nil
