local serialization = require("serialization")
local filesystem = require("filesystem")

local db = {}

function stackToString(stack)
    return stack.label
    --return stack.label.." ("..stack.name..")"
end

function readRecipeDir(directory)
    local recipes = {}
    for fileName in filesystem.list(directory) do
        local f = filesystem.open(directory.."/"..fileName, "r")
        local s = f:read(10000)
        f:close()
        
        recipes[#recipes+1] = serialization.unserialize(s)
    end
    return recipes
end

function db:init(directory)
    self.directory = directory
    self.recipes = {}
end

function db:load()
    self.recipes = readRecipeDir(self.directory)
end

function db:add(recipe)
    local fileName = self.directory.."/"..recipe.to.label..".txt"

    local f = filesystem.open(fileName, "w")
    f:write(serialization.serialize(recipe))
    f:close()

    self:load()
end

function db:get(index)
    return self.recipes[index]
end

function db:find(stack)
    for i = 1,#self.recipes do
        local s = self.recipes[i].to;
        if (s.label == stack.label) and (s.name == stack.name) then
            return i
        end
    end
    return nil
end

function db:findInexact(name)
    local ind = {}
    for i = 1,#self.recipes do
        local s = self.recipes[i].to;
        if string.find(string.lower(stackToString(s)), string.lower(name)) ~= nil then
            ind[#ind+1] = i;
        end
    end
    return ind
end

db.createStackFromNative = function(nativeStack)
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

db.makeStack = function(stack, count)
    return {
        label = stack['label'],
        name = stack['name'],
        size = count,
    }
end

return db
