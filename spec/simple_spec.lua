local literal = require "literal"

describe("simple literals", function()
   it("evaluates simple literals", function()
      assert.equal(true, literal.eval'true')
      assert.equal(false, literal.eval'false')
      assert.equal(nil, literal.eval'nil')
   end)
end)
