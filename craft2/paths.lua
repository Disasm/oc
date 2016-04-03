local root = "/var/craft2/"
return {
  item_db = root.."item_db/",
  content_cache = root.."content_cache/",
  topology = root.."topology",
  recipes = function(id)
    return string.format("%srecipes/%d", root, id)
  end
}
