# Cross-compile Linux aarch64 from an x86_64 host: Ubuntu's gcc-aarch64-linux-gnu, the
# official Qt binaries for linux_gcc_arm64 and multiarch ":arm64" system libraries
# (/usr/lib/aarch64-linux-gnu), as installed by the project Dockerfile.

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

foreach(_var QT_HOST_PATH QT_LINUX_ARM64_PATH)
    if(NOT DEFINED ENV{${_var}})
        message(FATAL_ERROR "${_var} is not set - configure inside the build container (run.sh).")
    endif()
endforeach()

set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)
set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
set(CMAKE_LIBRARY_ARCHITECTURE aarch64-linux-gnu)

# A cross linker does not follow DT_RUNPATH, so tell it where Qt's and the system's
# indirect dependencies (ICU, xkbcommon, ...) live.
set(_qt "$ENV{QT_LINUX_ARM64_PATH}")
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-Wl,-rpath-link,${_qt}/lib -Wl,-rpath-link,/usr/lib/aarch64-linux-gnu -Wl,-rpath-link,/lib/aarch64-linux-gnu")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${CMAKE_EXE_LINKER_FLAGS_INIT}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(ENV{PKG_CONFIG_LIBDIR} "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_PATH} "")

list(APPEND CMAKE_PREFIX_PATH "${_qt}")
set(QT_HOST_PATH "$ENV{QT_HOST_PATH}" CACHE PATH "Qt installation used for host tools")
