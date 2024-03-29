cmake_minimum_required(VERSION 3.13.0) # 3.13 minimum for CMP0079
set(CMAKE_OSX_DEPLOYMENT_TARGET "10.14" CACHE STRING "Minimum OS X deployment version")
project(allovisor VERSION 0.2.0)
cmake_policy(SET CMP0079 NEW)
cmake_policy(SET CMP0068 NEW)
cmake_policy(SET CMP0042 NEW) # make @rpath default

# Vars defining the contents of the Alloverse target across platforms
SET(ALLO_SOURCES 
  src/desktop_main.c # removed later if android
  src/get_version.c
  src/media.c
 "src/util.h")
SET(ALLO_LINK_LIBS lovr allonet allonet_av)
SET(ALLO_LUA_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/lua)

# Build settings that need to go before add_subdirectory
SET(LOVR_BUILD_SHARED ON CACHE BOOL "Always build lovr as library")
SET(LOVR_SYMBOL_VISIBILITY "default" CACHE STRING "Declare bravery")
SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
SET(LOVR_ENABLE_ENET OFF CACHE BOOL "Disable Lovr enet since allonet embeds its own")
SET(LOVR_BUILD_WITH_EXPORTED_INTERNALS ON CACHE BOOL "Expose Lovr internals")

set(ALLONET_USE_LUA ON CACHE BOOL "Request Lua bridge")
if(APPLE OR ANDROID)
  set(ALLONET_BUILD_STATIC ON CACHE BOOL "Always build allonet static")
endif()
set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON CACHE BOOL "always export all symbols")
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(LUAJIT_ENABLE_GC64 ON CACHE BOOL "GC64 needed to avoid changing -image_base, which breaks the linker cache")
if(WIN32)
  set(LOVR_USE_OCULUS ON CACHE BOOL "Use Oculus on Windows")
else()
  set(LOVR_USE_OCULUS OFF CACHE BOOL "Turn off Oculus on non-windows")
endif()

# Versioning
# crazy relative-path hack courtesy of running bash on windows and having mixed path types...
file(RELATIVE_PATH GENERATE_VERSION_SH ${CMAKE_CURRENT_BINARY_DIR} ${CMAKE_CURRENT_SOURCE_DIR}/generate-version.sh)
add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/include/allovisor_version.h
  WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
	COMMAND bash ${GENERATE_VERSION_SH} include
)
add_custom_target(
    allovisor_version_header ALL
    DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/include/allovisor_version.h
)

if(ANDROID)
    SET(BUILD_SHARED_LIBS OFF CACHE BOOL "Default to static linking, otherwise libluajit becomes dynamic??")

    set(ALLONET_THREADING_STRATEGY "force_use_tinycthread" CACHE STRING "lovr already has tinycthread, and on android that becomes duplicate symbols")
    set(ALLONET_LINK_TINYCTHREAD OFF CACHE BOOL "lovr already has tinycthread, and on android that becomes duplicate symbols. Use this symbol in addition to ALLONET_THREADING_STRATEGY to be compatible with both main and x264 branch")

    SET(ANDROID_ASSETS ${ALLO_LUA_SOURCE_DIR})
    set(ANDROID_MANIFEST "${CMAKE_CURRENT_SOURCE_DIR}/src/android/AndroidManifest_${ANDROID_VARIANT}.xml" CACHE STRING "The AndroidManifest.xml file to use")

    if(ANDROID_VARIANT STREQUAL "quest")
        set(APKNAME "alloverse-${PROJECT_VERSION}-quest.apk")
        set(LOVR_USE_VRAPI ON CACHE BOOL "build with vrapi")
    elseif(ANDROID_VARIANT STREQUAL "pico")
        set(APKNAME "alloverse-${PROJECT_VERSION}-pico.apk")
        set(LOVR_USE_PICO ON CACHE BOOL "build with pico")
    else()
        message(FATAL_ERROR "No ANDROID_VARIANT provided")
    endif()
else()
set(ALLONET_THREADING_STRATEGY "force_link_tinycthread" CACHE STRING "use tinycthread just to be consistent with android")
endif()

