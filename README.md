# Alloverse visor (Lua edition)

Allovisor is the "user interface" into the Alloverse. Use this Lovr app to connect to an Alloverse Place' and interact with the apps available in that place.

We [first tried to build the Alloverse visor](https://github.com/alloverse/allovisor)
in Unity, but have decided to switch to Lovr because it's easier and faster to develop
with, and easier to extend with low level functionality.

## Developing Allovisor

1. Install CMake 3.13.0 or newer
2. Install Lövr 0.13 or later (or follow the distribution instructions to use the embedded version)
3. `mkdir build && cd build && cmake ..` to prepare to build liballonet
4. In build, `make allonet && cp allonet/liballonet.dylib ../lua/liballonet.so` to build liballonet
   and put it in place to be used from lua
5. Start Lövr with the `lua` folder as the Lövr app, and optionally add `deps/lodr` too for auto-reload.

Mac + fish: `/Applications/LÖVR.app/Contents/MacOS/lovr (pwd)/deps/lodr (pwd)/lua`
Mac + bash: `/Applications/LÖVR.app/Contents/MacOS/lovr $(pwd)/deps/lodr $(pwd)/lua`

## Building Allovisor for distribution

This will compile Lovr, Allonet and build a nice little package to be distributed
for Mac, Windows or Android.

1. Install CMake 3.13.0 or newer
2. `mkdir build && cd build && cmake ..`

### Mac

* `make allovisor-mac`

### Windows

todo

## Quest/Android

todo