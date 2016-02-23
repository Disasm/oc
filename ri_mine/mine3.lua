local robot = require('robot')
local computer = require('computer')

local useless_slots = 4

local args = { ... }
if #args < 2 then
	print( "Usage: mine3 count depth")
	return
end
local count = tonumber( args[1] )
local depth = tonumber( args[2] )
print("Count: ", count)
print("Depth: ", depth)
print("Useless slots count: ", useless_slots)
print("ATTENTION: check useless slots!")


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

for z = 1,depth do 
  for i = 1,count do 
    if failure then break end 
    ok = false 
    while not ok do 
      swing_sensibly("forward")
      clear_slots() 
      ok, _ = move_smart("forward", false)
    end 
    local block_up_ok = true
    local block_down_ok = true
    for j = 1,useless_slots do 
      robot.select(j)
      -- print("Comparing with", j)
      if robot.compareUp() then 
        -- print("up: compare=true, skip block")
        block_up_ok = false
      end
      if robot.compareDown() then 
        -- print("down: compare=true, skip block")
        block_down_ok = false
      end
    end
    if block_down_ok then 
      -- print("Mine down!")
      ok, error = swing_sensibly("down")
      clear_slots() 
      if not ok then
        print("swing down failed: ", error)
      end
    end
    if block_up_ok then 
      -- print("Mine up!")
      ok, error = swing_sensibly("up")
      clear_slots() 
      if not ok then
        print("swing up failed: ", error)
      end
    end
  end 
  robot.turnAround()
  for i = 1,count do 
    ok = false 
    while not ok do 
      swing_sensibly("forward")
      clear_slots() 
      ok, _ = move_smart("forward", false)
    end 
  end 
  robot.turnAround()
  for i = 1,3 do 
    swing_sensibly("down")
    clear_slots() 
    move_smart("down", true)
  end 
end 
for i = 1,(3*depth) do   
  move_smart("up", true)
end 
  
