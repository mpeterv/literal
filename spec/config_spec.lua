local literal = require "literal"

describe("configs", function()
   it("evaluates empty configs", function()
      assert.same({}, literal.eval_config'')
   end)

   it("evaluates non-empty configs", function()
      local s = [=[
foo = "bar";

--[[magic]] true = false

]=]
      local t = literal.eval_config(s)
      assert.same({["true"] = false, foo = "bar"}, t)

      s = [=[
foo = "bar"; baz = 
   567

magic = "gone"

]=]
      t = literal.eval_config(s)
      assert.same({magic = "gone", foo = "bar", baz = 567}, t)
   end)

   it("doesn't evaluate key-value pairs without =", function()
      assert.errors(function() literal.eval_config'true foo' end,
         [=[[string "true foo"]:1: '=' expected near 'foo']=])
   end)

   it("doesn't evaluate unfinished configs", function()
      assert.errors(function() literal.eval_config'foo' end,
         [=[[string "foo"]:1: '=' expected near <eof>]=])
   end)

   it("doesn't evaluate empty config with a semicolon", function()
      assert.errors(function() literal.eval_config';' end,
         [=[[string ";"]:1: unexpected symbol near ';']=])
   end)

   it("doesn't evaluate deep configs", function()
      assert.errors(function() literal.eval_config('foo = ' .. ('{'):rep(200) .. ('}'):rep(200)) end,
         [=[[string "foo = {{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{{..."]:1: table is too deep near '{}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}}']=])
   end)
end)
