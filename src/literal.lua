--- A library for safe evaluation of Lua literal expressions. 
-- @module literal
-- @author Peter Melnichenko
-- @license Public Domain
local literal = {}

local class = require "30log"


--- Default grammar is the Lua version used to run literal. 
-- @field grammar
if _VERSION:find "5.2" then
   literal.grammar = "5.2"
else
   literal.grammar = "5.1"
end

local buffer = class()

function buffer:__init()
   self.n = 0
end

function buffer:add(s)
   self.n = self.n+1
   self[self.n] = s
   return self
end

function buffer:res()
   return table.concat(self)
end

literal.Cursor = class()
literal.Cursor.max_repr_length = 45

function literal.Cursor:__init(str, grammar, filename)
   self.str = str
   self.grammar = grammar or literal.grammar
   self.len = str:len()+1
   self.i = 1
   self.char = str:sub(1, 1)
   self.line = 1

   if filename then
      self.repr = filename
   else
      self.repr = self:match("([ %p%d%a]+)") or ""

      if self.repr:len() > self.max_repr_length or self.repr:len() ~= str:len() then
         self.repr = self.repr:sub(1, self.max_repr_length) .. "..."
      end

      self.repr = ("[string \"%s\"]"):format(self.repr)
   end

   -- Is current char the first half of two-chars newline?
   if self:match '\r\n' or self:match '\n\r' then
      self.bound = true
   else
      self.bound = false
   end
end

function literal.Cursor:error(msg, chunk)
   local line = self.line

   if not chunk then
      self:skip_space_and_comments()
      chunk = self:match("([_%d%a]+)")

      if chunk then
         chunk = "'" .. chunk .. "'"
      else
         chunk = "<eof>"
      end
   end

   error(("%s:%d: %s near %s"):format(self.repr, line, msg, chunk))
end

function literal.Cursor:assert(assertion, msg, chunk)
   return assertion or self:error(msg, chunk)
end

function literal.Cursor:invalid_escape()
   self:error("invalid escape sequence", "'\\" .. self:match '(%C?)' .. "'")
end

-- Can only jump forward
function literal.Cursor:jump(i)
   assert(i <= self.len)
   local cur_newline, new_i, old_i

   while self.i < i do
      new_i = self:find '[\r\n]'

      if not new_i or new_i > i then
         new_i = i
      end

      if self:match '[\r\n]' then
         if not self.bound then
            self.line = self.line+1
         end
      end

      old_i, self.i = self.i, new_i

      if self:match '\r\n' or self:match '\n\r' then
         if self.i-old_i == 1 and self.bound then
            self.bound = false
         else
            self.bound = true
         end
      else
         self.bound = false
      end
   end

   self.char = self.str:sub(i, i)

   return self
end

function literal.Cursor:step(di)
   return self:jump(self.i+(di or 1))
end

function literal.Cursor:find(pattern, plain)
   return self.str:find(pattern, self.i+1, plain)
end

function literal.Cursor:match(pattern)
   return self.str:match('^' .. pattern, self.i)
end

function literal.Cursor:skip_newline()
   local old_char = self.char
   self:step()

   if self.char:match '[\r\n]' and self.char ~= old_char then
      self:step()
   end

   return self
end

function literal.Cursor:skip_space()
   return self:jump(self:match '%s*()')
end

function literal.Cursor:skip_space_and_comments()
   while true do
      self:skip_space()

      if self:match '%-%-' then
         -- Comment
         self:step(2)

         if self:match '%[=*%[' then
            -- Long comment
            self:eval_long_string()
         else
            -- Short comment
            self:jump(self:match '[^\r\n]*()')
         end
      else
         return self
      end
   end
end

function literal.Cursor:finish()
   self:skip_space_and_comments()
   self:assert(self.i == self.len, "<eof> expected")
   return self
end

function literal.Cursor:eval_long_string()
   local second_opening_bracket = self:assert(self:match '%[=*()%[', "long string expected")

   local level = second_opening_bracket-self.i-1
   self:jump(second_opening_bracket+1)

   if self:match '[\r\n]' then
      self:skip_newline()
   end

   local patt = '(.-)]' .. ('='):rep(level) .. ']()'
   local str, next_i = self:match(patt)

   if not str then
      self:jump(self.len)
      self:error("unfinished long string")
   end

   self:jump(next_i)
   return str
end

