# Alloverse visor (Lua edition)

Allovisor is the "user interface" into the Alloverse. Use this Lovr app to connect to an Alloverse Place' and interact with the apps available in that place.

We [first tried to build the Alloverse visor in Unity](https://github.com/alloverse/allovisor-unity),
but have decided to switch to Lovr because it's easier and faster to develop
with, and easier to extend with low level functionality.

## Developing Allovisor

### Mac

#### Xcode project

1. Install CMake 3.13.0 or newer
2. `mkdir build && cd build && cmake -GXcode ..` to prepare to build
3. `open build/allovisor.xcodeproj`
4. Build the **ALL_BUILD** target
5. Switch to the **lovr** target
6. Open the scheme editor and add these launch arguments. 
  - `${PROJECT_DIR}/deps/lodr`
  - `${PROJECT_DIR}/lua`
7. Run the **lovr** target

#### make

1. Install CMake 3.13.0 or newer
2. `mkdir build && cd build && cmake ..` to prepare to build
3. In build, `make alloverse-dist` to build `Alloverse.app`.
4. You could now just double-click Alloverse.app, but then you'd need to recompile
   for each change. Instead, you can start it from the command line together with
   lodr to auto-reload whenever you change any lua source file. From `build`:

`./Alloverse.app/Contents/MacOS/lovr ../deps/lodr ../lua`

You could also `make allonet` and use the regular Lovr visor like below. (It's not
recommended, as you wouldn't get any Alloverse-specific Lovr app patches, and things
might not work as expected.) cpath is set up to find
`liballonet.so` in `build` next to `lua`. Run it from the project root like so:

`/Applications/LÖVR.app/Contents/MacOS/lovr deps/lodr lua`

### Windows

1. Install Visual Studio 2019, including "C++ CMake tools for Windows" which comes with "Desktop development with C++".
2. Open the project folder in VS2019
3. In the Solution Explorer, right-click CMakeLists.txt and select "Generate CMake cache for allovisor"
4. Build and run the Alloverse.exe target

Lua code is zipped and attached to the end of the exe as a post-build step. This means Lua changes aren't
visible until you rebuild the target. To get automatic hot-reloading so you don't even have to relaunch
Alloverse.exe to see your changes, you can launch Alloverse with Lodr.

Either cd to `out/build/x64-debug` and `Alloverse.exe ../../../deps/lodr ../../../lua`, or set it up
in Visual Studio by right-clicking the target and changing "Debug and Launch settings" and adding
absolute paths to lodr and lua that work on your computer to the ALloverse target, something like this:

```
    {
      "type": "default",
      "project": "CMakeLists.txt",
      "projectTarget": "Alloverse.exe",
      "name": "Alloverse.exe",
      "args": [
        "C:\\Users\\nevyn\\Dev\\allovisor-lovr\\deps\\lodr",
        "C:\\Users\\nevyn\\Dev\\allovisor-lovr\\lua"
      ]
    }
```

### Oculus Quest, with hard-linked allonet, from a Mac

1. Install CMake version 3.15.4 exactly
2. Install Android Studio if you haven't already.
3. [Enable developer mode on your Quest](https://developer.oculus.com/documentation/quest/latest/concepts/mobile-device-setup-quest/).
4. Connect it to your computer, and ensure it shows up when you run `adb devices` in your terminal.
5. Configure to build the alloverse.apk: `mkdir android-build; cd android-build; cmake -DCMAKE_TOOLCHAIN_FILE=~/Library/Android/sdk/ndk-bundle/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a ..`
6. Actually build it: `make alloverse-dist`
7. Upload to headset: `adb install alloverse-debug.apk`

If you are iterating on the native code parts, you can re-build and upload the api with this handy one-liner
from the `build` directory:

`cmake -DCMAKE_TOOLCHAIN_FILE=~/Library/Android/sdk/ndk-bundle/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a ..; and rm -rf *.apk; and make alloverse-dist; and adb uninstall com.alloverse.visor; and adb install alloverse-release.apk`

Note that this command deletes apks on disk (because the cmake integration is iffy and it doesn't know
to rebuild unless the apk is missing), and deletes from device (because I haven't worked out keychain yet
so each build gets a new signature).

If you are iterating on the lua code parts, it would be nice to upload just the lua files and
lodr could override the bundled sources to give the changes to you immediately, without even
having to restart the app on your Quest. If that had worked, you'd sync your source files like so:

`adb push --sync lua /sdcard/Android/data/com.alloverse.visor/files/.lodr`

... but that's waiting [for a card on clubhouse](https://app.clubhouse.io/alloverse/story/168/get-lodr-to-work-on-android-for-custom-alloverse-debug-apk)
to finish before it's possible.

## Building Allovisor for distribution

_Note that builds are available on Azure Pipelines CI and you shouldn't need to make distribution builds from your machine. But if you do..._

This will compile Lovr, Allonet and build a nice little package to be distributed
for Mac, Windows or Android.

1. Install CMake 3.13.0 or newer
2. `mkdir build && cd build && cmake ..`

### Mac

- `make alloverse-dist`
- You now have an `Alloverse.app` in the build folder.

### Windows

1. Install Visual Studio 2019, including "C++ CMake tools for Windows" which comes with "Desktop development with C++".
2. Open the project folder in VS2019
3. In the Solution Explorer, right-click CMakeLists.txt and select "Generate CMake cache for allovisor"
4. Switch to the [targets view](https://docs.microsoft.com/en-us/cpp/build/cmake-projects-in-visual-studio?view=vs-2019#ide-integration)
5. Build the target `alloverse-dist`.

Tada. You now have an `Alloverse` folder and zip file in `out/build/x64-Debug`.

## Quest/Android (from a Mac)

1. `mkdir build && cd build && cmake -DCMAKE_TOOLCHAIN_FILE=~/Library/Android/sdk/ndk-bundle/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a ..`
2. `make alloverse-dist`
3. You now have an `alloverse-debug.apk` and `alloverse-release.apk` in your build folder
