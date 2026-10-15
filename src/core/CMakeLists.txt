# Document model, file format and flow analysis. No UI dependencies, so the unit tests
# build it natively.
add_library(uiflow_core STATIC
    model.cpp model.h
    io.cpp io.h
    image.cpp image.h
    flow.cpp flow.h
    geometry.cpp geometry.h)
target_include_directories(uiflow_core PUBLIC "${PROJECT_SOURCE_DIR}/src")
target_include_directories(uiflow_core SYSTEM PRIVATE "${stb_SOURCE_DIR}")
target_link_libraries(uiflow_core PRIVATE nlohmann_json::nlohmann_json)
