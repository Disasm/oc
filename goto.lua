local movement = require("movement")

local argv = {...}

if #argv < 2 then
    print("Usage goto <x> <z>")
    return
end

local x, z = movement.get_pos()
print("Old position was: "..x..", "..z)

if argv[1] == "r" and argv[2] == "r" then
    movement.reset()
    return
end

x = tonumber(argv[1])
z = tonumber(argv[2])
movement.set_pos(x, z)
