cmake_minimum_required(VERSION 3.10)
project(railway_secretariat LANGUAGES CXX)

set(BINARY_NAME "railway_secretariat")
set(APPLICATION_ID "com.railways.secretariat_system")

cmake_policy(SET CMP0063 NEW)

set(CMAKE_INSTALL_RPATH "\$ORIGIN/lib")

# Root filesystem for cross-building.
if(FLUTTER_TARGET_PLATFORM_SYSROOT)
  set(CMAKE_SYSROOT \${FLUTTER_TARGET_PLATFORM_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH \${CMAKE_SYSROOT})
  set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
  set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
  set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
endif()

# Define build configuration options.
if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
  set(CMAKE_BUILD_TYPE "Debug" CACHE
    STRING "Flutter build mode" FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Profile" "Release")
endif()

# Compilation settings that should be applied to most targets.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(\${TARGET} PUBLIC cxx_std_14)
  target_compile_options(\${TARGET} PRIVATE -Wall -Werror)
  target_compile_options(\${TARGET} PRIVATE "\$<\$<NOT:\$<CONFIG:Debug>>:-O3>")
endfunction()

set(FLUTTER_MANAGED_DIR "\${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Flutter library and tool build rules.
add_subdirectory(\${FLUTTER_MANAGED_DIR})

# System-level dependencies.
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK REQUIRED IMPORTED_TARGET gtk+-3.0)

add_definitions(-DAPPLICATION_ID=\"\${APPLICATION_ID}\")

add_executable(\${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "\${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

apply_standard_settings(\${BINARY_NAME})
target_link_libraries(\${BINARY_NAME} PRIVATE flutter)
target_link_libraries(\${BINARY_NAME} PRIVATE PkgConfig::GTK)
add_dependencies(\${BINARY_NAME} flutter_assemble)

# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)
