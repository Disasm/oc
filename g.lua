local tArgs = { ... }
if #tArgs < 1 then
	print( "Usage: g [direction] <distance>" )
	return
end

local robot = require("robot")
local computer = require("computer")

local tHandlers = {
    ["f"] = robot.forward,
	["fd"] = robot.forward,
	["forward"] = robot.forward,
	["forwards"] = robot.forward,
	["b"] = robot.back,
	["bk"] = robot.back,
	["back"] = robot.back,
	["u"] = robot.up,
	["up"] = robot.up,
	["d"] = robot.down,
	["dn"] = robot.down,
	["down"] = robot.down,
	["l"] = robot.turnLeft,
	["lt"] = robot.turnLeft,
	["left"] = robot.turnLeft,
	["r"] = robot.turnRight,
	["rt"] = robot.turnRight,
	["right"] = robot.turnRight,
}

local nArg = 1
while nArg <= #tArgs do
    local sDirection = "f"
    if tonumber(tArgs[nArg])==nil then
        sDirection = tArgs[nArg]
        nArg = nArg + 1
    end
	local nDistance = 1
	if nArg <= #tArgs then
		local num = tonumber( tArgs[nArg] )
		if num then
			nDistance = num
			nArg = nArg + 1
		end
	end

	local fnHandler = tHandlers[string.lower(sDirection)]
	if fnHandler then
		for n=1,nDistance do
			fnHandler( nArg )
		end
	else
		print( "No such direction: "..sDirection )
		print( "Try: forward, back, up, down" )
		return
	end
end
