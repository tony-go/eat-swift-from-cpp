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


# We basically include .cmake files which contains our cmake functions.

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")
include(InitSwift)
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
