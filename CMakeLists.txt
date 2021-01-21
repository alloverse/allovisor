cmake_minimum_required(VERSION 3.13.0) # 3.13 minimum for CMP0079
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14" CACHE STRING "Minimum OS X deployment version")
project(allovisor VERSION 0.2.0)
cmake_policy(SET CMP0079 NEW)
cmake_policy(SET CMP0068 NEW)
cmake_policy(SET CMP0042 NEW) # make @rpath default

# Vars defining the contents of the Alloverse target across platforms
SET(ALLO_SOURCES src/allonet_loader.c)
SET(ALLO_LINK_LIBS lovr allonet)
SET(ALLO_LUA_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lua)

# Build settings that need to go before add_subdirectory
SET(LOVR_BUILD_SHARED ON CACHE BOOL "Always build lovr as library")
SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
SET(LOVR_ENABLE_ENET OFF CACHE BOOL "Disable Lovr enet since allonet embeds its own")
set(ALLONET_USE_LUA ON CACHE BOOL "Request Lua bridge")
if(APPLE OR ANDROID)
  set(ALLONET_BUILD_STATIC ON CACHE BOOL "Always build allonet static")
endif()
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON CACHE BOOL "always export all symbols")
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(LUAJIT_ENABLE_GC64 ON CACHE BOOL "GC64 needed to avoid changing -image_base, which breaks the linker cache")

if(ANDROID)
    SET(BUILD_SHARED_LIBS OFF CACHE BOOL "Default to static linking, otherwise libluajit becomes dynamic??")

    set(ALLONET_LINK_TINYCTHREAD OFF CACHE BOOL "lovr already has tinycthread, and on android that becomes duplicate symbols")
    
    SET(ANDROID_ASSETS ${ALLO_LUA_SOURCE_DIR})
    set(ANDROID_MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/src/android/AndroidManifest_${ANDROID_VARIANT}.xml" CACHE STRING "The AndroidManifest.xml file to use")

    if(ANDROID_VARIANT STREQUAL "quest")
        set(APKNAME "alloverse-quest.apk")
        set(LOVR_USE_VRAPI ON CACHE BOOL "build with vrapi")
    elseif(ANDROID_VARIANT STREQUAL "pico")
        set(APKNAME "alloverse-pico.apk")
        set(LOVR_USE_PICO ON CACHE BOOL "build with pico")
    else()
        message(FATAL_ERROR "No ANDROID_VARIANT provided")
    endif()
endif()


# Installer settings (again, before any add_subdirectory)
set(CPACK_PACKAGE_NAME Alloverse)
SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Create your own classrooms, meeting places or social spaces in the Alloverse and, from inside it, run collaborative apps with your students, colleagues and friends. The Alloverse is an open source 'operating system' for collaborative workspaces in VR.")
SET(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
SET(CPACK_PACKAGE_VENDOR "Alloverse AB")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

# Add dependencies' cmakes
add_subdirectory (deps/lovr)
add_subdirectory (deps/allonet)

# Build settings that go after add_subdirectory (i e only applies
# to these targets, not dependencies' targets)
include_directories(deps/lovr/src)
include_directories(deps/lovr/deps/luajit/src ${CMAKE_BINARY_DIR}/deps/lovr/luajit)


# Targets and installers for each platform
if(WIN32)
    add_executable(Alloverse ${ALLO_SOURCES})
    target_link_libraries(Alloverse ${ALLO_LINK_LIBS})
    target_compile_options(Alloverse PRIVATE /W4)

    add_custom_command(
        TARGET Alloverse POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:glfw> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:libluajit> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:ode> ${CMAKE_CURRENT_BINARY_DIR}
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
    # from https://braintrekking.wordpress.com/2013/04/27/dll-hell-how-to-include-microsoft-redistributable-runtime-libraries-in-your-cmakecpack-project/
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ".")
    include (InstallRequiredSystemLibraries)
    message( "Runtime installation files: ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}" )
    install(DIRECTORY lua DESTINATION .)
    install(FILES $<TARGET_FILE:glfw> DESTINATION .)
    install(FILES $<TARGET_FILE:libluajit> DESTINATION .)
    install(FILES $<TARGET_FILE:ode> DESTINATION .)
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

    ## Setup Info.plist
    # Sets the icon
    SET(MACOSX_BUNDLE_ICON_FILE alloverse.icns)
    # Give the location of the icon
    set_source_files_properties(${ALLO_ICON} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)

    set(APP_NAME Alloverse)

    # Setup the executable
    add_executable (${APP_NAME} MACOSX_BUNDLE 
        ${ALLO_SOURCES}
        src/allomac.m
        ${ALLO_ICON}
    )

    find_library(AVFOUNDATION_LIBRARY NAMES AVFoundation)

    # Link the libs
    target_link_libraries (Alloverse 
        ${ALLO_LINK_LIBS}
        ${AVFOUNDATION_LIBRARY}
    )

    target_compile_options(Alloverse PRIVATE -Wall -Wextra -pedantic)

    # stack-check breaks luajit
    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fno-stack-check")

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
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/src/mac/MacOSXBundleInfo.plist.in"
        # RESOURCE "${CMAKE_CURRENT_SOURCE_DIR}/src/resources/lovr.icns"
    )


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

    # TODO: modify manifest with app name etc...
    add_custom_target(
        Alloverse ALL
        DEPENDS lovr buildAPK
        BYPRODUCTS ${APKNAME}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_PROPERTY:lovr,BINARY_DIR>/lovr.apk ${CMAKE_CURRENT_BINARY_DIR}/${APKNAME}
    )
elseif(UNIX)
    add_executable(Alloverse ${ALLO_SOURCES})
    target_link_libraries(Alloverse ${ALLO_LINK_LIBS})
    target_compile_options(Alloverse PRIVATE -Wall -Wextra -pedantic)
endif()
