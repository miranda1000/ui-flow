# Native Linux x86_64 build against the official Qt binaries (linux_gcc_64).
if(NOT DEFINED ENV{QT_LINUX_X64_PATH})
    message(FATAL_ERROR "QT_LINUX_X64_PATH is not set - configure inside the build container (run.sh).")
endif()
list(APPEND CMAKE_PREFIX_PATH "$ENV{QT_LINUX_X64_PATH}")
