util = {}

function util.createStackFromNative(nativeStack)
    if nativeStack == nil then
        return nil
    else
        return {
            label = nativeStack['label'],
            name = nativeStack['name'],
            size = nativeStack['size'],
        }
    end
end

function util.stackHash(stack)
  return stack.name.."_"..stack.label
end

function util.makeStack(stack, newSize)
  newStack = {}
  for k,v in pairs(stack) do
    newStack[k] = v
  end
  if newSize ~= nil then
    newStack.size = newSize
  end
  return newStack
end

return util
