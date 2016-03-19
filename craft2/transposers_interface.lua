local component = require("component")

local r = {}
function r.get_transposers()
  local result = {}
  for address, _ in component.list("transposer", true) do 
    table.insert(result, address)
  end
  return result
end
return r
