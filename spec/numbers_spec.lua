local literal = require "literal"

describe("numbers", function()
   it("doesn't evaluate garbage", function()
      assert.errors(function() literal.eval_number'' end,
         [=[[string ""]:1: numerical constant expected near <eof>]=])
      assert.errors(function() literal.eval_number'FOO BAR BAZ!' end,
         [=[[string "FOO BAR BAZ!"]:1: numerical constant expected near 'FOO']=])
   end)

   it("detects numbers", function()
      assert.equal(0, literal.eval'0')
      assert.equal(0, literal.eval'0x0')
      assert.equal(0, literal.eval'0.0')
      assert.equal(0, literal.eval'.0')
      assert.equal(0, literal.eval'0.')
   end)
end)
