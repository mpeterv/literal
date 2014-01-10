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
