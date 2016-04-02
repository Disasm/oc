
local r = {};

function r.stack_to_chest_role(stack)
  if stack == nil then return "storage" end
  if stack.label == "Stick" then
    if stack.size == 1 then
      return "incoming"
    elseif stack.size == 2 then
      return "output"
    end
  elseif stack.label == "Crafting Table" then
    return "craft"
  elseif stack.label == "HV Cable" then
    return "Extruder"
  elseif stack.label == "Iron Item Casing" then
    return "Roller"
  elseif stack.label == "Dense Iron Plate" then
    return "Compressor"
  elseif stack.label == "Iron Coin" then
    return "Furnace"
  elseif stack.label == "Rubber" then
    return "Extractor"
  elseif stack.label == "Iron Dust" then
    return "Macerator"
  else
    print(string.format("Unknown marker: '%s'", stack.label))
  end
  return "storage"
end

return r
