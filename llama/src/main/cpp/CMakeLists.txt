cmake_minimum_required(VERSION 3.22.1)
project(picochat_llama LANGUAGES C CXX)
set(CMAKE_CXX_STANDARD 17)

# llama.cpp is fetched at configure time at a pinned tag (needs network once).
set(LLAMA_CURL OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)
set(BUILD_SHARED_LIBS OFF)

include(FetchContent)
FetchContent_Declare(llama
    GIT_REPOSITORY https://github.com/ggml-org/llama.cpp.git
    GIT_TAG b6000
    GIT_SHALLOW TRUE)
FetchContent_MakeAvailable(llama)

add_library(picochat_llama SHARED ${CMAKE_CURRENT_LIST_DIR}/../../../../native/llama_jni.cpp)
target_link_libraries(picochat_llama llama ggml android log)
