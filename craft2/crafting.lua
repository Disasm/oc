local module_r = {}
function module_r.process_task(task)
  local master = require("craft2/master_main")
  local l = master.log

  l.error("craft task is not implemented yet")
  return false



end

function module_r.has_recipe(item_id)
  return false
end



return module_r
