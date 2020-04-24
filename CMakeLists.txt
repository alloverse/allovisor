cmake_minimum_required(VERSION 3.13.0) # 3.13 minimum for CMP0079
project(allovisor VERSION 0.2.0)
cmake_policy(SET CMP0079 NEW)
cmake_policy(SET CMP0068 NEW)
cmake_policy(SET CMP0042 NEW) # make @rpath default

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

    add_custom_command(
        TARGET Alloverse POST_BUILD
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
    set(CPACK_NSIS_DISPLAY_NAME "Alloverse ${PROJECT_VERSION}")
    if (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    else (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES")
    endif (CMAKE_CL_64)
    set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\Alloverse.lnk\\\" \\\"$INSTDIR\\\\.\\\\Alloverse.exe \\\"")
    include(CPack)


    install(TARGETS Alloverse DESTINATION .)
    install(DIRECTORY lua DESTINATION .)
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
    set(INSTALL_NAME_DIR .)
    set(CMAKE_INSTALL_RPATH "@loader_path")
    set(CMAKE_XCODE_GENERATE_SCHEME ON)

    # Add the mac source dir to the module path, for the info plist
    list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/src/mac")
    
    # The icon
    SET(ALLO_ICON "${CMAKE_CURRENT_LIST_DIR}/src/mac/alloverse.icns")

    # The loader
    SET(ALLO_SOURCES src/allonet_loader.c)

    # Libs to link into the app target
    SET(ALLO_LINK_LIBS
        lovr
        allonet
    )
    
    # The dir with all the lua code
    SET(ALLO_LUA_SOURCE_DIR
        ${CMAKE_CURRENT_SOURCE_DIR}/lua
    )

    ## Setup Info.plist
    # Sets the icon
    SET(MACOSX_BUNDLE_ICON_FILE alloverse.icns)
    # Give the location of the icon
    set_source_files_properties(${ALLO_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    
    ## LuaJit requires some special linking
    # If you're building a 64 bit application on OSX which links directly or indirectly against LuaJIT, you need to link your main executable with these flags:
    # http://luajit.org/install.html
    set(CMAKE_EXE_LINKER_FLAGS ${CMAKE_EXE_LINKER_FLAGS} "-pagezero_size 10000 -image_base 100000000")

    set(APP_NAME Alloverse)

    # Setup the executable
    add_executable (${APP_NAME} MACOSX_BUNDLE 
        ${ALLO_SOURCES}
        ${ALLO_ICON}
    )

    # Link the libs
    target_link_libraries (Alloverse 
        ${ALLO_LINK_LIBS}
    )

    # Set xcode launch arguments for hot reload of the lua folder
    set_property(TARGET Alloverse 
        APPEND PROPERTY XCODE_SCHEME_ARGUMENTS "\${PROJECT_DIR}/deps/lodr"
        APPEND PROPERTY XCODE_SCHEME_ARGUMENTS "\${PROJECT_DIR}/lua"
    )

    set_target_properties(Alloverse PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_RPATH TRUE
        BUILD_WITH_INSTALL_RPATH TRUE
        INSTALL_RPATH "@loader_path"
        # MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/Info.plist"
        # RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/lovr.icns"
    )


    # Include dependencies
    include_directories(deps/lovr/src)
    include_directories(deps/lovr/deps/luajit/src ${CMAKE_BINARY_DIR}/deps/lovr/luajit)

    # Copy the lua code
    add_custom_command(TARGET Alloverse POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory ${ALLO_LUA_SOURCE_DIR} $<TARGET_FILE_DIR:Alloverse>/../Resources/.lovr
    )

    function(move_lib)
      if(TARGET ${ARGV0})
        add_custom_command(TARGET Alloverse POST_BUILD
          COMMAND ${CMAKE_COMMAND} -E copy
          $<TARGET_SONAME_FILE:${ARGV0}>
          $<TARGET_FILE_DIR:Alloverse>/$<TARGET_SONAME_FILE_NAME:${ARGV0}> # Bad
        )
      endif()
    endfunction()

    move_lib(lovr)
    move_lib(opus)
    move_lib(glfw)
    move_lib(libluajit)
    move_lib(lib_msdfgen)
    move_lib(ode)
    move_lib(OpenAL)
    move_lib(openvr_api)
    
    # Add the target to install package
    install(TARGETS ${APP_NAME} 
        BUNDLE DESTINATION . COMPONENT applications
        RUNTIME DESTINATION bin COMPONENT applications
        )

    # set(APPS 
    #     "\${CMAKE_INSTALL_PREFIX}/${APP_NAME}.app"
    #     )
    # SET(DIRS ${CMAKE_BINARY_DIR})

    # install(CODE "
    #     message(\"HELLO\")
    #     include(BundleUtilities)
    #     fixup_bundle(\"${APPS}\" \"\" \"${DIRS}\")")
    
    # Enable "drag into applications folder" dmg
    set(CPACK_BINARY_DRAGNDROP ON)
    # Only pack the application
    set(CPACK_ARCHIVE_COMPONENT_INSTALL ON)
    set(CPACK_COMPONENTS_ALL applications libs)
    # Pack it up
    include(CPack)
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