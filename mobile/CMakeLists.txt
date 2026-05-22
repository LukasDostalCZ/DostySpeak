cmake_minimum_required(VERSION 3.21)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/../VERSION" DOSTY_SPEAK_VERSION LIMIT_COUNT 1)
project(DostySpeakMobile VERSION ${DOSTY_SPEAK_VERSION} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)

qt_standard_project_setup()

if(COMMAND qt_policy)
    qt_policy(SET QTP0002 NEW)
endif()

set(MOBILE_SOURCES
    main_mobile.cpp
    MobileBridge.cpp
    MobileBridge.h
)

if(IOS)
    list(APPEND MOBILE_SOURCES
        IosTts.h
        IosTts.mm
    )
endif()

qt_add_executable(dosty-speak-mobile MANUAL_FINALIZATION
    ${MOBILE_SOURCES}
)

qt_add_resources(dosty-speak-mobile mobile_qml_resources
    PREFIX "/mobile"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}"
    FILES
        qml/main.qml
)

target_link_libraries(dosty-speak-mobile
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Quick
)

if(IOS)
    target_link_libraries(dosty-speak-mobile PRIVATE "-framework AVFoundation")
endif()

set_target_properties(dosty-speak-mobile PROPERTIES
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

if(APPLE AND NOT IOS)
    # Development preview on macOS. Homebrew Qt apps often run more reliably
    # from the terminal with Qt paths than from a fully deployed .app bundle.
    get_filename_component(QT_CMAKE_PARENT "${Qt6_DIR}/../../.." ABSOLUTE)
    set_target_properties(dosty-speak-mobile PROPERTIES
        BUILD_RPATH "${QT_CMAKE_PARENT}/lib;/opt/homebrew/opt/qt/lib;/usr/local/opt/qt/lib"
        INSTALL_RPATH "${QT_CMAKE_PARENT}/lib;/opt/homebrew/opt/qt/lib;/usr/local/opt/qt/lib"
    )
    target_compile_definitions(dosty-speak-mobile PRIVATE QT_DESKTOP_PREVIEW=1)
endif()

if(ANDROID)
    set_target_properties(dosty-speak-mobile PROPERTIES
        QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
        QT_ANDROID_PACKAGE_NAME "cz.dosty.speak"
        QT_ANDROID_VERSION_NAME "${PROJECT_VERSION}"
        QT_ANDROID_VERSION_CODE 55
    )
endif()



add_custom_command(TARGET dosty-speak-mobile POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_directory
        "${CMAKE_CURRENT_SOURCE_DIR}/qml"
        "$<$<BOOL:${APPLE}>:$<TARGET_BUNDLE_CONTENT_DIR:dosty-speak-mobile>/Resources/mobile/qml>$<$<NOT:$<BOOL:${APPLE}>>:$<TARGET_FILE_DIR:dosty-speak-mobile>/mobile/qml>"
    COMMENT "copy_mobile_qml_for_preview"
)

qt_finalize_executable(dosty-speak-mobile)
