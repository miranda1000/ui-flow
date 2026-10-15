cmake_minimum_required(VERSION 3.24)

project(UiFlow
    VERSION 0.1.0
    DESCRIPTION "ui-flow - local, single-file UI flow designer"
    LANGUAGES C CXX)

set(UIFLOW_EXE_NAME "ui-flow")
set(UIFLOW_VERSION_SUFFIX "" CACHE STRING "Suffix appended to the displayed version (e.g. -dev)")
set(UIFLOW_VERSION_STRING "${PROJECT_VERSION}${UIFLOW_VERSION_SUFFIX}")
file(WRITE "${CMAKE_BINARY_DIR}/version.txt" "${UIFLOW_VERSION_STRING}")

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Debug or Release" FORCE)
endif()

# clang-cl: release CRT and release Qt DLLs even for Debug builds (the MSVC debug runtime
# is not redistributable); DWARF debug info so the binaries can be debugged with GDB.
if(CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(CMAKE_MSVC_RUNTIME_LIBRARY MultiThreadedDLL)
    set(CMAKE_MAP_IMPORTED_CONFIG_DEBUG Release "")
    set(CMAKE_CXX_FLAGS_DEBUG "/Od /Ob0 /Oy- /Z7 -gdwarf /clang:-gdwarf-4")
    set(CMAKE_EXE_LINKER_FLAGS_DEBUG "/debug:dwarf /incremental:no")
endif()

# Linux: keep the glibc requirement at what the Qt binaries need (see cmake/glibc-compat.h).
if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options("SHELL:-include ${PROJECT_SOURCE_DIR}/cmake/glibc-compat.h")
endif()

# WebAssembly: the core library reports malformed app files with exceptions, which
# Emscripten disables by default. Use its JavaScript-based exception model: the one Qt for
# WebAssembly is built and linked with (the two models cannot be mixed).
if(EMSCRIPTEN)
    add_compile_options(-fexceptions)
    add_link_options(-fexceptions)
endif()

option(UIFLOW_BUILD_APP "Build the ui-flow application (Qt Quick UI)" ON)
option(UIFLOW_BUILD_TESTS "Build the unit tests (core library only, no Qt needed)" OFF)

# --- Third-party sources ---------------------------------------------------------------
# In the build container they are pre-downloaded to $UIFLOW_DEPS_DIR (see Dockerfile);
# anywhere else FetchContent downloads the same pinned versions.
include(FetchContent)
if(DEFINED ENV{UIFLOW_DEPS_DIR})
    set(FETCHCONTENT_SOURCE_DIR_NLOHMANN_JSON "$ENV{UIFLOW_DEPS_DIR}/json")
    set(FETCHCONTENT_SOURCE_DIR_STB "$ENV{UIFLOW_DEPS_DIR}/stb")
    set(UIFLOW_FONT_DIR "$ENV{UIFLOW_DEPS_DIR}/inter" CACHE PATH "Directory with Inter-*.ttf")
else()
    set(UIFLOW_FONT_DIR "" CACHE PATH "Directory with Inter-*.ttf (empty: system font)")
endif()
FetchContent_Declare(nlohmann_json
    GIT_REPOSITORY https://github.com/nlohmann/json.git
    GIT_TAG        v3.12.0
    GIT_SHALLOW    TRUE)
FetchContent_Declare(stb
    GIT_REPOSITORY https://github.com/nothings/stb.git
    GIT_TAG        2c980bb59875b0d32144a71867fbdebb2f77cd20)
FetchContent_MakeAvailable(nlohmann_json stb)

add_subdirectory(src/core)

if(UIFLOW_BUILD_APP)
    find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 Svg)
    qt_standard_project_setup(REQUIRES 6.8)
    add_subdirectory(src/app)
endif()

if(UIFLOW_BUILD_TESTS)
    enable_testing()
    add_subdirectory(tests)
endif()
