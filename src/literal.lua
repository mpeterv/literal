--- A library for safe evaluation of Lua literal expressions. 
-- @module literal
-- @license Public Domain
-- @author Peter Melnichenko
local literal = {}

local class = require "30log"

--- Default grammar to be used by evaluation functions. Set to the version of Lua used to run the module. 
literal.grammar = _VERSION:find "5.2" and "5.2" or "5.1"

--- Maximum nesting level of table literals. Default is 200. 
literal.max_nesting = 200

--- Maximum length of string representation in error messages. Default is 45. 
literal.max_repr_length = 45

literal.Cursor = class()

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
      self.repr = self:match "([ %p%d%a]*)"

      if self.repr:len() > literal.max_repr_length or self.repr:len() ~= str:len() then
         self.repr = self.repr:sub(1, literal.max_repr_length) .. "..."
      end

      self.repr = ('[string "%s"]'):format(self.repr)
   end

   -- Is current char the first half of two-chars newline?
   if self:match "\r\n" or self:match "\n\r" then
      self.bound = true
   else
      self.bound = false
   end
end

function literal.Cursor:errormsg(msg, chunk)
   local line = self.line

   if not chunk then
      self:skip_space_and_comments()
      chunk = self:match "([^%s%c]+)"

      if chunk then
         chunk = "'" .. chunk .. "'"
      elseif self:match "%c" then
         chunk = "char(" .. self.char:byte() .. ")"
      else
         chunk = "<eof>"
      end
   end

   self.errmsg = ("%s:%d: %s near %s"):format(self.repr, line, msg, chunk)
   return self.errmsg
end

function literal.Cursor:error(msg, chunk)
   error(self:errormsg(msg, chunk))
end

function literal.Cursor:assert(assertion, msg, chunk)
   return assertion or self:error(msg, chunk)
end

function literal.Cursor:invalid_escape()
   self:error("invalid escape sequence", "'\\" .. self:match "(%C?)" .. "'")
end

-- Can only jump forward
function literal.Cursor:jump(i)
   assert(i <= self.len)
   local cur_newline, new_i, old_i

   while self.i < i do
      new_i = self:find "[\r\n]"

      if not new_i or new_i > i then
         new_i = i
      end

      if self:match "[\r\n]" then
         if not self.bound then
            self.line = self.line+1
         end
      end

      old_i, self.i = self.i, new_i

      if self:match "\r\n" or self:match "\n\r" then
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
   return self.str:match("^" .. pattern, self.i)
end

function literal.Cursor:skip_newline()
   self:step(self.bound and 2)
end

function literal.Cursor:skip_space()
   return self:jump(self:match "%s*()")
end

function literal.Cursor:skip_space_and_comments()
   while true do
      self:skip_space()

      if self:match "%-%-" then
         -- Comment
         self:step(2)

         if self:match "%[=*%[" then
            -- Long comment
            self:eval_long_string()
         else
            -- Short comment
            self:jump(self:match "[^\r\n]*()")
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
   local errmsg = self:errormsg("unfinished long string")
   local second_opening_bracket = self:assert(self:match "%[=*()%[", "long string expected")

   local level = second_opening_bracket-self.i-1
   self:jump(second_opening_bracket+1)

   if self:match "[\r\n]" then
      self:skip_newline()
   end

   local patt = "(.-)]" .. ("="):rep(level) .. "]()"
   local str, next_i = self:match(patt)

   if not str then
      error(errmsg)
   end

   self:jump(next_i)
   return str
end

local escapes = {
   a = "\a",
   b = "\b",
   f = "\f",
   n = "\n",
   r = "\r",
   t = "\t",
   v = "\v",
   ["\\"] = "\\",
   ["'"] = "'",
   ['"'] = '"'
}

