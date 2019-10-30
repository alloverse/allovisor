cmake_minimum_required(VERSION 3.1.0)
project(allovisor VERSION 0.2.0)

SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
SET(LOVR_ENABLE_ENET OFF CACHE BOOL "Disable Lovr enet since allonet embeds its own")
add_subdirectory (deps/lovr)

add_subdirectory (deps/allonet)

if(WIN32) # windows unsupported atm

elseif(APPLE)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.app
        COMMAND cp -r ${CMAKE_CURRENT_BINARY_DIR}/deps/lovr/lovr.app ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.app
        COMMAND cp -r ${CMAKE_CURRENT_SOURCE_DIR}/lua Alloverse.app/Contents/Resources/.lovr
        COMMAND cp -r ${CMAKE_CURRENT_BINARY_DIR}/deps/allonet/liballonet.dylib Alloverse.app/Contents/Resources/.lovr/liballonet.so
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/Info.plist Alloverse.app/Contents/Info.plist
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/alloverse.icns Alloverse.app/Contents/Resources/alloverse.icns
        COMMAND rm ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.app/Contents/Resources/lovr.icns
        COMMAND zip ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.zip -r Alloverse.app
        DEPENDS lovr allonet
    )
    add_custom_target(
        alloverse-dist ALL
        DEPENDS Alloverse.app
    )
elseif(ANDROID)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/alloverse-release.apk
        COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/build-android.sh build
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/deps/lovr-android/LovrApp/Projects/Android/build/outputs/apk/debug/alloverse-debug.apk .
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/deps/lovr-android/LovrApp/Projects/Android/build/outputs/apk/release/alloverse-release.apk .
    )
    add_custom_target(
        alloverse-dist ALL
        DEPENDS alloverse-release.apk
    )

elseif(UNIX) # linux unsupported atm

endif()