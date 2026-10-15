# WebAssembly (static website): Qt for WebAssembly (wasm_singlethread, static libraries)
# on top of Emscripten from emsdk, as installed by the project Dockerfile. Qt's own
# toolchain file chainloads Emscripten's (found through $EMSDK).

foreach(_var QT_HOST_PATH QT_WASM_PATH EMSDK)
    if(NOT DEFINED ENV{${_var}})
        message(FATAL_ERROR "${_var} is not set - configure inside the build container (run.sh).")
    endif()
endforeach()

set(QT_HOST_PATH "$ENV{QT_HOST_PATH}" CACHE PATH "Qt installation used for host tools")
include("$ENV{QT_WASM_PATH}/lib/cmake/Qt6/qt.toolchain.cmake")
