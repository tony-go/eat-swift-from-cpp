.PHONY: all setup build clean

# Default target executed
all: build

# Setup build directory and run CMake
setup:
	@mkdir -p build
	@cd build && cmake -G 'Ninja' -DCMAKE_CXX_COMPILER=clang++ ../

# Build the project using Ninja
build: setup
	@cd build && ninja

run:
	./build/cpp_ex

# Clean the build directory
clean:
	@rm -rf build

