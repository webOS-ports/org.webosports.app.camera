# QML plugin
set(plugin_SRCS
    components.cpp
    cpuboost.cpp
    fileoperations.cpp
    flashled.cpp
    imagetools.cpp
    jpegexif.cpp
    storagemonitor.cpp
    storagelocations.cpp
    )

set(plugin_HDRS
    components.h
    cpuboost.h
    fileoperations.h
    flashled.h
    imagetools.h
    jpegexif.h
    storagemonitor.h
    storagelocations.h
    )

add_library(camera-qml MODULE ${plugin_SRCS} ${plugin_HDRS})

#make sure that the qmldir file is in the QML2_IMPORT_PATH when running from QtC
file(COPY qmldir DESTINATION ${CMAKE_CURRENT_BINARY_DIR})

target_link_libraries(camera-qml
    ${Qt6Qml_LIBRARIES}
    ${Qt6Quick_LIBRARIES}
    ${Qt6Multimedia_LIBRARIES}
    PkgConfig::LIBEXIF
    )

install(TARGETS camera-qml DESTINATION ${PLUGIN_DIR})
install(FILES qmldir DESTINATION ${PLUGIN_DIR})

