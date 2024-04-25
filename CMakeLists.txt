cmake_minimum_required(VERSION 3.26)

project(EatSwiftFromCPP LANGUAGES CXX Swift)

# Check Swift compiler version

if("${CMAKE_Swift_COMPILER_VERSION}" VERSION_LESS 5.9)
  message(FATAL_ERROR "Bidirectional C++ Interop requires Swift 5.9 or greater. Have ${CMAKE_Swift_COMPILER_VERSION}")
endif()

# Check that Clang is the C++ compiler as this interopability is only available with Clang

if(NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" AND
   NOT "${CMAKE_CXX_COMPILER_ID}" STREQUAL "AppleClang")
  message(FATAL_ERROR "Project requires building with Clang.
  Have ${CMAKE_CXX_COMPILER_ID}")
endif()

function(_swift_windows_arch_name output_variable_name target_arch)
  if(NOT WIN32)
    return()
  endif()

  if("${target_arch}" STREQUAL "AMD64")
    set("${output_variable_name}" "x86_64" PARENT_SCOPE)
  elseif("${target_arch}" STREQUAL "ARM64")
    set("${output_variable_name}" "aarch64" PARENT_SCOPE)
  else()
    message(FATAL_ERROR "Unknown windows architecture: ${target_arch}")
  endif()
endfunction()

# Compute flags and search paths
# NOTE: This logic will eventually move to CMake
function(_setup_swift_paths)
  # If we haven't set the swift library search paths, do that now
  if(NOT SWIFT_LIBRARY_SEARCH_PATHS)
    if(APPLE)
      set(SDK_FLAGS "-sdk" "${CMAKE_OSX_SYSROOT}")
    endif()

    # Note: This does not handle cross-compiling correctly.
    #       To handle it correctly, we would need to pass the target triple and
    #       flags to this compiler invocation.
    execute_process(
      COMMAND ${CMAKE_Swift_COMPILER} ${SDK_FLAGS} -print-target-info
      OUTPUT_VARIABLE SWIFT_TARGET_INFO
    )

    # extract search paths from swift driver response
    string(JSON SWIFT_TARGET_PATHS GET ${SWIFT_TARGET_INFO} "paths")

    string(JSON SWIFT_TARGET_LIBRARY_PATHS GET ${SWIFT_TARGET_PATHS} "runtimeLibraryPaths")
    string(JSON SWIFT_TARGET_LIBRARY_PATHS_LENGTH LENGTH ${SWIFT_TARGET_LIBRARY_PATHS})
    math(EXPR SWIFT_TARGET_LIBRARY_PATHS_LENGTH "${SWIFT_TARGET_LIBRARY_PATHS_LENGTH} - 1 ")

    string(JSON SWIFT_TARGET_LIBRARY_IMPORT_PATHS GET ${SWIFT_TARGET_PATHS} "runtimeLibraryImportPaths")
    string(JSON SWIFT_TARGET_LIBRARY_IMPORT_PATHS_LENGTH LENGTH ${SWIFT_TARGET_LIBRARY_IMPORT_PATHS})
    math(EXPR SWIFT_TARGET_LIBRARY_IMPORT_PATHS_LENGTH "${SWIFT_TARGET_LIBRARY_IMPORT_PATHS_LENGTH} - 1 ")

    string(JSON SWIFT_SDK_IMPORT_PATH ERROR_VARIABLE errno GET ${SWIFT_TARGET_PATHS} "sdkPath")

    foreach(JSON_ARG_IDX RANGE ${SWIFT_TARGET_LIBRARY_PATHS_LENGTH})
      string(JSON SWIFT_LIB GET ${SWIFT_TARGET_LIBRARY_PATHS} ${JSON_ARG_IDX})
      list(APPEND SWIFT_SEARCH_PATHS ${SWIFT_LIB})
    endforeach()

    foreach(JSON_ARG_IDX RANGE ${SWIFT_TARGET_LIBRARY_IMPORT_PATHS_LENGTH})
      string(JSON SWIFT_LIB GET ${SWIFT_TARGET_LIBRARY_IMPORT_PATHS} ${JSON_ARG_IDX})
      list(APPEND SWIFT_SEARCH_PATHS ${SWIFT_LIB})
    endforeach()

    if(SWIFT_SDK_IMPORT_PATH)
      list(APPEND SWIFT_SEARCH_PATHS ${SWIFT_SDK_IMPORT_PATH})
    endif()

    # Save the swift library search paths
    set(SWIFT_LIBRARY_SEARCH_PATHS ${SWIFT_SEARCH_PATHS} CACHE FILEPATH "Swift driver search paths")
  endif()

  link_directories(${SWIFT_LIBRARY_SEARCH_PATHS})

  if(WIN32)
    _swift_windows_arch_name(SWIFT_WIN_ARCH_DIR "${CMAKE_SYSTEM_PROCESSOR}")
    set(SWIFT_SWIFTRT_FILE "$ENV{SDKROOT}/usr/lib/swift/windows/${SWIFT_WIN_ARCH_DIR}/swiftrt.obj")
    add_link_options("$<$<LINK_LANGUAGE:Swift>:${SWIFT_SWIFTRT_FILE}>")
  elseif(NOT APPLE)
    find_file(SWIFT_SWIFTRT_FILE
              swiftrt.o
              PATHS ${SWIFT_LIBRARY_SEARCH_PATHS}
              NO_CACHE
              REQUIRED
              NO_DEFAULT_PATH)
    add_link_options("$<$<LINK_LANGUAGE:Swift>:${SWIFT_SWIFTRT_FILE}>")
  endif()
endfunction()

_setup_swift_paths()

# We basically include .cmake files which contains our cmake functions.

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(AddSwift)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_OSX_DEPLOYMENT_TARGET 13.0)

# This function is written in the "cmake/AddSwift.cmake" file
# It will generate the header file to consume Swift code from C++.

generate_cxx_header_target_from_swift(
  swift_lib_h
  SwiftLib
  "${CMAKE_CURRENT_BINARY_DIR}/include/swift-lib.h"
  SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/Lib.swift")

# Now we need to create a Library for Swift sources

add_library(swift_lib STATIC Lib.swift)

# The library requires the Swift header in order to compile, so we create a
#   dependency between the library and the header target created above.

add_dependencies(swift_lib swift_lib_h)

# This libraries, and users of this library, will need to find the
#   generated header.

target_include_directories(swift_lib PUBLIC "${CMAKE_CURRENT_BINARY_DIR}/include")

# Manually override the Swift module name to "SwiftLib" to match the
#   name in the generated header header above.

set_target_properties(swift_lib PROPERTIES Swift_MODULE_NAME "SwiftLib")

# Enable C++ interoperability mode on all Swift compilations. Again, this is
#   We make it 'PUBLIC' to ensure the flag is propagated to users of the library.

target_compile_options(swift_lib PUBLIC
  "$<$<COMPILE_LANGUAGE:Swift>:-cxx-interoperability-mode=default>")

# Finally we create our exectutable based on the C++ translation unit.
#   Then, we link the Swift lib to the executable.

add_executable(cpp_ex main.cc)
target_link_libraries(cpp_ex PRIVATE swift_lib)
