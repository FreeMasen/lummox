package = "lummox"
version = "dev-1"
source = {
   url = "git+ssh://git@github.com/FreeMasen/lummox.git"
}
description = {
   homepage = "https://github.com/FreeMasen/lummox",
   license = "MIT"
}
build = {
   type = "builtin",
   modules = {
      lummox = "lummox/init.lua",
      ["lummox.document"] = "lummox/document.lua",
      ["lummox.element"] = "lummox/element.lua",
      ["lummox.utils"] = "lummox/utils.lua",
   }
}
