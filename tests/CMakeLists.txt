# Unit tests for the camera's C++ that needs no camera: the JPEG/EXIF editing
# (CameraApp/jpegexif.cpp) and the post-processing around it
# (CameraApp/imagetools.cpp). See README.md.
#
# Off by default, so image builds are unaffected:
#   cmake -DBUILD_TESTING=ON ...
# It needs googletest in the sysroot.

find_package(GTest REQUIRED)

add_executable(camera-app-tests
    unit/main.cpp
    unit/test_jpegexif.cpp
    unit/test_imagetools.cpp
    ${PROJECT_SOURCE_DIR}/CameraApp/jpegexif.cpp
    ${PROJECT_SOURCE_DIR}/CameraApp/imagetools.cpp
    ${PROJECT_SOURCE_DIR}/CameraApp/imagetools.h
)
set_target_properties(camera-app-tests PROPERTIES AUTOMOC ON)
target_include_directories(camera-app-tests PRIVATE ${PROJECT_SOURCE_DIR}/CameraApp)
target_link_libraries(camera-app-tests PRIVATE GTest::gtest Qt6::Gui PkgConfig::LIBEXIF)

add_test(NAME camera-app-unit COMMAND camera-app-tests)
