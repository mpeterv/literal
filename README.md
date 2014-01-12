# literal

[![Build Status](https://travis-ci.org/mpeterv/literal.png?branch=master)](https://travis-ci.org/mpeterv/literal)

__literal__ is a library for safe evaluation of Lua literal expressions, written in pure Lua. It can evaluate literals like `nil`, `true`, `false`, decimal and hexadecimal numerical constants, short and long strings, and tables of other literals. It can use grammar of Lua 5.1 or Lua 5.2, and provides error messages similar to those of Lua compiler. 

## Contents

* [Usage](#usage)
* [Documentation](#documentation)
* [Installation](#installation)
* [Testing](#testing)
* [License](#license)

## Usage

### Importing

This works:

```lua
local literal = require "literal"
```

This doesn't work:

```lua
require "literal"
```

### Evaluating

Evaluate strings using `literal.eval` function. Pass a string as the first argument. 

```lua
local s = [[
{
	foo = "bar", -- Comments are skipped
	true,
	[0xFFA] = [=[baz]=]
}

-- Whitespace and comments before and after literal are discarded as well
]]

local t = literal.eval(s)
print(t.foo) -- bar
print(t[1]) -- true
print(t[4090]) -- baz
```

`literal.eval` raises an error if the string is not a valid literal. 

```lua
local s = [[
{
   foo = "bar"
]]

local t = literal.eval(s)
-- Raises: [string "{..."]:3: '}' expected (to close '{' at line 1) near <eof>
```

`literal.eval` takes two optional arguments. The first one should be a string `5.1` or `5.2` and specifies which grammar will be used. By default, it is the grammar of the Lua version used to run __literal__. 

```lua
local s = "0x1p1"
print(literal.eval(s, "5.2")) -- 2
literal.eval(s, "5.1")
-- Raises: [string "0x1p1"]:1: <eof> expected near 'p1'
```

The second optional argument sets the filename to be used in error messages. 

```lua
local s = "0x1p1"
literal.eval(s, "5.1", "test.lua")
-- Raises: test.lua:1: <eof> expected near 'p1'
```

### Evaluating configuration files

It is common to use Lua scripts as configuration files. Usually such files consist of several assignments in form `name` = `expression`. In this case, it is possible to load configuration using `literal.eval_config`. 

```lua
local s = [[
foo = "bar"
names = {"Alice", "Bob"}

-- comments are allowed
enable_magic = true
]]

local config = literal.eval_config(s)
print(config.foo) -- bar
print(config.names[1] .. ", " .. config.names[2]) -- Alice, Bob
print(config.enable_magic and "Magic" or "No magic :(") -- Magic
```

### Getting error message

`literal.eval` and `literal.eval_config` raise an error if the passed string is not valid. The error message can be extracted using `pcall`, but it will be automatically prepended with information about where the error was raised. 

To avoid this, use `literal.peval` and `literal.peval_config`, which return a boolean flag indicating success of evaluation and the result or error message. 

For more information, see [documentation](https://mpeterv.github.io/literal). 

## Documentation

[LDoc](http://stevedonovan.github.io/ldoc/) generated documentation is available in `doc` directory. It can be viewed online [here](https://mpeterv.github.io/literal). 

## Installation

### Using luarocks

Installing __literal__ using luarocks is easy. 

```bash
luarocks install literal
```

#### Problem with old luarocks versions

You may get an error like `Parse error processing dependency '30log >= 0.7'` if you use __luarocks__ 2.1 or older. In this case, either upgrade to at least __luarocks__ 2.1.1 or install [30log](http://yonaba.github.io/30log/) manually, then download the rockspec for __literal__, remove the line `"30log >= 0.7"` and run

```bash
luarocks install /path/to/literal/rockspec
```

### Without luarocks

Download `/src/literal.lua` file and put it into the directory for libraries or your working directory. Install __30log__ using __luarocks__ or manually download `30log.lua` file from [30log repo](https://github.com/Yonaba/30log). 

## Testing

__literal__ comes with a testing suite located in `spec` directory. The requirements for testing are [busted](http://olivinelabs.com/busted/) and [serpent](https://github.com/pkulchenko/serpent), both can be installed using __luarocks__. The command for running tests is

```bash
busted path/to/spec/directory
```

## License

__literal__ is public domain. See `LICENSE` file. 
