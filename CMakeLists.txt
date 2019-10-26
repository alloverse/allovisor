cmake_minimum_required(VERSION 3.1.0)
project(allovisor VERSION 0.2.0)

SET(LOVR_BUILD_BUNDLE ON CACHE BOOL "Always build lovr bundle on mac")
add_subdirectory (deps/lovr)
