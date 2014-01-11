local literal = require "literal"

describe("short strings", function()
   it("evaluates empty strings", function()
      assert.equal('', literal.eval[['']])
      assert.equal('', literal.eval[[""]])
   end)

   it("evaluates simple strings", function()
      assert.equal('foo', literal.eval[['foo']])
      assert.equal('foo', literal.eval[["foo"]])
   end)

   it("evaluates strings with quotes", function()
      assert.equal('"foo"', literal.eval[['"foo"']])
      assert.equal('\'foo\'', literal.eval[["'foo'"]])
   end)

   it("detects short strings", function()
      assert.equal('foo', literal.eval[['foo']])
   end)

   it("detects strings", function()
      assert.equal('foo', literal.eval[['foo']])
   end)

   it("evaluates strings with simple escape sequences", function()
      assert.equal('\afo\no \\\'\\', literal.eval[['\afo\no \\\'\\']])
      assert.equal('\b\t\\\f\nn\rr\vv', literal.eval[['\b\t\\\f\nn\rr\vv']])
      assert.equal('\"\\\'', literal.eval[['\"\\\'']])
   end)

   it("doesn't evaluate strings with unknown escape sequences", function()
      assert.errors(function() literal.eval[['foo\jbar']] end,
         [=[[string "'foo\jbar'"]:1: invalid escape sequence near '\j']=])
      assert.errors(function() literal.eval[['foo\]] end,
         [=[[string "'foo\"]:1: unfinished string near ''foo\']=])
      assert.errors(function() literal.eval([['foo\]] .. '\a' .. [[']]) end,
         [=[[string "'foo\..."]:1: invalid escape sequence near '\']=])
   end)

   it("substitutes newlines after backslash", function()
      assert.equal('foo\nbar', literal.eval([['foo\]] .. '\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval([['foo\]] .. '\r' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval([['foo\]] .. '\r\n' .. [[bar']]))
      assert.equal('foo\nbar', literal.eval([['foo\]] .. '\n\r' .. [[bar']]))
      assert.errors(function() literal.eval([['foo\]] .. '\n\n' .. [[bar']]) end,
         [=[[string "'foo\..."]:1: unfinished string near ''foo\']=])
      assert.errors(function() literal.eval([['foo\]] .. '\r\r' .. [[bar']]) end,
         [=[[string "'foo\..."]:1: unfinished string near ''foo\']=])
   end)

   it("evaluates strings with decimal escape sequences", function()
      assert.equal('\afo\no\0002\1bar', literal.eval[['\afo\no\0002\1bar']])
      assert.equal('\\\255\00\0\1111', literal.eval[['\\\255\00\0\1111']])
      assert.errors(function() literal.eval[['foo\912bar']] end,
         [=[[string "'foo\912bar'"]:1: decimal escape too large near '\912']=])
   end)

   it("evaluates strings with hexadecimal escape sequences with Lua 5.2 grammar", function()
      assert.equal('A\\Z', literal.eval([['\x41\\\x5A']], "5.2"))
      assert.equal('\\x\0\255', literal.eval([['\\x\x00\xFf']], "5.2"))
      assert.equal('\0' .. '0', literal.eval([['\x000']], "5.2"))
      assert.errors(function() literal.eval([['\x4\\\x5A']], "5.2") end,
         [=[[string "'\x4\\\x5A'"]:1: hexadecimal digit expected near '\x4\']=])
      assert.errors(function() literal.eval([['\x41\\\x5A']], "5.1") end,
         [=[[string "'\x41\\\x5A'"]:1: invalid escape sequence near '\x']=])
   end)

   it("evaluates strings with z escape sequences with Lua 5.2 grammar", function()
      assert.equal('foobar', literal.eval([['foo\z]] .. '\n \f \t\n\rbar' .. [[']], "5.2"))
      assert.equal('\nfoo\n', literal.eval([['\nfo\zo\n']], "5.2"))
      assert.errors(function() literal.eval([['\nfo\zo\n']], "5.1") end,
         [=[[string "'\nfo\zo\n'"]:1: invalid escape sequence near '\z']=])
   end)
end)

describe("long strings", function()
   it("evaluates empty strings", function()
      assert.equal('', literal.eval'[[]]')
      assert.equal('', literal.eval'[=[]=]')
      assert.equal('', literal.eval'[===[]===]')
   end)

   it("doesn't evaluate unfinished strings", function()
      assert.errors(function() literal.eval'[[\n' end,
         [=[[string "[[..."]:1: unfinished long string near '[[']=])
      assert.errors(function() literal.eval'[=[]]]==]' end,
         [=[[string "[=[]]]==]"]:1: unfinished long string near '[=[]]]==]']=])
   end)

   it("evaluates simple strings", function()
      assert.equal('foo', literal.eval'[[foo]]')
      assert.equal('foo', literal.eval'[====[foo]====]')
   end)

   it("evaluates strings with closing brackets of different level", function()
      assert.equal('foo[=[]=]bar', literal.eval'[[foo[=[]=]bar]]')
      assert.equal('[[foo]]', literal.eval'[====[[[foo]]]====]')
   end)

   it("detects long strings", function()
      assert.equal('foo', literal.eval'[[foo]]')
      assert.equal('foo', literal.eval'[=====[foo]=====]')
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
