cmake_minimum_required(VERSION 3.13)

project(morphcard)

set(CMAKE_VERBOSE_MAKEFILE on)

add_compile_options(
  -fexceptions
  -frtti
  -std=c++20
  -Wall
  -Wpedantic
)

file(GLOB morphcard_SRC CONFIGURE_DEPENDS ../../../../common/cpp/react/renderer/components/morphcard/*.cpp)

add_library(
  react_codegen_morphcard
  SHARED
  ${morphcard_SRC}
)

target_include_directories(react_codegen_morphcard PUBLIC ../../../../common/cpp)

find_package(fbjni REQUIRED CONFIG)
find_package(ReactAndroid REQUIRED CONFIG)

target_link_libraries(
  react_codegen_morphcard
  fbjni::fbjni
  ReactAndroid::fabricjni
  ReactAndroid::folly_runtime
  ReactAndroid::glog
  ReactAndroid::jsi
  ReactAndroid::mapbufferjni
  ReactAndroid::react_codegen_rncore
  ReactAndroid::react_debug
  ReactAndroid::react_nativemodule_core
  ReactAndroid::react_render_componentregistry
  ReactAndroid::react_render_core
  ReactAndroid::react_render_debug
  ReactAndroid::react_render_graphics
  ReactAndroid::react_render_mapbuffer
  ReactAndroid::react_utils
  ReactAndroid::rrc_view
  ReactAndroid::yoga
)
