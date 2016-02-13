local file_serialization = require("file_serialization")
local filesystem = require("filesystem")



local db = {}

function stackToString(stack)
    return stack.label
    --return stack.label.." ("..stack.name..")"
end

function readRecipeDir(directory)
    local recipes = {}
    for fileName in filesystem.list(directory) do
        recipes[#recipes+1] = file_serialization.load(directory.."/"..fileName)
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
    local index = db:find(recipe.to)
    if index ~= nil then 
        self.recipes[index] = recipe
    else
        self.recipes[#self.recipes + 1] = recipe
    end
  
    local fileName = self.directory.."/"..recipe.to.label..".txt"
    file_serialization.save(fileName, recipe)
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
