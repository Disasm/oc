local component = require("component")
local filesystem = require("filesystem")
local event = require("event")
local fser = require("libs/file_serialization")

local modem = component.modem 
local hosts_filename = "/lib/hosts.lua"

local the_port = 10101

function get_hostname()
  local f = filesystem.open("/etc/hostname", "r")
  if not f then error("failed to read hostname") end
  local s = f:read(math.huge)
  f:close()
  return s
end 
  
local hostname = get_hostname()
local hosts = fser.load(hosts_filename)
if not hosts then 
  hosts = {}
  fser.save(hosts_filename, hosts, true)
end 
print("My hostname: "..hostname)
for k, v in pairs(hosts) do 
  print("Known hostname: "..k)  
end


function on_message(_, _, remote_addr, port, _, payload) 
  if the_port == port then 
    if not hosts[payload] then 
      print("New host added: "..payload)
      hosts[payload] = remote_addr
      fser.save(hosts_filename, hosts, true)
    end
  end
end 

function on_timer()
  modem.broadcast(the_port, hostname)
end

event.listen("modem_message", on_message)
modem.open(the_port)

event.timer(3, on_timer, math.huge)