file(GLOB ALLO_LOVR_PLUGINS lovr-plugins/*)
set(LOVR_BUILD_EXTRA_PLUGINS ${ALLO_LOVR_PLUGINS})


# Installer settings (again, before any add_subdirectory)
set(CPACK_PACKAGE_NAME Alloverse)
SET(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Create your own classrooms, meeting places or social spaces in the Alloverse and, from inside it, run collaborative apps with your students, colleagues and friends. The Alloverse is an open source 'operating system' for collaborative workspaces in VR.")
SET(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_CURRENT_SOURCE_DIR}/README.md")
SET(CPACK_PACKAGE_VENDOR "Alloverse AB")
set(CPACK_PACKAGE_VERSION ${PROJECT_VERSION})
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

# Build settings for ALL targets (to be added before any add_subdirectory)
set(CMAKE_XCODE_ATTRIBUTE_DEBUG_INFORMATION_FORMAT "dwarf-with-dsym")
set(CMAKE_XCODE_ATTRIBUTE_GCC_GENERATE_DEBUGGING_SYMBOLS "YES")


# Add dependencies' cmakes
add_subdirectory (deps/lovr)
add_subdirectory (deps/allonet)

# Build settings that go after add_subdirectory (i e only applies
# to these targets, not dependencies' targets)
include_directories(src ${CMAKE_CURRENT_BINARY_DIR}/include)
include_directories(src deps/allonet/include deps/allonet/lib)
include_directories(deps/lovr/src deps/lovr/src/modules)
include_directories(deps/lovr/deps/luajit/src ${CMAKE_BINARY_DIR}/deps/lovr/luajit)


# Targets and installers for each platform
if(WIN32)
    add_executable(Alloverse ${ALLO_SOURCES})
    target_link_libraries(Alloverse ${ALLO_LINK_LIBS})
    add_dependencies(Alloverse allovisor_version_header)
    target_compile_options(Alloverse PRIVATE /W4)

    add_custom_command(
        TARGET Alloverse POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:glfw> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:libluajit> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:ode> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:openvr_api64> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:msdfgen> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:opus> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:allonet_av> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:allonet> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:lovr> ${CMAKE_CURRENT_BINARY_DIR}
        COMMAND ${CMAKE_COMMAND} -E copy ${LIBAV_DLLS} ${CMAKE_CURRENT_BINARY_DIR}
    )

    set(CPACK_GENERATOR "NSIS")
    #set(CPACK_NSIS_INSTALLED_ICON_NAME "${APP_LOW_NAME}.ico")
    set(CPACK_NSIS_HELP_LINK "https://alloverse.com/support")
    set(CPACK_NSIS_URL_INFO_ABOUT "https://alloverse.com/")
    set(CPACK_NSIS_CONTACT "info@alloverse.com")
    set(CPACK_PACKAGE_INSTALL_DIRECTORY "Alloverse")
    set(CPACK_NSIS_INSTALLED_ICON_NAME "Alloverse.exe")
    set(CPACK_NSIS_DISPLAY_NAME "Alloverse ${PROJECT_VERSION}")
    if (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES64")
    else (CMAKE_CL_64)
      set(CPACK_NSIS_INSTALL_ROOT "$PROGRAMFILES")
    endif (CMAKE_CL_64)
    set(CPACK_NSIS_EXTRA_INSTALL_COMMANDS "CreateShortCut \\\"$SMPROGRAMS\\\\$STARTMENU_FOLDER\\\\Alloverse.lnk\\\" \\\"$INSTDIR\\\\.\\\\Alloverse.exe \\\"")
    set(CPACK_COMPONENTS_ALL "Alloverse")
    include(CPack)


    install(TARGETS Alloverse DESTINATION . COMPONENT Alloverse)
    # from https://braintrekking.wordpress.com/2013/04/27/dll-hell-how-to-include-microsoft-redistributable-runtime-libraries-in-your-cmakecpack-project/
    set(CMAKE_INSTALL_SYSTEM_RUNTIME_DESTINATION ".")
    include (InstallRequiredSystemLibraries)
    message( "Runtime installation files: ${CMAKE_INSTALL_SYSTEM_RUNTIME_LIBS}" )
    message( "LibAV DLLs: ${LIBAV_DLLS}" )
    install(DIRECTORY lua DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:glfw> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:libluajit> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:ode> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:openvr_api64> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:msdfgen> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:opus> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:allonet> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:allonet_av> DESTINATION . COMPONENT Alloverse)
    install(FILES $<TARGET_FILE:lovr> DESTINATION . COMPONENT Alloverse)
    install(FILES ${LIBAV_DLLS} DESTINATION . COMPONENT Alloverse)

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
    set(CMAKE_XCODE_ATTRIBUTE_OTHER_CODE_SIGN_FLAGS "--deep")

    list(APPEND ALLO_SOURCES src/allomac.m)

    # Setup the executable
    add_executable (${APP_NAME} MACOSX_BUNDLE 
        ${ALLO_SOURCES}
        ${ALLO_ICON}
    )

    set_property(TARGET ${APP_NAME} PROPERTY ENABLE_EXPORTS 1) # for get_version

    add_dependencies(${APP_NAME} allovisor_version_header)

    find_library(AVFOUNDATION_LIBRARY NAMES AVFoundation)

    # Link the libs
    target_link_libraries (Alloverse 
        "-Wl,-force_load" allonet
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
    move_lib(msdfgen)
    move_lib(ode)
    move_lib(openvr_api)
    message( "LibAV DLLs: ${LIBAV_DLLS}" )
    add_custom_command(TARGET Alloverse POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy
      ${LIBAV_DLLS}
      $<TARGET_FILE_DIR:Alloverse>/
    )
    
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
    list(REMOVE_ITEM ALLO_SOURCES src/desktop_main.c)

    add_library(visorlib STATIC
      ${ALLO_SOURCES}
    )
    add_dependencies(visorlib allovisor_version_header)

    # Force-load allonet into lovr exe
    target_link_libraries(lovr "-Wl,--whole-archive" allonet allonet_av visorlib "-Wl,--no-whole-archive" "-ldl")

    # Add the requisite libraries to the apk bundling
    file(COPY ${LIBAV_DLLS} DESTINATION deps/lovr/raw/lib/${ANDROID_ABI})

    add_custom_target(
        Alloverse ALL
        DEPENDS lovr buildAPK
        BYPRODUCTS ${APKNAME}
        COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_PROPERTY:lovr,BINARY_DIR>/lovr.apk ${CMAKE_CURRENT_BINARY_DIR}/${APKNAME}
    )
elseif(UNIX)
    add_executable(
      Alloverse 
      ${ALLO_SOURCES}
    )
    set_property(TARGET Alloverse PROPERTY ENABLE_EXPORTS 1) # for get_version from lua
    target_link_libraries(Alloverse ${ALLO_LINK_LIBS})
    add_dependencies(Alloverse allovisor_version_header)
    target_compile_options(Alloverse PRIVATE -Wall -Wextra -pedantic)
    set_target_properties(Alloverse PROPERTIES
      RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
      BUILD_WITH_INSTALL_RPATH TRUE
      INSTALL_RPATH "\$ORIGIN"
    )
    function(move_lib)
      if(TARGET ${ARGV0})
        get_target_property(TARGET_TYPE ${ARGV0} TYPE)
        if(${TARGET_TYPE} STREQUAL "MODULE_LIBRARY")
          add_custom_command(TARGET Alloverse POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_FILE:${ARGV0}>
            ${CMAKE_BINARY_DIR}/bin/$<TARGET_FILE_NAME:${ARGV0}>
          )
        else()
          add_custom_command(TARGET Alloverse POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy
            $<TARGET_SONAME_FILE:${ARGV0}>
            ${CMAKE_BINARY_DIR}/bin/$<TARGET_SONAME_FILE_NAME:${ARGV0}>
          )
        endif()
      endif()
    endfunction()
    move_lib(lovr)
    move_lib(allonet)
    move_lib(allonet_av)
    move_lib(${LOVR_GLFW})
    move_lib(${LOVR_LUA})
    move_lib(${LOVR_ODE})
    move_lib(${LOVR_OPENVR})
    move_lib(${LOVR_MSDF})
    move_lib(${LOVR_OCULUS_AUDIO})
    add_custom_command(TARGET Alloverse POST_BUILD
      COMMAND ${CMAKE_COMMAND} -E copy ${LIBAV_DLLS} ${CMAKE_BINARY_DIR}/bin
    )
endif()
