local literal = require "literal"

describe("numbers", function()
   it("doesn't evaluate garbage", function()
      assert.errors(function() literal.eval_number'' end,
         [=[[string ""]:1: numerical constant expected near <eof>]=])
      assert.errors(function() literal.eval_number'hex' end,
         [=[[string "hex"]:1: numerical constant expected near 'hex']=])
   end)

   it("detects numbers", function()
      assert.equal(0, literal.eval_number'0')
      assert.equal(0, literal.eval_number'0x0')
      assert.equal(0, literal.eval_number'0.0')
      assert.equal(0, literal.eval_number'.0')
      assert.equal(0, literal.eval_number'0.')
   end)

   it("evaluates decimal constants", function()
      assert.equal(25678, literal.eval_number'25678')
      assert.equal(-0.58, literal.eval_number'-.580')
      assert.equal(-200000, literal.eval_number'-2e+5')
      assert.equal(0.9, literal.eval_number'+9E-1')
   end)

   it("evaluates hexadecimal integer constants", function()
      assert.equal(15, literal.eval_number'0xf')
      assert.equal(-10, literal.eval_number'-0xA')
      assert.equal(255, literal.eval_number'+0xFf')
   end)

   it("only evaluates hexadecimal float constants with Lua 5.2 grammar", function()
      assert.equal(15.5, literal.eval_number('0xF.8', "5.2"))
      assert.equal(-18.03125, literal.eval_number('-0x12.08', "5.2"))
      assert.equal(0.5, literal.eval_number('0x1p-1', "5.2"))
      assert.equal(1024, literal.eval_number('0x.8p11', "5.2"))
      assert.equal(-16269.358287811279, literal.eval_number('-0xfE35.6ee3P-2', "5.2"))

      assert.errors(function() literal.eval_number('0xF.8', "5.1") end,
         [=[[string "0xF.8"]:1: <eof> expected near '.8']=])
      assert.errors(function() literal.eval_number('-0x12.08', "5.1") end,
         [=[[string "-0x12.08"]:1: <eof> expected near '.08']=])
      assert.errors(function() literal.eval_number('0x1p-1', "5.1") end,
         [=[[string "0x1p-1"]:1: <eof> expected near 'p-1']=])
   end)

   it("doesn't evaluate malformed numbers", function()
      assert.errors(function() literal.eval_number'FOOBAR' end,
         [=[[string "FOOBAR"]:1: malformed number near 'FOOBAR']=])
      assert.errors(function() literal.eval_number('0x.', "5.2") end,
         [=[[string "0x."]:1: malformed number near <eof>]=])
   end)
end)
