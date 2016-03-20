local component = require("component")
local event = require("event")
local filesystem = require("filesystem")
local shell = require("shell")

function on_added(_, address, name)
  if name == "filesystem" then 
    print("")
    print("New filesystem added")
    local target_path = nil
    for proxy, mount_point in filesystem.mounts() do 
      if proxy.address == address then 
        target_path = mount_point
        break 
      end
    end
    if not target_path then error("Failed to find mount point") end 
    source_path = "/mnt/7e2/"
    print(string.format("Copying files from %s to %s...", source_path, target_path))
    shell.execute(string.format("cp -r %s* %s", source_path, target_path))
    print("Done")
  end 
end

event.listen("component_added", on_added)
