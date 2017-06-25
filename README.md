# hslua examples – using the Lua interface for Haskell

To use system-wide installed Lua/LuaJIT when linking hslua as a dependency,
build/install your package using `--constraint="hslua +system-lua"` or for
LuaJIT: `--constraint="hslua +system-lua +luajit"`. For example, you can install
these examples with hslua that uses system-wide LuaJIT like this:

```
cabal install hslua-examples --constraint="hslua +system-lua +luajit"
```
