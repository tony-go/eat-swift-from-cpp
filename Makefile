.PHONY: all setup build clean

# Default compiler
CXX ?= clang++

# Default target executed
all: build

# Setup build directory and run CMake
setup:
	@mkdir -p build
	@cd build && cmake -G 'Ninja' -DCMAKE_CXX_COMPILER=$(CXX) ../

# Build the project using Ninja
build: setup
	@cd build && ninja -v

run:
	./build/cpp_ex

# Clean the build directory
clean:
	@rm -rf build

