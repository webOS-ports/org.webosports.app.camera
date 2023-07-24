project(org.webosports.app.camera)

cmake_minimum_required(VERSION 2.8.8)

# Find includes in corresponding build directories
set(CMAKE_INCLUDE_CURRENT_DIR ON)

# Instruct CMake to run moc automatically when needed.
set(CMAKE_AUTOMOC ON)

# Configure camera output directory
set(CAMERA_OUTPUT_DIR "/media/internal/DCIM")
set(APP_DIR ${CMAKE_CURRENT_BINARY_DIR}/org.webosports.app.camera)

if(UNIX)
    set(CAMERA_OUTPUT_DIR "/tmp/luneos-camera")

    include(webOS/webOS OPTIONAL RESULT_VARIABLE FOUND_WEBOS_MODULE_PATH)
    if(NOT "${FOUND_WEBOS_MODULE_PATH}" STREQUAL "NOTFOUND")
        # LuneOS version
        webos_modules_init(1 0 0 QUALIFIER RC3)
        webos_component(0 5 0)

        # also check that the root path is not the fallback one
        if(NOT "${WEBOS_INSTALL_ROOT}" STREQUAL "/usr/local/webos")
            set(APP_DIR ${WEBOS_INSTALL_WEBOS_APPLICATIONSDIR}/org.webosports.app.camera)
            set(CAMERA_OUTPUT_DIR "/media/internal/DCIM")
        endif()
    endif()
else()
    # Windows, so desktop too
    set(CAMERA_OUTPUT_DIR "C:/temp/luneos-camera")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden -Wall -std=c++1z")
add_definitions(-DCAMERA_OUTPUT_DIR="${CAMERA_OUTPUT_DIR}")

# Standard install paths. Needs to be set before finding packages.
include(GNUInstallDirs)

find_package(Qt6 REQUIRED COMPONENTS Qml Quick Multimedia Gui ShaderTools)

set(APP_DATA appinfo.json icon.png icon-256x256.png)
set(PLUGIN_DIR ${APP_DIR}/CameraApp)

message(STATUS "APP_DIR=${APP_DIR}")
message(STATUS "CAMERA_OUTPUT_DIR=${CAMERA_OUTPUT_DIR}")

install(FILES ${APP_DATA} DESTINATION ${APP_DIR})
install(DIRECTORY qml DESTINATION ${APP_DIR})

# make non compiled files visible in qtcreator
file(GLOB_RECURSE NON_COMPILED_FILES *.qml *.js *.svg *.png *.json *.sci qmldir)
add_custom_target(NON_COMPILED_TARGET ALL SOURCES ${NON_COMPILED_FILES})

qt6_add_shaders(org.webosports.app.camera "camera_shaders"
     FILES
         "qml/components/cornershader.frag"
)

add_subdirectory(CameraApp)
