# QML plugin
set(plugin_SRCS
    components.cpp
    advancedcamerasettings.cpp
    droidcamerafactory.cpp
    fileoperations.cpp
    foldersmodel.cpp
    pieslice.cpp
    storagemonitor.cpp
    storagelocations.cpp
    )

set(plugin_HDRS
    components.h
    advancedcamerasettings.h
    droidcamerafactory.h
    fileoperations.h
    foldersmodel.h
    pieslice.h
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
    )

# The QtMultimedia GStreamer SPI headers (QtMultimedia/spi/, used by
# DroidCameraFactory) install under the versioned include dir, which only the
# Private target puts on the include path. Present when qtmultimedia was
# built with -DFEATURE_gstreamer_qt_api=ON; the factory compiles to a stub
# otherwise (__has_include).
find_package(Qt6 QUIET COMPONENTS MultimediaPrivate)
if(TARGET Qt6::MultimediaPrivate)
    target_link_libraries(camera-qml Qt6::MultimediaPrivate)
endif()

install(TARGETS camera-qml DESTINATION ${PLUGIN_DIR})
install(FILES qmldir DESTINATION ${PLUGIN_DIR})

