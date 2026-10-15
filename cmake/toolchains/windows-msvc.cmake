# Cross-compile Windows (MSVC ABI) binaries from Linux with clang-cl + lld-link.
# Included by windows-x64.cmake / windows-arm64.cmake after they set:
#   UIFLOW_WIN_ARCH   x86_64 | aarch64   (xwin directory names)
#   UIFLOW_QT_ENV     environment variable holding the matching Qt for Windows
# Expects the environment prepared by the project Dockerfile:
#   XWIN_DIR          MSVC CRT + Windows SDK splatted by xwin (crt/, sdk/)
#   QT_HOST_PATH      Qt for linux_gcc_64 (host tools: moc, rcc, qmlcachegen, ...)

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_VERSION 10.0)

foreach(_var XWIN_DIR QT_HOST_PATH ${UIFLOW_QT_ENV})
    if(NOT DEFINED ENV{${_var}})
        message(FATAL_ERROR "${_var} is not set - configure inside the build container (run.sh).")
    endif()
endforeach()
set(XWIN_DIR "$ENV{XWIN_DIR}")

set(CMAKE_C_COMPILER   clang-cl)
set(CMAKE_CXX_COMPILER clang-cl)
set(CMAKE_LINKER       lld-link)
set(CMAKE_AR           llvm-lib)
set(CMAKE_RC_COMPILER  llvm-rc)
set(CMAKE_MT           llvm-mt)
set(CMAKE_C_COMPILER_TARGET   ${UIFLOW_WIN_ARCH}-pc-windows-msvc)
set(CMAKE_CXX_COMPILER_TARGET ${UIFLOW_WIN_ARCH}-pc-windows-msvc)

set(_flags
    "-imsvc ${XWIN_DIR}/crt/include"
    "-imsvc ${XWIN_DIR}/sdk/include/ucrt"
    "-imsvc ${XWIN_DIR}/sdk/include/um"
    "-imsvc ${XWIN_DIR}/sdk/include/shared"
    "-imsvc ${XWIN_DIR}/sdk/include/winrt"
    "-fms-compatibility-version=19.40")
list(JOIN _flags " " _flags)
set(CMAKE_C_FLAGS_INIT   "${_flags}")
set(CMAKE_CXX_FLAGS_INIT "${_flags}")

set(_link
    "/libpath:${XWIN_DIR}/crt/lib/${UIFLOW_WIN_ARCH}"
    "/libpath:${XWIN_DIR}/sdk/lib/um/${UIFLOW_WIN_ARCH}"
    "/libpath:${XWIN_DIR}/sdk/lib/ucrt/${UIFLOW_WIN_ARCH}")
list(JOIN _link " " _link)
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_link}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_link}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_link}")

# xwin only ships the release CRT (no msvcrtd.lib), so compiler checks must link Release.
set(CMAKE_TRY_COMPILE_CONFIGURATION Release)

# Programs (moc, qmlcachegen, ...) come from the Linux host; libraries from the target.
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)

list(APPEND CMAKE_PREFIX_PATH "$ENV{${UIFLOW_QT_ENV}}")
set(QT_HOST_PATH "$ENV{QT_HOST_PATH}" CACHE PATH "Qt installation used for host tools")
