local literal = require "literal"

describe("tables", function()
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

   it("doesn't evaluate empty tables with a separator", function()
      assert.errors(function() literal.eval_table'{,}' end,
         [=[[string "{,}"]:1: literal expected near ',}']=])
      assert.errors(function() literal.eval_table'{--[[]];--[[]]}' end,
         [=[[string "{--[[]];--[[]]}"]:1: literal expected near ';--[[]]}']=])
   end)

   it("doesn't evaluate tables with extra separators", function()
      assert.errors(function() literal.eval_table'{,}' end,
         [=[[string "{,}"]:1: literal expected near ',}']=])
      assert.errors(function() literal.eval_table'{--[[]];--[[]]}' end,
         [=[[string "{--[[]];--[[]]}"]:1: literal expected near ';--[[]]}']=])
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
end)
