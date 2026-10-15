# Windows on ARM64, MSVC ABI (clang-cl), Qt win64_msvc2022_arm64_cross_compiled.
set(CMAKE_SYSTEM_PROCESSOR ARM64)
set(UIFLOW_WIN_ARCH aarch64)
set(UIFLOW_QT_ENV QT_WIN_ARM64_PATH)
include("${CMAKE_CURRENT_LIST_DIR}/windows-msvc.cmake")
