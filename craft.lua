package.path = package.path .. ';/libs/?.lua;/libcraft/?.lua'

local craft = require("libcraft/craft")
craft.run_craft();