function literal.Cursor:eval_short_string()
   self:assert(self:match "['\"]", "short string expected")
   local quote = self.char
   local errmsg = self:errormsg("unfinished string")
   local buf = {}
   self:step()
   local chunk_start = self.i

   while self.char ~= quote do
      if not self:match "[^\r\n]" then
         error(errmsg)
      end

      if self.char == "\\" then
         -- Escape sequence
         -- Cut chunk
         table.insert(buf, self.str:sub(chunk_start, self.i-1))
         self:step()

         if self.char == "" then
            error(errmsg)
         end

         if escapes[self.char] then
            -- Regular escape
            table.insert(buf, escapes[self.char])
            self:step()
         elseif self:match "[\r\n]" then
            -- Must replace with \n
            table.insert(buf, "\n")
            self:skip_newline()
         elseif self:match "%d" then
            -- Decimal escape
            local start_i = self.i
            self:step()

            for j=2, 3 do
               if self:match "%d" then
                  self:step()
               end
            end

            -- i now points to first char not in escape
            local code_str = self.str:sub(start_i, self.i-1)
            local code = tonumber(code_str)
            self:assert(code and code < 256, "decimal escape too large", "'\\" .. code_str .. "'")
            table.insert(buf, string.char(code))
         elseif self.grammar == "5.2" then
            -- Lua 5.2 things

            if self.char == "z" then
               self:step() -- Skip z
               self:skip_space()
            elseif self.char == "x" then
               -- Hexadecimal escape
               self:step() -- Skip x
               local code_str = self.str:sub(self.i, self.i+1)
               self:assert(code_str:match "(%x%x)",
                  "hexadecimal digit expected", "'\\x" .. code_str:match "([^%s%c]*)" .. "'")
               self:step(2)
               local code = tonumber(code_str, 16)
               table.insert(buf, string.char(code))
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
   table.insert(buf, self.str:sub(chunk_start, self.i-1))
   self:step()
   return table.concat(buf)
end

function literal.Cursor:eval_sign()
   if self.char == "-" then
      self:step()
      return -1
   elseif self.char == "+" then
      self:step()
   end

   return 1
end

function literal.Cursor:eval_number()
   self:assert(self:match "[%+%-%.%x]", "numerical constant expected")
   local mul = self:eval_sign()
   local res

   if self:match "0[xX]" then
      -- Hexadecimal
      self:step(2)
      if self.grammar == "5.1" then
         -- Should be an integer
         local integer_str = self:assert(self:match "(%x+)", "malformed number")
         res = self:assert(tonumber(integer_str, 16), "malformed number")
         self:step(integer_str:len())
      else
         local integer_str = self:assert(self:match "(%x*)", "malformed number")
         local integer

         if integer_str == "" then
            integer = 0
         else
            integer = self:assert(tonumber(integer_str, 16), "malformed number")
         end

         self:step(integer_str:len())
         local fract = 0

         if self.char == "." then
            self:step()
            local fract_str = self:assert(self:match "(%x*)", "malformed number")

            if fract_str == "" then
               self:assert(integer_str ~= "", "malformed number")
               fract = 0
            else
               fract = self:assert(tonumber(fract_str, 16), "malformed number")
               fract = fract / 16^fract_str:len()
            end

            self:step(fract_str:len())
         end

         if self:match "[pP]" then
            self:step()
            local pow_mul = self:eval_sign()
            local pow_str = self:assert(self:match "(%d+)", "malformed number")
            local pow = self:assert(tonumber(pow_str), "malformed number")*pow_mul
            mul = mul * 2^pow
            self:step(pow_str:len())
         end

         res = integer+fract
      end
   else
      -- Decimal
      local number_str = self:assert(self:match "([%+%-%.%deE]+)", "malformed number")
      res = self:assert(tonumber(number_str), "malformed number")
      self:step(number_str:len())
   end

   local number = res*mul

   if number ~= number then
      return 0
   else
      return number
   end
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

local literals = {
   ["nil"] = {nil},
   ["true"] = {true},
   ["false"] = {false}
}

function literal.Cursor:eval_table(nesting)
   nesting = (nesting or 0)+1
   self:assert(nesting <= literal.max_nesting, "table is too deep")
   self:assert(self.char == "{", "table literal expected")
   local t = {}
   local n = 0
   local k, v
   local key_value
   local start_line = self.line
   self:step()

   while true do
      self:skip_space_and_comments()
      key_value = false

      if self.char == "}" then
         self:step()
         return t
      elseif self.char == "[" then
         if not self:match "%[=*%[" then
            self:step()
            self:skip_space_and_comments()
            k = self:eval_literal(nesting)
            self:assert(k ~= nil, "table index is nil")
            self:skip_space_and_comments()
            self:assert(self.char == "]", "']' expected")
            self:step()
            key_value = true
         end
      elseif self:match "[_%a][_%a%d]*" then
         k = self:match "([_%a][_%a%d]*)"

         if not literals[k] then
            if keywords[k] or self.grammar == "5.2" and k == "goto" then
               self:error("unexpected symbol")
            end

            self:step(k:len())
            key_value = true
         end
      end

      if key_value then
         self:skip_space_and_comments()
         self:assert(self.char == "=", "'=' expected")
         self:step()
         self:skip_space_and_comments()
         v = self:eval_literal(nesting)
         t[k] = v
      else
         v = self:eval_literal(nesting)
         n = n+1
         t[n] = v
      end

      self:skip_space_and_comments()

      if self:match "[,;]" then
         self:step()
      else
         local msg = "'}' expected"

         if self.line ~= start_line then
            msg = msg .. " (to close '{' at line " .. start_line .. ")"
         end

         self:assert(self.char == "}", msg)
      end
   end
