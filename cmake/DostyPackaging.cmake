# Dosty Speak Linux packaging through CPack.
# Included only on Linux from the root CMakeLists.txt.

if(NOT DEFINED PROJECT_VERSION OR PROJECT_VERSION STREQUAL "")
    set(PROJECT_VERSION "0.0.0")
endif()

set(CPACK_PACKAGE_NAME "dosty-speak")
set(CPACK_PACKAGE_VENDOR "Dosty")
set(CPACK_PACKAGE_CONTACT "Lukáš Dostál <luklin626@gmail.com>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Cross-platform phrase based text-to-speech app")
set(CPACK_PACKAGE_DESCRIPTION "Dosty Speak is a cross-platform phrase based text-to-speech app.")
set(CPACK_PACKAGE_VERSION "${PROJECT_VERSION}")
set(CPACK_PACKAGE_HOMEPAGE_URL "https://github.com/luklin626/dosty-speak")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_FILE_NAME "DostySpeak-${CPACK_PACKAGE_VERSION}-linux-${CMAKE_SYSTEM_PROCESSOR}")
set(CPACK_STRIP_FILES TRUE)

set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Lukáš Dostál <luklin626@gmail.com>")
set(CPACK_DEBIAN_PACKAGE_SECTION "sound")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "espeak-ng, alsa-utils")

set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Applications/Multimedia")
set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
set(CPACK_RPM_PACKAGE_REQUIRES "espeak-ng")

include(CPack)
