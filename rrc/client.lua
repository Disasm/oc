rpc = require("/libs/rpc")
robot = require("robot")
component = require("component")

function fill(tbl, prefix, obj)
    for k,v in pairs(obj) do
        tbl[prefix.."_"..k] = v
    end
end

t = {}
fill(t, "r", robot)
fill(t, "rs", component.redstone)
fill(t, "ic", component.inventory_controller)

rpc.bind(t)
