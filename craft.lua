package.path = package.path .. ';scripts/?.lua'

local craft = require("libcraft/craft")
craft.run_craft();