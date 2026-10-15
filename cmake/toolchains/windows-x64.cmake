# Windows x64, MSVC ABI (clang-cl), Qt win64_msvc2022_64.
set(CMAKE_SYSTEM_PROCESSOR AMD64)
set(UIFLOW_WIN_ARCH x86_64)
set(UIFLOW_QT_ENV QT_WIN_X64_PATH)
include("${CMAKE_CURRENT_LIST_DIR}/windows-msvc.cmake")
