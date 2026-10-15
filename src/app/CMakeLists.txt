qt_add_executable(uiflow WIN32 main.cpp)
set_target_properties(uiflow PROPERTIES OUTPUT_NAME "${UIFLOW_EXE_NAME}")
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    # Console subsystem: Qt log output goes to the terminal and to GDB.
    set_target_properties(uiflow PROPERTIES WIN32_EXECUTABLE FALSE)
endif()

set(UIFLOW_QML_FILES
    qml/Main.qml
    qml/Theme.qml
    qml/Ui.qml
    qml/Icon.qml
    qml/FButton.qml
    qml/FIconButton.qml
    qml/FTextField.qml
    qml/FTextArea.qml
    qml/FComboBox.qml
    qml/FSwitch.qml
    qml/FSlider.qml
    qml/FMenu.qml
    qml/FMenuItem.qml
    qml/FMenuSeparator.qml
    qml/FToolTip.qml
    qml/FDialog.qml
    qml/SectionHeader.qml
    qml/ListRow.qml
    qml/Toast.qml
    qml/TopBar.qml
    qml/Welcome.qml
    qml/CanvasView.qml
    qml/ScreenItem.qml
    qml/LinkItem.qml
    qml/ScreensPanel.qml
    qml/Inspector.qml
    qml/ScreenPickerMenu.qml
    qml/EditorView.qml
    qml/PlayerView.qml
    qml/NewAppDialog.qml
    qml/InteractionDialog.qml
    qml/ConfirmDialog.qml
    qml/ShortcutsDialog.qml
)
# Keep every QML file at the module root (next to its qmldir), so they see each other
# and the Theme singleton without importing their own module.
foreach(_qml ${UIFLOW_QML_FILES})
    get_filename_component(_name "${_qml}" NAME)
    set_source_files_properties("${_qml}" PROPERTIES QT_RESOURCE_ALIAS "${_name}")
endforeach()
set_source_files_properties(qml/Theme.qml qml/Ui.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)

file(GLOB UIFLOW_ICONS RELATIVE "${CMAKE_CURRENT_SOURCE_DIR}" CONFIGURE_DEPENDS icons/*.svg)

qt_add_qml_module(uiflow
    URI UiFlow
    VERSION 1.0
    QML_FILES ${UIFLOW_QML_FILES}
    SOURCES FlowController.cpp FlowController.h
    RESOURCES ${UIFLOW_ICONS}
)

# Inter (OFL) when available - the build container provides it; otherwise the system font.
set(_fonts Inter-Regular.ttf Inter-Medium.ttf Inter-SemiBold.ttf)
if(UIFLOW_FONT_DIR AND EXISTS "${UIFLOW_FONT_DIR}/Inter-Regular.ttf")
    list(TRANSFORM _fonts PREPEND "${UIFLOW_FONT_DIR}/")
    qt_add_resources(uiflow "fonts" PREFIX "/fonts" BASE "${UIFLOW_FONT_DIR}" FILES ${_fonts})
else()
    message(STATUS "Inter font not found (UIFLOW_FONT_DIR): using the system font")
endif()

if(EMSCRIPTEN)
    target_sources(uiflow PRIVATE WebPlatform.cpp WebPlatform.h)
endif()

target_compile_definitions(uiflow PRIVATE UIFLOW_VERSION="${UIFLOW_VERSION_STRING}")
target_link_libraries(uiflow PRIVATE Qt6::Gui Qt6::Qml Qt6::Quick Qt6::QuickControls2 uiflow_core)

# Windows: icon + version resource, generated from the SVG master.
if(WIN32)
    set(UIFLOW_ICO "${CMAKE_CURRENT_BINARY_DIR}/ui-flow.ico")
    add_custom_command(
        OUTPUT "${UIFLOW_ICO}"
        COMMAND python3 "${PROJECT_SOURCE_DIR}/scripts/svg-to-ico.py" "${CMAKE_CURRENT_SOURCE_DIR}/icons/app.svg" "${UIFLOW_ICO}"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/icons/app.svg" "${PROJECT_SOURCE_DIR}/scripts/svg-to-ico.py"
        COMMENT "Generating Windows icon"
        VERBATIM)
    configure_file(ui-flow.rc.in "${CMAKE_CURRENT_BINARY_DIR}/ui-flow.rc" @ONLY)
    set_source_files_properties("${CMAKE_CURRENT_BINARY_DIR}/ui-flow.rc" PROPERTIES OBJECT_DEPENDS "${UIFLOW_ICO}")
    target_sources(uiflow PRIVATE "${CMAKE_CURRENT_BINARY_DIR}/ui-flow.rc")
else()
    # Deployed layout: ui-flow, lib/, plugins/, qml/ (see scripts/deploy.py).
    set_target_properties(uiflow PROPERTIES INSTALL_RPATH "$ORIGIN/lib")
endif()

install(TARGETS uiflow RUNTIME DESTINATION .)

# Web: a static site - our page instead of Qt's sample shell, the loader, the module.
if(EMSCRIPTEN)
    set(UIFLOW_WEB_ENTRY uiflow_entry)
    set_target_properties(uiflow PROPERTIES QT_WASM_EXPORT_NAME ${UIFLOW_WEB_ENTRY})
    configure_file(web/index.html.in "${CMAKE_CURRENT_BINARY_DIR}/web/index.html" @ONLY)
    install(FILES "${CMAKE_CURRENT_BINARY_DIR}/web/index.html" DESTINATION .)
    install(FILES "$<TARGET_FILE_DIR:uiflow>/${UIFLOW_EXE_NAME}.wasm" "$<TARGET_FILE_DIR:uiflow>/qtloader.js"
            DESTINATION .)
    install(FILES icons/app.svg DESTINATION . RENAME favicon.svg)
endif()
