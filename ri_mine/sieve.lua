local robot = require("robot")
local libmine = require("libmine")

local args = {...}
local mode = args[1] or "d"

local mode_names = { c = "Cobblestone / Gravel", s = "Sand", d = "Dust"}
if not mode_names[mode] then
  error("Invalid mode")
end
print("Mode: ".. mode_names[mode])


local function get_tool()
  libmine.equip("empty")

end

local function do_swing(is_final, dir)
  if is_final then
    robot.select(2)
  else
    robot.select(1)
  end
  local func
  if dir == "front" then
    func = robot.swing
  elseif dir == "up" then
    func = robot.swingUp
  else
    error("unsupported dir")
  end
  while true do
    local ok, err = robot.swing()
    if ok then
      break
    end
    if err == "block" then

    end
  end
end

while true do
  do_swing(mode == "c", "front")
  if mode ~= "c" then
    while not robot.placeUp() do end
    do_swing(mode == "s", "up")
    if mode ~= "s" then
      while not robot.placeUp() do end
      do_swing(true, "up")
    end
  end
end

