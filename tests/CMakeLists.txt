add_executable(uiflow_tests test_core.cpp)
target_link_libraries(uiflow_tests PRIVATE uiflow_core)
add_test(NAME core COMMAND uiflow_tests)
