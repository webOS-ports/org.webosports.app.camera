# Build-host tools for the app's artwork, not part of the app: vectorfit
# redraws the legacy camera's button bitmaps as SVG, svgcheck renders an
# SVG with Qt's own SVG renderer (the one QML uses on the device) and
# compares it with the bitmap it was drawn after. See README.md.
cmake_minimum_required(VERSION 3.16)
project(vectorize CXX)
set(CMAKE_CXX_STANDARD 17)
find_package(Qt6 REQUIRED COMPONENTS Gui Svg)
add_executable(svgcheck svgcheck.cpp)
target_compile_options(svgcheck PRIVATE -Wall -Wextra -Wpedantic -Wshadow -Wold-style-cast)
target_link_libraries(svgcheck PRIVATE Qt6::Gui Qt6::Svg)
add_executable(vectorfit vectorfit.cpp)
target_compile_options(vectorfit PRIVATE -Wall -Wextra -Wpedantic -Wshadow -Wold-style-cast)
target_link_libraries(vectorfit PRIVATE Qt6::Gui Qt6::Svg)
