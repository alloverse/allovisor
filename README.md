# Alloverse visor (Lua edition)

Allovisor is the "user interface" into the Alloverse. Use this Lovr app to connect to an Alloverse Place' and interact with the apps available in that place.

We [first tried to build the Alloverse visor](https://github.com/alloverse/allovisor)
in Unity, but have decided to switch to Lovr because it's easier and faster to develop
with, and easier to extend with low level functionality.

## Developing Allovisor

1. Install Lövr 0.13 or later
2. Start Lövr with the `lua` folder as the Lövr app, and optionally add `deps/lodr` too for auto-reload.

Mac + fish: `/Applications/LÖVR.app/Contents/MacOS/lovr (pwd)/deps/lodr (pwd)/lua`
Mac + bash: `/Applications/LÖVR.app/Contents/MacOS/lovr $(pwd)/deps/lodr $(pwd)/lua`

