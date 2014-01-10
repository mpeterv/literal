package = "literal"
version = "git-1"
source = {
   url = "git://github.com/mpeterv/literal.git"
}
description = {
   summary = "write me!",
   detailed = [[write me!]],
   homepage = "https://github.com/mpeterv/literal",
   license = "Public domain"
}
dependencies = {
   "lua >= 5.1, < 5.3",
   "30log >= 0.6"
}
build = {
   type = "builtin",
   modules = {
      literal = "src/literal.lua"
   },
   copy_directories = {}
}
