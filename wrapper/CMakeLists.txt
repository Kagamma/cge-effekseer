cmake_minimum_required (VERSION 3.15)

project(wrapper)

set(CMAKE_CXX_STANDARD 17)

# MSVC Flag
if (MSVC)
    if(USE_MSVC_RUNTIME_LIBRARY_DLL)
        cmake_policy(SET CMP0091 NEW)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    else()
        cmake_policy(SET CMP0091 NEW)
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")
    endif()
endif()

add_library(wrapper main.cpp)
set_target_properties(wrapper PROPERTIES
  OUTPUT_NAME "effekseer"
)

target_include_directories(
    wrapper
    PRIVATE
    ${CMAKE_SOURCE_DIR}/src/Effekseer
    ${CMAKE_SOURCE_DIR}/src/EffekseerRendererGL
    ${EFK_THIRDPARTY_INCLUDES}
)

target_link_libraries(
    wrapper
    PRIVATE
    ${CMAKE_BINARY_DIR}/src/EffekseerRendererGL/libEffekseerRendererGL.a
    ${CMAKE_BINARY_DIR}/src/Effekseer/libEffekseer.a
    Effekseer
    EffekseerRendererGL
)

target_link_directories(
    wrapper
    PRIVATE
    ${EFK_THIRDPARTY_LIBRARY_DIRECTORIES}
)
