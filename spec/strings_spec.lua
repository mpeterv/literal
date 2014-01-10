local literal = require "literal"

describe("short strings", function()
   it("doesn't eval garbage", function()
      assert.errors(function() literal.eval_short_string'' end,
         "[string \"\"]:1: short string expected near <eof>")
      assert.errors(function() literal.eval_short_string'foo' end,
         "[string \"foo\"]:1: short string expected near 'foo'")
      assert.errors(function() literal.eval_short_string'\r\n\rfoo' end,
         "[string \"...\"]:3: short string expected near 'foo'")
   end)

   it("evals empty strings", function()
      assert.equal('', literal.eval_short_string[['']])
      assert.equal('', literal.eval_short_string[[""]])
   end)

   it("evals simple strings", function()
      assert.equal('foo', literal.eval_short_string[['foo']])
      assert.equal('foo', literal.eval_short_string[["foo"]])
   end)

   it("evals strings with quotes", function()
      assert.equal('"foo"', literal.eval_short_string[['"foo"']])
      assert.equal('\'foo\'', literal.eval_short_string[["'foo'"]])
   end)

   it("detects short strings", function()
      assert.equal('foo', literal.eval_string[['foo']])
   end)

   it("detects strings", function()
      assert.equal('foo', literal.eval[['foo']])
   end)

   it("evals strings with simple escape sequences", function()
      assert.equal('\afo\no \\\'\\', literal.eval_short_string[['\afo\no \\\'\\']])
      assert.equal('\b\t\\\f\nn\rr\vv', literal.eval_short_string[['\b\t\\\f\nn\rr\vv']])
      assert.equal('\"\\\'', literal.eval_short_string[['\"\\\'']])
   end)

   it("substitutes newlines after backslash", function()
      assert.equal('foo\nbar', literal.eval_short_string([['foo\]] .. '\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval_short_string([['foo\]] .. '\r' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval_short_string([['foo\]] .. '\r\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval_short_string([['foo\]] .. '\n\r' .. [[bar']]))
      assert.errors(function() literal.eval_short_string([['foo\]] .. '\n\n' .. [[bar']]) end,
         "[string \"'foo\\...\"]:2: unfinished string near 'bar'")
      assert.errors(function() literal.eval_short_string([['foo\]] .. '\r\r' .. [[bar']]) end,
         "[string \"'foo\\...\"]:2: unfinished string near 'bar'")
   end)

   it("evals strings with decimal escape sequences", function()
      assert.equal('\afo\no\0002\1bar', literal.eval_short_string[['\afo\no\0002\1bar']])
      assert.equal('\\\255\00\0\1111', literal.eval_short_string[['\\\255\00\0\1111']])
   end)

   it("evals strings with hexadecimal escape sequences with Lua 5.2 grammar", function()
      assert.equal('A\\Z', literal.eval_short_string([['\x41\\\x5A']], "5.2"))
      assert.equal('\\x\0\255', literal.eval_short_string([['\\x\x00\xFf']], "5.2"))
      assert.equal('\0' .. '0', literal.eval_short_string([['\x000']], "5.2"))
   end)

   it("evals strings with z escape sequences with Lua 5.2 grammar", function()
      assert.equal('foobar', literal.eval_short_string([['foo\z]] .. '\n \f \t\n\rbar' .. [[']], "5.2"))
      assert.equal('\nfoo\n', literal.eval_short_string([['\nfo\zo\n']], "5.2"))
   end)
end)

describe("long strings", function()
   it("doesn't eval garbage", function()
      assert.errors(function() literal.eval_long_string'' end,
         "[string \"\"]:1: long string expected near <eof>")
      assert.errors(function() literal.eval_long_string'foo' end,
         "[string \"foo\"]:1: long string expected near 'foo'")
      assert.errors(function() literal.eval_long_string'\r\n\rfoo' end,
         "[string \"...\"]:3: long string expected near 'foo'")
   end)

   it("evals empty strings", function()
      assert.equal('', literal.eval_long_string'[[]]')
      assert.equal('', literal.eval_long_string'[=[]=]')
      assert.equal('', literal.eval_long_string'[===[]===]')
   end)

   it("doesn't eval unfinished strings", function()
      assert.equal('', literal.eval_long_string'[[]]')
      assert.equal('', literal.eval_long_string'[=[]=]')
      assert.equal('', literal.eval_long_string'[===[]===]')
   end)

   it("evals simple strings", function()
      assert.equal('foo', literal.eval_long_string'[[foo]]')
      assert.equal('foo', literal.eval_long_string'[====[foo]====]')
   end)

   it("evals strings with closing brackets of different level", function()
      assert.equal('foo[=[]=]bar', literal.eval_long_string'[[foo[=[]=]bar]]')
      assert.equal('[[foo]]', literal.eval_long_string'[====[[[foo]]]====]')
   end)

   it("detects long strings", function()
      assert.equal('foo', literal.eval_string'[[foo]]')
      assert.equal('foo', literal.eval_string'[=====[foo]=====]')
   end)

   it("detects strings", function()
      assert.equal('foo', literal.eval'[[foo]]')
      assert.equal('foo', literal.eval'[=[foo]=]')
   end)

   it("removes first newline", function()
      assert.equal('foo', literal.eval'[[\nfoo]]')
      assert.equal('foo', literal.eval'[[\rfoo]]')
      assert.equal('foo', literal.eval'[[\n\rfoo]]')
      assert.equal('foo', literal.eval'[[\r\nfoo]]')
      assert.equal('\nfoo', literal.eval'[[\n\nfoo]]')
   end)
end)
