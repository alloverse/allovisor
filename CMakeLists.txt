cmake_minimum_required(VERSION 3.13.0) # 3.13 minimum for CMP0079
project(allovisor VERSION 0.2.0)
cmake_policy(SET CMP0079 NEW)

SET(LOVR_BUILD_SHARED ON CACHE BOOL "Always build lovr as library")
SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
SET(LOVR_ENABLE_ENET OFF CACHE BOOL "Disable Lovr enet since allonet embeds its own")
set(ALLONET_USE_LUA ON CACHE BOOL "Request Lua bridge")
set(ALLONET_BUILD_STATIC ON CACHE BOOL "Always build allonet static")
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON CACHE BOOL "always export all symbols")

add_subdirectory (deps/lovr)
add_subdirectory (deps/allonet)

if(WIN32)
    target_link_libraries(lovr allonet)
    add_executable (Alloverse src/allonet_loader.c)
    target_link_libraries (Alloverse lovr)
    include_directories(deps/lovr/src)
    include_directories(deps/lovr/deps/luajit/src ${CMAKE_BINARY_DIR}/deps/lovr/luajit)

    file(GLOB ZIP_FILES "${CMAKE_CURRENT_SOURCE_DIR}/lua/*")
    add_custom_command(
        TARGET Alloverse POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E chdir ${CMAKE_CURRENT_SOURCE_DIR}/lua ${CMAKE_COMMAND} -E tar c ${CMAKE_CURRENT_BINARY_DIR}/lua.zip --format=zip -- ${ZIP_FILES}
        COMMAND copy /b $<SHELL_PATH:$<TARGET_FILE:Alloverse>>+lua.zip $<SHELL_PATH:$<TARGET_FILE:Alloverse>>
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:glfw> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:libluajit> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:ode> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:OpenAL> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:openvr_api64> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:lib_msdfgen> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:opus> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:allonet> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:lovr> ${CMAKE_CURRENT_BINARY_DIR}
    )
elseif(APPLE)
    # Force-load allonet into lovr exe
    target_link_libraries(lovr "-Wl,-all_load" allonet )

    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.app
        COMMAND cp -r ${CMAKE_CURRENT_BINARY_DIR}/deps/lovr/lovr.app ${CMAKE_CURRENT_BINARY_DIR}/Alloverse.app
        COMMAND cp -r ${CMAKE_CURRENT_SOURCE_DIR}/lua Alloverse.app/Contents/Resources/.lovr
        #COMMAND cp -r ${CMAKE_CURRENT_BINARY_DIR}/deps/allonet/liballonet.dylib Alloverse.app/Contents/Resources/.lovr/liballonet.so
        COMMAND cp -r ${CMAKE_CURRENT_BINARY_DIR}/deps/allonet/lib/opus/libopus.0.dylib Alloverse.app/Contents/MacOS
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/Info.plist Alloverse.app/Contents/Info.plist
        COMMAND cp ${CMAKE_CURRENT_SOURCE_DIR}/src/mac/alloverse.icns Alloverse.app/Contents/Resources/alloverse.icns
        COMMAND zip ${CMAKE_CURRENT_BINARY_DIR}/Alloverse-mac.zip -r Alloverse.app
        DEPENDS lovr allonet
    )
    add_custom_target(
        alloverse-dist ALL
        DEPENDS Alloverse.app
    )
elseif(ANDROID)
    # Force-load allonet into lovr exe
    target_link_libraries(lovr "-Wl,--whole-archive" allonet "-Wl,--no-whole-archive" "-ldl")

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