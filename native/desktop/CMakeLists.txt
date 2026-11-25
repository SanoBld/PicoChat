# Desktop (Windows / Linux / macOS) build of the llama.cpp JNI bridge.
#   cmake -S native/desktop -B native/build -DCMAKE_BUILD_TYPE=Release -DPICO_OUT=$PWD/desktopApp/native-libs/<os>-<arch>
#   cmake --build native/build --config Release
# <os>-<arch>: windows-x64, windows-arm64, linux-x64, linux-arm64, macos-x64, macos-arm64
cmake_minimum_required(VERSION 3.22)
project(picochat_llama LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
if(NOT PICO_OUT)
    set(PICO_OUT ${CMAKE_BINARY_DIR}/out)
endif()

set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF)

include(FetchContent)
FetchContent_Declare(llama
    GIT_REPOSITORY https://github.com/ggml-org/llama.cpp.git
    GIT_TAG b6000
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(llama)

find_package(JNI REQUIRED)
add_library(picochat_llama SHARED ${CMAKE_CURRENT_LIST_DIR}/../llama_jni.cpp)
target_include_directories(picochat_llama PRIVATE ${JNI_INCLUDE_DIRS})
target_link_libraries(picochat_llama PRIVATE llama ggml)
set_target_properties(picochat_llama PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${PICO_OUT}
    RUNTIME_OUTPUT_DIRECTORY_RELEASE ${PICO_OUT}
    LIBRARY_OUTPUT_DIRECTORY ${PICO_OUT}
    LIBRARY_OUTPUT_DIRECTORY_RELEASE ${PICO_OUT})
