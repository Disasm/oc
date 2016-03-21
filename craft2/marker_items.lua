
local r = {};

function r.stack_to_chest_role(stack)
  if stack == nil then return "storage" end 
  if stack.label == "Stick" then 
    if stack.size == 1 then
      return "incoming"
    elseif stack.size == 2 then 
      return "output"
    end
  end
  return "storage"
end

return r
