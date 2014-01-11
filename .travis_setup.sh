# A script for setting up environment for travis-ci testing. 
# Sets up Lua and Luarocks. 
# LUA must be "Lua 5.1", "Lua 5.2" or "LuaJIT 2.0". 

case $LUA in
  "Lua 5.1")
    LUA_URL="http://www.lua.org/ftp/lua-5.1.5.tar.gz"
    LUA_DIR="lua-5.1.5"
    LUA_BUILD_COMMAND="sudo make linux install"
  ;;
  "Lua 5.2")
    LUA_URL="http://www.lua.org/ftp/lua-5.2.3.tar.gz"
    LUA_DIR="lua-5.2.3"
    LUA_BUILD_COMMAND="sudo make linux install"
  ;;
  "LuaJIT 2.0")
    LUA_URL="http://luajit.org/download/LuaJIT-2.0.2.tar.gz"
    LUA_DIR="LuaJIT-2.0.2"
    LUA_BUILD_COMMAND="make && sudo make install"
  ;;
esac

LUAROCKS_URL="http://luarocks.org/releases/luarocks-2.1.1.tar.gz"
LUAROCKS_DIR="luarocks-2.1.1"
LUAROCKS_BUILD_COMMAND="./configure && make && sudo make install"

# Install Lua
curl $LUA_URL | tar xz
cd $LUA_DIR
eval $LUA_BUILD_COMMAND
cd ..

# Install Luarocks
curl $LUAROCKS_URL | tar xz
cd $LUAROCKS_DIR
eval $LUAROCKS_BUILD_COMMAND
cd ..

# Done!
