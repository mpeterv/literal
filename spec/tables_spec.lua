local literal = require "literal"

describe("tables", function()
   it("doesn't evaluate garbage", function()
      assert.errors(function() literal.eval_table'' end,
         [=[[string ""]:1: table literal expected near <eof>]=])
      assert.errors(function() literal.eval_table'}' end,
         [=[[string "}"]:1: table literal expected near '}']=])
   end)

   it("detects tables", function()
      local s = [[
      {
         foo = "bar", -- Comments are skipped
         true,
         [0xFFA] = [=[baz]=]
      }

      -- Whitespace and comments before and after literal are discarded as well
      ]]

      local t = literal.eval(s)
      assert.same({true, foo = "bar", [4090] = "baz"}, t)
   end)

   it("evaluates empty tables", function()
      assert.same({}, literal.eval_table'{}')
   end)

   it("evaluates tables with extra separator", function()
      assert.same({0.5}, literal.eval_table'{0.5,}')
      assert.same({0.5}, literal.eval_table'{0.5;}')
      assert.same({foo = "bar"}, literal.eval_table'{["foo"]="bar",}')
      assert.same({foo = "bar"}, literal.eval_table'{["foo"]="bar";}')
   end)

   it("doesn't evaluate keys without closing bracket", function()
      assert.errors(function() literal.eval_table'{[{}}' end,
         [=[[string "{[{}}"]:1: ']' expected near '}']=])
      assert.errors(function() literal.eval_table'{[-7e5;}' end,
         [=[[string "{[-7e5;}"]:1: ']' expected near ';}']=])
   end)

   it("doesn't evaluate nil keys", function()
      assert.errors(function() literal.eval_table'{"foo"; [nil] = false}' end,
         [=[[string "{"foo"; [nil] = false}"]:1: table index is nil near ']']=])
   end)

   it("doesn't evaluate keywords as bracket-less keys", function()
      assert.errors(function() literal.eval_table'{break = false}' end,
         [=[[string "{break = false}"]:1: unexpected symbol near 'break']=])
      assert.errors(function() literal.eval_table('{goto = false}', "5.2") end,
         [=[[string "{goto = false}"]:1: unexpected symbol near 'goto']=])
      assert.same({["goto"] = false}, literal.eval_table('{goto = false}', "5.1"))
   end)

   it("doesn't evaluate key-value pairs without =", function()
      assert.errors(function() literal.eval_table'{[true] foo}' end,
         [=[[string "{[true] foo}"]:1: '=' expected near 'foo}']=])
      assert.errors(function() literal.eval_table'{[1], 2}' end,
         [=[[string "{[1], 2}"]:1: '=' expected near ',']=])
   end)

   it("doesn't evaluate unfinished tables", function()
      assert.errors(function() literal.eval_table'{' end,
         [=[[string "{"]:1: literal expected near <eof>]=])
      assert.errors(function() literal.eval_table'{1' end,
         [=[[string "{1"]:1: '}' expected near <eof>]=])
      assert.errors(function() literal.eval_table'{foo\n="bar" baz' end,
         [=[[string "{foo..."]:2: '}' expected (to close '{' at line 1) near 'baz']=])
   end)

   it("doesn't evaluate empty tables with a separator", function()
      assert.errors(function() literal.eval_table'{,}' end,
         [=[[string "{,}"]:1: literal expected near ',}']=])
      assert.errors(function() literal.eval_table'{--[[]];--[[]]}' end,
         [=[[string "{--[[]];--[[]]}"]:1: literal expected near ';--[[]]}']=])
   end)

   it("doesn't evaluate tables with extra separators", function()
      assert.errors(function() literal.eval_table'{;[{}]=.7}' end,
         [=[[string "{;[{}]=.7}"]:1: literal expected near ';[{}]=.7}']=])
      assert.errors(function() literal.eval_table'{1, ;3, -0xf}' end,
         [=[[string "{1, ;3, -0xf}"]:1: literal expected near ';3,']=])
   end)

   it("skips comments", function()
      local s = [==[
      {--[[]]foo--
=--[=[foo]=]"bar";-- Comments are skipped
true--[[this works in Lua]],[0xFFA]=[=[baz]=]--
}
      ]==]

      local t = literal.eval_table(s)
      assert.same({true, foo = "bar", [4090] = "baz"}, t)
   end)

   it("doesn't evaluate deep tables", function()
      assert.errors(function() literal.eval_table(('{'):rep(201) .. ('}'):rep(201)) end,
         [=[[string "{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{..."]:1: table is too deep near '{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}']=])
   end)
end)
