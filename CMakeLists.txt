cmake_minimum_required(VERSION 3.13.0) # 3.13 minimum for CMP0079
project(allovisor VERSION 0.2.0)
cmake_policy(SET CMP0079 NEW)

SET(LOVR_BUILD_SHARED ON CACHE BOOL "Always build lovr as library")
SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
SET(LOVR_ENABLE_ENET OFF CACHE BOOL "Disable Lovr enet since allonet embeds its own")
set(ALLONET_USE_LUA ON CACHE BOOL "Request Lua bridge")
set(ALLONET_BUILD_STATIC ON CACHE BOOL "Always build allonet static")
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON CACHE BOOL "always export all symbols")

set(CPACK_PACKAGE_NAME Alloverse)
SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Create your own classrooms, meeting places or social spaces in the Alloverse and, from inside it, run collaborative apps with your students, colleagues and friends. The Alloverse is an open source 'operating system' for collaborative workspaces in VR.")
SET(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
SET(CPACK_PACKAGE_VENDOR "Alloverse AB")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

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

    set(CPACK_GENERATOR "NSIS")
    #set(CPACK_NSIS_INSTALLED_ICON_NAME "${APP_LOW_NAME}.ico")
    set(CPACK_NSIS_HELP_LINK "https://alloverse.com/support")
    set(CPACK_NSIS_URL_INFO_ABOUT "https://alloverse.com/")
    set(CPACK_NSIS_CONTACT "info@alloverse.com")
    set(CPACK_NSIS_ENABLE_UNINSTALL_BEFORE_INSTALL ON)
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Alloverse")
    set(CPACK_NSIS_INSTALLED_ICON_NAME "Alloverse.exe")
    set(CPACK_NSIS_DISPLAY_NAME "Alloverse ${PROJECT_VER}")
    if (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    else (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES")
    endif (CMAKE_CL_64)
    include(CPack)


    install(TARGETS Alloverse DESTINATION .)
    install(FILES $<TARGET_FILE:glfw> DESTINATION .)
    install(FILES $<TARGET_FILE:libluajit> DESTINATION .)
    install(FILES $<TARGET_FILE:ode> DESTINATION .)
    install(FILES $<TARGET_FILE:OpenAL> DESTINATION .)
    install(FILES $<TARGET_FILE:openvr_api64> DESTINATION .)
    install(FILES $<TARGET_FILE:lib_msdfgen> DESTINATION .)
    install(FILES $<TARGET_FILE:opus> DESTINATION .)
    install(FILES $<TARGET_FILE:allonet> DESTINATION .)
    install(FILES $<TARGET_FILE:lovr> DESTINATION .)

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