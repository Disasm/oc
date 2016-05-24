local config = require("craft2/config")

local root = config.data_root or "/var/craft2/"
return {
  item_db = root.."item_db/",
  content_cache = root.."content_cache/",
  topology = root.."topology",
  recipes = function(id)
    return string.format("%srecipes/%d", root, id)
  end
}
