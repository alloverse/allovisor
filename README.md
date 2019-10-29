# Alloverse visor (Lua edition)

Allovisor is the "user interface" into the Alloverse. Use this Lovr app to connect to an Alloverse Place' and interact with the apps available in that place.

We [first tried to build the Alloverse visor](https://github.com/alloverse/allovisor)
in Unity, but have decided to switch to Lovr because it's easier and faster to develop
with, and easier to extend with low level functionality.

## Developing Allovisor

### Mac

1. Install CMake 3.13.0 or newer
2. Install Lövr 0.13 or later (or follow the distribution instructions to use the embedded version)
3. `mkdir build && cd build && cmake ..` to prepare to build liballonet
4. In build, `make allonet && cp allonet/liballonet.dylib ../lua/liballonet.so` to build liballonet
   and put it in place to be used from lua
5. Start Lövr with the `lua` folder as the Lövr app, and optionally add `deps/lodr` too for auto-reload.

fish: `/Applications/LÖVR.app/Contents/MacOS/lovr (pwd)/deps/lodr (pwd)/lua`
bash: `/Applications/LÖVR.app/Contents/MacOS/lovr $(pwd)/deps/lodr $(pwd)/lua`


### Windows

TBD

### Oculus Quest (from a Mac)

To acquire `liballonet.so` for Android, either
[download it from Azure Pipelines](https://github.com/alloverse/allonet#download-allonet), or build
it as per [the instructions in the allonet readme](https://github.com/alloverse/allonet#developing-for-android).
Then copy it into the root of the `lua` folder.

Then, you can [sideload the Lövr test app](https://lovr.org/docs/Getting_Started_(Android))
and run Alloverse visor inside it:

1. Install Android Studio if you haven't already.
2. [Enable developer mode on your Quest](https://developer.oculus.com/documentation/quest/latest/concepts/mobile-device-setup-quest/).
3. Connect it to your computer, and ensure it shows up when you run `adb devices` in your terminal.
4. Download `test-debug.apk` from [the lovr-oculus-mobile repo](https://github.com/mcclure/lovr-oculus-mobile/releases)
5. Install it: `adb install ~/Downloads/test-debug.apk`
6. `cd` to the root of this project (to the folder of this readme)
7. Sync the Alloverse visor app onto your quest to be used by test-debug.apk:
   `adb push --sync lua /sdcard/Android/data/org.lovr.test/files/.lodr`

Whenever you make changes to any part of the app, you can re-run step 7 to sync the changes
over, and they'll reload immediately.

## Building Allovisor for distribution

This will compile Lovr, Allonet and build a nice little package to be distributed
for Mac, Windows or Android.

1. Install CMake 3.13.0 or newer
2. `mkdir build && cd build && cmake ..`

### Mac

* `make alloverse-dist`
* You now have an `Alloverse.app` in the build folder.

### Windows

todo

## Quest/Android

todo