
component = require("component")
internet = component.internet 
computer = require("computer")


local start_timestamp = nil
real_time = {}

real_time.sync = function()  
  result = internet.request("http://wiki.idzaaus.org/test2/current_time.php")
  for i=1,10 do
    text = result.read()
    if text ~= "" then 
      start_timestamp = tonumber(text) - computer.uptime()
      break
    end
  end
end

real_time.get = function()
  return start_timestamp + computer.uptime()
end

real_time.get_string = function(fmt)
  if not fmt then 
    fmt = "%d.%m.%Y %H:%M:%S"
  end 
  return os.date(fmt, real_time.get())
end

real_time.sync()


return real_time 
