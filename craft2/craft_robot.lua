local rpc = require("rpc")
local robot = require("robot")
local component = require("component")
local craft = component.crafting.craft

robot.select(16)

api = {}

api.craft = craft

rpc.bind(api)
