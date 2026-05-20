cmake_minimum_required(VERSION 3.16)

project(DostySpeak
    VERSION 0.2.49
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
    $<$<PLATFORM_ID:Windows>:src/windows/dosty-speak.rc>
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


# Linux package generation via CPack.
set(CPACK_PACKAGE_NAME "dosty-speak")
set(CPACK_PACKAGE_VENDOR "Lukas Dostal")
set(CPACK_PACKAGE_CONTACT "Lukas Dostal")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Cross-platform phrase based text-to-speech app")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/luklin626/dosty-speak")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_FILE_NAME "DostySpeak-${PROJECT_VERSION}-${CMAKE_SYSTEM_PROCESSOR}")

set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Lukas Dostal")
set(CPACK_DEBIAN_PACKAGE_SECTION "sound")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "libqt6widgets6 | libqt5widgets5, libqt6network6 | libqt5network5, espeak-ng, alsa-utils")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
set(CPACK_RPM_PACKAGE_REQUIRES "espeak-ng")

include(CPack)
