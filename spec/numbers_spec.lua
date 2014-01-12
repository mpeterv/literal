local literal = require "literal"

describe("numbers", function()
   it("detects numbers", function()
      assert.equal(0, literal.eval'0')
      assert.equal(0, literal.eval'0x0')
      assert.equal(0, literal.eval'0.0')
      assert.equal(0, literal.eval'.0')
      assert.equal(0, literal.eval'0.')
   end)

   it("evaluates decimal constants", function()
      assert.equal(25678, literal.eval'25678')
      assert.equal(-0.58, literal.eval'-.580')
      assert.equal(-200000, literal.eval'-2e+5')
      assert.equal(0.9, literal.eval'+9E-1')
   end)

   it("evaluates hexadecimal integer constants", function()
      assert.equal(15, literal.eval'0xf')
      assert.equal(-10, literal.eval'-0xA')
      assert.equal(255, literal.eval'+0xFf')
   end)

   it("only evaluates hexadecimal float constants with Lua 5.2 grammar", function()
      assert.equal(15.5, literal.eval('0xF.8', "5.2"))
      assert.equal(-18.03125, literal.eval('-0x12.08', "5.2"))
      assert.equal(0.5, literal.eval('0x1p-1', "5.2"))
      assert.equal(1024, literal.eval('0x.8p11', "5.2"))
      assert.equal(-16269.358287811279, literal.eval('-0xfE35.6ee3P-2', "5.2"))

      assert.errors(function() literal.eval('0xF.8', "5.1") end,
         [=[[string "0xF.8"]:1: <eof> expected near '.8']=])
      assert.errors(function() literal.eval('-0x12.08', "5.1") end,
         [=[[string "-0x12.08"]:1: <eof> expected near '.08']=])
      assert.errors(function() literal.eval('0x1p-1', "5.1") end,
         [=[[string "0x1p-1"]:1: <eof> expected near 'p-1']=])
   end)

   it("doesn't evaluate numbers with inf exp as NaN", function()
      assert.equal(0, literal.eval(('1'):rep(500) .. 'e-100000'))
      assert.equal(0, literal.eval('0x' .. ('1'):rep(500) .. 'p-100000', "5.2"))
   end)
end)
