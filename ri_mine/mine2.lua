local robot = require('robot')
local computer = require('computer')

local depth = 40
local count = 20
local useless_slots = 3

function move_smart(dir, restless) 
  local ok, error = false, nil
  while not ok do 
    if dir == "up" then 
      ok, error = robot.up()
    elseif dir == "forward" then 
      ok, error = robot.forward()
    elseif dir == "down" then 
      ok, error = robot.down()
    else 
      print("move_smart: invalid direction", dir);
      return false, 'invalid direction'
    end
    if not ok then
      if not restless and  error ~= "already moving" then 
        print("move failed: ", dir, error)
        break
      else 
        print("move failed, retrying: ", dir, error)
      end
    end  
  end  
  return ok, error 
end


function swing_sensibly(dir) 
  local detection, cause;
  if dir == "forward" then 
    detection, cause = robot.detect();
  elseif dir == "down" then 
    detection, cause = robot.detectDown();
  elseif dir == "up" then 
    detection, cause = robot.detectUp();
  end 
  if not detection then return true, '' end 
  if cause == "entity" then return false, 'entity in the way' end 
  if dir == "forward" then 
    return robot.swing()
  elseif dir == "down" then 
    return robot.swingDown()
  elseif dir == "up" then 
    return robot.swingUp()
  end 
end
    
    

local clear_slots_cooldown = 0
function clear_slots() 
  if clear_slots_cooldown == 0 then
    for i = 1,useless_slots do 
      if robot.count(i) > 21 then 
        robot.select(i)
        robot.drop(robot.count(i) - 1)
      end 
    end
    clear_slots_cooldown = 20
  else 
    clear_slots_cooldown = clear_slots_cooldown - 1
  end 
end 


local failure = false
local ok, error = false, nil
for i = 1,count do 
  if failure then break end 
  
  -- for j = 1,3 do
  swing_sensibly("forward")
  move_smart("forward", true)
  swing_sensibly("up")
  robot.turnRight()
  swing_sensibly("forward")
  move_smart("forward", true)
  swing_sensibly("up")
  robot.turnAround()
  move_smart("forward", true)
  robot.turnRight()
  -- end
  
  local current_z = 0
  for z = 1,depth do 
    clear_slots()
    ok, error = swing_sensibly("down")
    if not ok then
      print("swing down failed: ", error)
      break
    end
    ok, error = move_smart("down", false)
    if not ok then
      print("down failed: ", error)
      break
    end
    current_z = current_z + 1    
  end
  for z = 1,current_z do
    move_smart("up", true)
  end
end


robot.turnAround()
for i = 1,(count+1) do 
  move_smart("forward", true)
end 
robot.turnAround()
