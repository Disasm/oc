
local module_r = {} 
function module_r.create_storage()
  local master = require("craft2/master_main")
  local l = master.log 
  local r = {}
  function r.load_all_from_chest(chest) 
    l.error("r.load_all_from_chest is not implemented yet")
    return false 
  end 
  
  return r
end 
return module_r 
