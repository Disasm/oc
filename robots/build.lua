computer = require("computer")
robot = require("robot")
m = require("movement")
m.reset()
 
function gather(slot)
    for i=slot+1,robot.inventorySize() do
        if robot.space(slot) == 0 then
            return
        end
        if robot.count(i) > 0 then
            robot.select(i)
            robot.transferTo(slot)
        end
    end
end
 
function cleanup()
    for i=1,robot.inventorySize() do
        if robot.space(i) > 0 then
            gather(i)
        end
    end
end
 
function ensureBlock()
    if robot.count(1) > 0 then
        return
    end
    cleanup()
    if robot.count(1) == 0 then
        computer.beep(1000, 1)
        while robot.count(1) == 0 do
            os.sleep(1)
        end
    end
end
 
p = {}
 
function p.move(x, z)
    m.set_pos(x, z)
end
 
function p.place(x, z)
    m.set_pos(x, z)
    ensureBlock()
    robot.select(1)
    robot.placeDown()
end
 
function p.rect(xSize, zSize)
    local x0, z0 = m.get_pos()
    local dz = 1
    local z = 1
    for x=1,xSize do
        while true do
            p.place(x0 + x - 1, z0 + z - 1)
            z = z + dz
            if z == 0 then
                z = 1
                dz = -dz
                break
            end
            if z == zSize+1 then
                z = zSize
                dz = -dz
                break
            end
        end
    end
end
 
function p.square(xSize, zSize)
    local x0, z0 = m.get_pos()
    p.rect(1, zSize)
   
    p.move(x0+xSize-1, z0)
    p.rect(1, zSize)
   
    p.move(x0+1, z0)
    p.rect(xSize-2, 1)
   
    p.move(x0+1, z0+zSize-1)
    p.rect(xSize-2, 1)
end
 
function p.nextLayer()
    robot.up()
end
 
 
 
--p.move(0, 0)
--p.rect(20, 20)
--p.nextLayer()
 
for i=1,2 do
    p.move(0, 0)
    p.square(20, 20)
   
    p.move(1, 1)
    p.rect(8, 8)
   
    p.move(11, 1)
    p.rect(8, 8)
   
    p.move(1, 11)
    p.rect(8, 8)
   
    p.move(11, 11)
    p.rect(8, 8)
    p.nextLayer()
end
 
for i=1,3 do
    p.move(0, 0)
    p.square(20, 20)
    p.nextLayer()
end
 
p.move(0, 0)
p.rect(20, 20)
p.nextLayer()