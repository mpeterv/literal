local literal = require "literal"

describe("protected versions of functions", function()
   describe("literal.peval", function()
      it("returns correct result", function()
         local s = [[
         {
            foo = "bar", -- Comments are skipped
            true,
            [0xFFA] = [=[baz]=]
         }

         -- Whitespace and comments before and after literal are discarded as well
         ]]

         local ok, t = literal.peval(s)
         assert.is_true(ok)
         assert.same({true, foo = "bar", [4090] = "baz"}, t)
      end)

      it("returns correct error message", function()
         local s = [[
{
   foo = "bar"
]]

         local ok, err = literal.peval(s)
         assert.is_false(ok)
         assert.equal([=[[string "{..."]:3: '}' expected (to close '{' at line 1) near <eof>]=], err)
      end)
   end)

   describe("literal.peval_config", function()
      it("returns correct result", function()
         local s = [=[
foo = "bar";

--[[magic]] true = false

]=]
         local ok, t = literal.peval_config(s)
         assert.is_true(ok)
         assert.same({["true"] = false, foo = "bar"}, t)
      end)

      it("returns correct error message", function()
         local ok, err = literal.peval_config'foo'
         assert.is_false(ok)
         assert.equal([=[[string "foo"]:1: '=' expected near <eof>]=], err)
      end)
   end)
end)
