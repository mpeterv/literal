local literal = require "literal"
local serpent = require "serpent"

local function random_var(is_key, deep)
   local key = math.random(1000)

   if key <= 100 then
      if is_key then
         return 0
      else
         return nil
      end
   elseif key <= 200 then
      return false
   elseif key <= 300 then
      return true
   elseif key <= 600 then
      return math.random(-1e6, 1e6)
   elseif key <= 900 then
      local len = math.random(0, 100)
      local res = {}

      for i=1, len do
         table.insert(res, string.char(math.random(0, 255)))
      end

      return table.concat(res)
   else
      if deep > 3 or is_key then
         return 0
      else
         local len = math.random(0, 10)
         local res = {}

         for i=1, len do
            if math.random(0, 1) == 0 then
               table.insert(res, random_var(false, deep+1))
            else
               res[random_var(true, deep+1)] = random_var(false, deep+1)
            end
         end

         return res
      end
   end
end

describe("randomized test", function()
   it("evaluates literals produced by serpent", function()
      math.randomseed(os.time())

      for i=1, 100 do
         local x = random_var(false, 0)
         local s = serpent.block(x, {sortkeys = false})
         local x2 = literal.eval(s)
         assert.same(x, x2)
      end
   end)
end)
