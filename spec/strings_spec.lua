local literal = require "literal"

describe("short strings", function()
   it("doesn't load garbage", function()
      assert.errors(function() literal.load_short_string'' end,
         "[string \"\"]:1: expected short string near <eof>")
      assert.errors(function() literal.load_short_string'foo' end,
         "[string \"foo\"]:1: expected short string near 'foo'")
      assert.errors(function() literal.load_short_string'\r\n\rfoo' end,
         "[string \"...\"]:3: expected short string near 'foo'")
   end)

   it("loads empty strings", function()
      assert.equal('', literal.load_short_string[['']])
      assert.equal('', literal.load_short_string[[""]])
   end)

   it("loads simple strings", function()
      assert.equal('foo', literal.load_short_string[['foo']])
      assert.equal('foo', literal.load_short_string[["foo"]])
   end)

   it("loads strings with quotes", function()
      assert.equal('"foo"', literal.load_short_string[['"foo"']])
      assert.equal('\'foo\'', literal.load_short_string[["'foo'"]])
   end)

   it("detects short strings", function()
      assert.equal('foo', literal.load_string[['foo']])
   end)

   it("detects strings", function()
      assert.equal('foo', literal.load[['foo']])
   end)

   it("loads strings with simple escape sequences", function()
      assert.equal('\afo\no \\\'\\', literal.load_short_string[['\afo\no \\\'\\']])
      assert.equal('\b\t\\\f\nn\rr\vv', literal.load_short_string[['\b\t\\\f\nn\rr\vv']])
      assert.equal('\"\\\'', literal.load_short_string[['\"\\\'']])
   end)

   it("substitutes newlines after backslash", function()
      assert.equal('foo\nbar', literal.load_short_string([['foo\]] .. '\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.load_short_string([['foo\]] .. '\r' .. [[bar']]))
      assert.equal('foo\nbar', literal.load_short_string([['foo\]] .. '\r\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.load_short_string([['foo\]] .. '\n\r' .. [[bar']]))
      assert.errors(function() literal.load_short_string([['foo\]] .. '\n\n' .. [[bar']]) end,
         "[string \"'foo\\...\"]:2: unfinished string near 'bar'")
      assert.errors(function() literal.load_short_string([['foo\]] .. '\r\r' .. [[bar']]) end,
         "[string \"'foo\\...\"]:2: unfinished string near 'bar'")
   end)

   it("loads strings with decimal escape sequences", function()
      assert.equal('\afo\no\0002\1bar', literal.load_short_string[['\afo\no\0002\1bar']])
      assert.equal('\\\255\00\0\1111', literal.load_short_string[['\\\255\00\0\1111']])
   end)

   it("loads strings with hexadecimal escape sequences with Lua 5.2 grammar", function()
      assert.equal('A\\Z', literal.load_short_string([['\x41\\\x5A']], "5.2"))
      assert.equal('\\x\0\255', literal.load_short_string([['\\x\x00\xFf']], "5.2"))
      assert.equal('\0' .. '0', literal.load_short_string([['\x000']], "5.2"))
   end)

   it("loads strings with z escape sequences with Lua 5.2 grammar", function()
      assert.equal('foobar', literal.load_short_string([['foo\z]] .. '\n \f \t\n\rbar' .. [[']], "5.2"))
      assert.equal('\nfoo\n', literal.load_short_string([['\nfo\zo\n']], "5.2"))
   end)
end)

describe("long strings", function()
   it("doesn't load garbage", function()
      assert.errors(function() literal.load_long_string'' end,
         "[string \"\"]:1: expected long string near <eof>")
      assert.errors(function() literal.load_long_string'foo' end,
         "[string \"foo\"]:1: expected long string near 'foo'")
      assert.errors(function() literal.load_long_string'\r\n\rfoo' end,
         "[string \"...\"]:3: expected long string near 'foo'")
   end)

   it("loads empty strings", function()
      assert.equal('', literal.load_long_string'[[]]')
      assert.equal('', literal.load_long_string'[=[]=]')
      assert.equal('', literal.load_long_string'[===[]===]')
   end)

   it("doesn't load unfinished strings", function()
      assert.equal('', literal.load_long_string'[[]]')
      assert.equal('', literal.load_long_string'[=[]=]')
      assert.equal('', literal.load_long_string'[===[]===]')
   end)

   it("loads simple strings", function()
      assert.equal('foo', literal.load_long_string'[[foo]]')
      assert.equal('foo', literal.load_long_string'[====[foo]====]')
   end)

   it("loads strings with closing brackets of different level", function()
      assert.equal('foo[=[]=]bar', literal.load_long_string'[[foo[=[]=]bar]]')
      assert.equal('[[foo]]', literal.load_long_string'[====[[[foo]]]====]')
   end)

   it("detects long strings", function()
      assert.equal('foo', literal.load_string'[[foo]]')
      assert.equal('foo', literal.load_string'[=====[foo]=====]')
   end)

   it("detects strings", function()
      assert.equal('foo', literal.load'[[foo]]')
      assert.equal('foo', literal.load'[=[foo]=]')
   end)

   it("removes first newline", function()
      assert.equal('foo', literal.load'[[\nfoo]]')
      assert.equal('foo', literal.load'[[\rfoo]]')
      assert.equal('foo', literal.load'[[\n\rfoo]]')
      assert.equal('foo', literal.load'[[\r\nfoo]]')
      assert.equal('\nfoo', literal.load'[[\n\nfoo]]')
   end)
end)