local escapes = {
   a = '\a',
   b = '\b',
   f = '\f',
   n = '\n',
   r = '\r',
   t = '\t',
   v = '\v',
   ['\\'] = '\\',
   ['\''] = '\'',
   ['\"'] = '"'
}

function literal.Cursor:eval_short_string()
   self:assert(self:match '[\'"]', "short string expected")

   local quote = self.char
   local buf = buffer()

   self:step()
   local chunk_start = self.i
   while self.char ~= quote do
      self:assert(self:match '[^\r\n]', "unfinished string")

      if self.char == '\\' then
         -- Cut chunk
         buf:add(self.str:sub(chunk_start, self.i-1))

         -- Escape sequence
         self:step()
         self:assert(self.char ~= '', "unfinished string")

         if escapes[self.char] then
            -- Regular escape
            buf:add(escapes[self.char])
            self:step()
         elseif self:match '[\r\n]' then
            -- Must replace with \n
            buf:add('\n')
            self:skip_newline()
         elseif self:match '%d' then
            -- Decimal escape
            local start_i = self.i
            self:step()

            for j=2, 3 do
               if self:match '%d' then
                  self:step()
               end
            end

            -- i now points to first char not in escape
            local code_str = self.str:sub(start_i, self.i-1)
            local code = tonumber(code_str)
            self:assert(code and code < 256, "decimal escape too large", "'\\" .. code_str .. "'")
            buf:add(string.char(code))
         elseif self.grammar == "5.2" then
            -- Lua 5.2 things

            if self.char == 'z' then
               self:step() -- Skip z
               self:skip_space()
            elseif self.char == 'x' then
               -- Hexadecimal escape
               self:step() -- Skip x
               local code_str = self:assert(self:match '(%x%x)', "mailformed hexadecimal escape sequence")
               self:step(2)
               local code = self:assert(tonumber(code_str, 16), "mailformed hexadecimal escape sequence")
               buf:add(string.char(code))
            else
               self:invalid_escape()
            end
         else
            self:invalid_escape()
         end

         chunk_start = self.i
      else
         -- Regular char
         self:step()
      end
   end

   -- Add last chunk
   buf:add(self.str:sub(chunk_start, self.i-1))
   self:step()
   return buf:res()
end

function literal.Cursor:eval_sign()
   if self.char == '-' then
      self:step()
      return -1
   elseif self.char == '+' then
      self:step()
   end

   return 1
end

function literal.Cursor:eval_number()
   self:assert(self:match '[%+%-%.%x]', "numerical constant expected")
   local mul = self:eval_sign()
   local res

   if self:match '0[xX]' then
      -- Hexadecimal
      self:step(2)
      if self.grammar == "5.1" then
         -- Should be an integer
         local integer_str, next_i = self:match '(%x+)()'

         if not integer_str then
            self:error("mailformed hexadecimal constant")
         end

         res = self:assert(tonumber(integer_str, 16), "mailformed hexadecimal constant")
         self:jump(next_i)
      else
         local integer_str, next_i = self:match '(%x*)()'

         if not integer_str then
            self:error("mailformed hexadecimal constant")
         end

         local integer

         if integer_str == '' then
            integer = 0
         else
            integer = self:assert(tonumber(integer_str, 16), "mailformed hexadecimal constant")
         end

         self:jump(next_i)
         local fract = 0

         if self.char == '.' then
            self:step()
            local fract_str, next_i = self:match '(%x*)()'

            if not fract_str then
               self:error("mailformed hexadecimal constant")
            end

            self:jump(next_i)

            if fract_str == '' then
               self:assert(integer_str ~= '', "mailformed hexadecimal constant")
               fract = 0
            else
               fract = self:assert(tonumber(fract_str, 16), "mailformed hexadecimal constant")
               fract = fract / 16^fract_str:len()
            end
         end

         if self:match '[pP]' then
            self:step()

            local pow_mul = self:eval_sign()
            local pow_str, next_i = self:match '(%d+)()'

            if not pow_str then
               self:error("mailformed hexadecimal constant")
            end

            self:jump(next_i)
            local pow = self:assert(tonumber(pow_str), "mailformed hexadecimal constant")*pow_mul
            mul = mul * 2^pow
         end

         res = integer+fract
      end
   else
      -- Decimal
      local number, next_i = self:match '([%+%-%.%deE]+)()'

      if not number then
         self:error("mailformed decimal constant")
      end

      res = self:assert(tonumber(number), "mailformed decimal constant")
      self:jump(next_i)
   end

   return res*mul
