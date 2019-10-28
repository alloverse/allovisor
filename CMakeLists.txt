cmake_minimum_required(VERSION 3.1.0)
project(allovisor VERSION 0.2.0)

SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
add_subdirectory (deps/lovr)

if(WIN32)

elseif(APPLE)
    add_custom_command(
        OUTPUT Alloverse.app
        COMMAND cp -r deps/lovr/lovr.app Alloverse.app
        COMMAND cp -r ${CMAKE_CURRENT_SOURCE_DIR}/lua Alloverse.app/Contents/Resources/.lovr
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/Info.plist Alloverse.app/Contents/Info.plist
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/alloverse.icns Alloverse.app/Contents/Resources/alloverse.icns
        COMMAND rm Alloverse.app/Contents/Resources/lovr.icns
        MAIN_DEPENDENCY deps/lovr/lovr.app
    )
    add_custom_target(
        alloverse-dist ALL
        DEPENDS Alloverse.app
    )
elseif(ANDROID)

elseif(UNIX) # linux unsupported atm

endif()