cmake_minimum_required(VERSION 3.16)

file(STRINGS "${CMAKE_CURRENT_SOURCE_DIR}/VERSION" DOSTY_SPEAK_VERSION LIMIT_COUNT 1)
project(DostySpeak
    VERSION ${DOSTY_SPEAK_VERSION}
    DESCRIPTION "Cross-platform phrase based text-to-speech app"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 COMPONENTS Widgets Network QUIET)

if (Qt6_FOUND)
    set(QT_PACKAGE Qt6)
else()
    find_package(Qt5 COMPONENTS Widgets Network REQUIRED)
    set(QT_PACKAGE Qt5)
endif()

set(CMAKE_AUTOMOC ON)

if(WIN32)
    enable_language(RC)
    configure_file(
        "${CMAKE_CURRENT_SOURCE_DIR}/src/windows/dosty-speak.rc.in"
        "${CMAKE_CURRENT_BINARY_DIR}/dosty-speak.rc"
        @ONLY
    )
    set(DOSTY_SPEAK_PLATFORM_SOURCES "${CMAKE_CURRENT_BINARY_DIR}/dosty-speak.rc")
else()
    set(DOSTY_SPEAK_PLATFORM_SOURCES "")
endif()

add_executable(dosty-speak WIN32
    src/main.cpp
    src/AppInfo.cpp
    src/AppInfo.h
    src/AppPaths.cpp
    src/AppPaths.h
    src/I18n.cpp
    src/I18n.h
    src/Settings.cpp
    src/Settings.h
    src/PhraseStore.cpp
    src/PhraseStore.h
    src/VoiceCatalog.cpp
    src/VoiceCatalog.h
    src/Speaker.cpp
    src/Speaker.h
    src/MainWindow.cpp
    src/MainWindow.h
    ${DOSTY_SPEAK_PLATFORM_SOURCES}
)

target_link_libraries(dosty-speak PRIVATE
    ${QT_PACKAGE}::Widgets
    ${QT_PACKAGE}::Network
)

if(APPLE)
    set_source_files_properties(resources/icons/dosty-speak.icns PROPERTIES MACOSX_PACKAGE_LOCATION "Resources")
    target_sources(dosty-speak PRIVATE resources/icons/dosty-speak.icns)
    set_target_properties(dosty-speak PROPERTIES
        MACOSX_BUNDLE TRUE
        MACOSX_BUNDLE_ICON_FILE dosty-speak.icns
        MACOSX_BUNDLE_BUNDLE_NAME "Dosty Speak"
        MACOSX_BUNDLE_GUI_IDENTIFIER "cz.dosty.dostyspeak"
    )
endif()

target_compile_definitions(dosty-speak PRIVATE
    APP_VERSION="${PROJECT_VERSION}"
    APP_ID="dosty-speak"
    APP_NAME="Dosty Speak"
    APP_AUTHOR="Lukáš Dostál"
    APP_LICENSE="MIT"
    RESOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/resources"
)

if(APPLE)
    add_custom_command(TARGET dosty-speak POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E make_directory
                "$<TARGET_BUNDLE_CONTENT_DIR:dosty-speak>/Resources"
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_SOURCE_DIR}/resources"
                "$<TARGET_BUNDLE_CONTENT_DIR:dosty-speak>/Resources/resources"
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
                "${CMAKE_CURRENT_SOURCE_DIR}/resources/icons/dosty-speak.icns"
                "$<TARGET_BUNDLE_CONTENT_DIR:dosty-speak>/Resources/dosty-speak.icns"
    )
else()
    add_custom_command(TARGET dosty-speak POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_directory
                "${CMAKE_CURRENT_SOURCE_DIR}/resources"
                "$<TARGET_FILE_DIR:dosty-speak>/resources"
    )
endif()

install(TARGETS dosty-speak
    BUNDLE DESTINATION .
    RUNTIME DESTINATION bin
)
install(DIRECTORY resources/i18n DESTINATION share/dosty-speak)
install(DIRECTORY resources/voices DESTINATION share/dosty-speak)
install(FILES resources/dosty-speak.desktop DESTINATION share/applications)

install(DIRECTORY resources/icons DESTINATION share/dosty-speak)
install(FILES resources/icons/256x256/dosty-speak.png DESTINATION share/icons/hicolor/256x256/apps RENAME dosty-speak.png)



# Linux DEB/RPM packaging.
if(UNIX AND NOT APPLE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/cmake/DostyPackaging.cmake")
    include("${CMAKE_CURRENT_SOURCE_DIR}/cmake/DostyPackaging.cmake")
endif()