end

local keywords = {
   ["and"] = true,
   ["break"] = true,
   ["do"] = true,
   ["else"] = true,
   ["elseif"] = true,
   ["end"] = true,
   ["false"] = true,
   ["for"] = true,
   ["function"] = true,
   ["if"] = true,
   ["in"] = true,
   ["local"] = true,
   ["nil"] = true,
   ["not"] = true,
   ["or"] = true,
   ["repeat"] = true,
   ["return"] = true,
   ["then"] = true,
   ["true"] = true,
   ["until"] = true,
   ["while"] = true
}

function literal.Cursor:eval_table()
   self:assert(self.char == '{', "table literal expected")
   local t = {}
   local n = 0
   local k, v
   local key_value
   local line_start = self.line
   self:step()

   while true do
      self:skip_space_and_comments()
      key_value = false

      if self.char == '}' then
         self:step()
         return t
      elseif self.char == '[' then
         if not self:match '%[=*%[' then
            key_value = true
            self:step()
            self:skip_space_and_comments()
            k = self:eval()
            self:skip_space_and_comments()
            self:assert(self.char == ']', "']' expected")
            self:step()
         end
      elseif self:match '[_%a][_%a%d]*%s*=' then
         key_value = true
         k = self:match '([_%a][_%a%d]*)'

         if keywords[k] or self.grammar == "5.2" and k == "goto" then
            self:error("unexpected symbol")
         end

         self:step(k:len())
      end

      if key_value then
         self:skip_space_and_comments()
         self:assert(self.char == '=', "'=' expected")
         self:step()
         self:skip_space_and_comments()
         v = self:eval()
         self:assert(k ~= nil, "table index is nil")
         t[k] = v
      else
         v = self:eval()
         n = n+1
         t[n] = v
      end

      self:skip_space_and_comments()
      if self:match '[,;]' then
         self:step()
      else
         self:assert(self.char == '}', ("'}' expected (to close '{' at line %d)"):format(line_start))
      end
   end
end

local literals = {
   ["nil"] = {nil},
   ["true"] = {true},
   ["false"] = {false}
}

function literal.Cursor:eval()
   for lit, val in pairs(literals) do
      if self:match(lit) then
         self:step(lit:len())
         return val[1]
      end
   end

   if self:match '[\'"]' then
      return self:eval_short_string()
   elseif self:match '%[=*%[' then
      return self:eval_long_string()
   elseif self:match '[%+%-%d]' then
      return self:eval_number()
   elseif self.char == '{' then
      return self:eval_table()
   else
      self:error("literal expected")
   end
end


--- Main evaluation function. 
--
-- Tries to evaluate a given string as a Lua literal. 
-- Correct literals are "nil", "true", "false", decimal and hexadecimal numerical constants, short and long strings, and tables of other literals. 
--
-- Comments are considered whitespace. 
-- Non-whitespace after a correct literal is an error. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=nil|boolean|number|string|table] Result of evaluation. 
function literal.eval(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res = cur:eval()
   cur:finish()
   return res
end

---Only evaluates short literal strings. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=string] Result of evaluation. 
-- @see eval
function literal.eval_short_string(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res = cur:eval_short_string()
   cur:finish()
   return res
end

--- Only evaluates long literal strings. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=string] Result of evaluation. 
-- @see eval
function literal.eval_long_string(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res = cur:eval_long_string()
   cur:finish()
   return res
end

--- Only evaluates literal strings. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=string] Result of evaluation. 
-- @see eval
function literal.eval_string(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res

   if cur:match '[\'"]' then
      res = cur:eval_short_string()
   elseif cur:match '%[=*%[' then
      res = cur:eval_long_string()
   else 
      self:error("string expected")
   end

   cur:finish()
   return res
end

--- Only evaluates numerical constants. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=number] Result of evaluation. 
-- @see eval
function literal.eval_number(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res = cur:eval_number()
   cur:finish()
   return res
end

--- Only evaluates literal tables. 
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=table] Result of evaluation. 
-- @see eval
function literal.eval_table(str, grammar, filename)
   local cur = literal.Cursor(str, grammar, filename)
   cur:skip_space_and_comments()
   local res = cur:eval_table()
   cur:finish()
   return res
end

return literal