end

function literal.Cursor:eval_literal(nesting)
   for lit, val in pairs(literals) do
      if self:match(lit) then
         self:step(lit:len())
         return val[1]
      end
   end

   if self:match "['\"]" then
      return self:eval_short_string()
   elseif self:match "%[=*%[" then
      return self:eval_long_string()
   elseif self:match "[%.%+%-%d]" then
      return self:eval_number()
   elseif self.char == "{" then
      return self:eval_table(nesting)
   else
      self:error("literal expected")
   end
end

function literal.Cursor:eval()
   self:skip_space_and_comments()
   local res = self:eval_literal()
   self:finish()
   return res
end

function literal.Cursor:eval_config()
   local t = {}
   local k, v

   while self.i < self.len do
      self:skip_space_and_comments()
      k = self:assert(self:match "([_%a][_%a%d]*)", "unexpected symbol")
      self:step(k:len())
      self:skip_space_and_comments()
      self:assert(self.char == "=", "'=' expected")
      self:step()
      self:skip_space_and_comments()
      v = self:eval_literal(1)
      self:skip_space_and_comments()

      if self.char == ";" then
         self:step()
      end

      t[k] = v
   end

   return t
end

--- Tries to evaluate a given string as a Lua literal. 
-- Correct literals are "nil", "true", "false", decimal and hexadecimal numerical constants, short and long strings, and tables of other literals. 
--
-- Comments are considered whitespace. 
-- Non-whitespace after a correct literal is an error. 
--
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=nil|boolean|number|string|table] Result of evaluation. 
function literal.eval(str, grammar, filename)
   assert(type(str) == "string", ("bad argument #1 to 'eval' (string expected, got %s)"):format(type(str)))
   return literal.Cursor(str, grammar, filename):eval()
end

--- Protected version of @{eval}. 
-- Acts as @{eval}, but instead of raising errors returns false and error message. 
--
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @return[type=boolean] True if there were no errors, false otherwise. 
-- @return[type=nil|boolean|number|string|table] Result of evaluation or error message. 
function literal.peval(str, grammar, filename)
   assert(type(str) == "string", ("bad argument #1 to 'peval' (string expected, got %s)"):format(type(str)))
   local cur = literal.Cursor(str, grammar, filename)
   local ok, result = pcall(cur.eval, cur)

   if not ok then
      result = cur.errmsg
   end

   return ok, result
end

--- Tries to evaluate a given string as a config file. 
-- Config is a string consisting of pairs "&lt;string&gt; = &lt;literal&gt;", separated by whitespace and optional semicolons. 
-- &lt;string&gt; must be a valid Lua name or keyword. 
-- Config is interpreted as a table with these strings as keys and corresponding literals as values. 
--
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @raise Errors similar to those of Lua compiler. 
-- @return[type=table] Result of evaluation. 
function literal.eval_config(str, grammar, filename)
   assert(type(str) == "string", ("bad argument #1 to 'eval_config' (string expected, got %s)"):format(type(str)))
   return literal.Cursor(str, grammar, filename):eval_config()
end

--- Protected version of @{eval_config}. 
-- Acts as @{eval_config}, but instead of raising errors returns false and error message. 
--
-- @string str the string. 
-- @string[opt] grammar the grammar to be used. Must be either "5.1" or "5.2". Default grammar is the grammar of Lua version used to run the module. 
-- @string[opt] filename the filename to be used in error messages. 
-- @return[type=boolean] True if there were no errors, false otherwise. 
-- @return[type=string|table] Result of evaluation or error message. 
function literal.peval_config(str, grammar, filename)
   assert(type(str) == "string", ("bad argument #1 to 'peval_config' (string expected, got %s)"):format(type(str)))
   local cur = literal.Cursor(str, grammar, filename)
   local ok, result = pcall(cur.eval_config, cur)

   if not ok then
      result = cur.errmsg
   end

   return ok, result
end

return literal
