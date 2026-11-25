#!/usr/bin/env bash
# Builds llama.xcframework (needs macOS + Xcode). Output: native/ios/out/llama.xcframework
set -euo pipefail
cd "$(dirname "$0")"
rm -rf out work && mkdir -p out work
git clone --depth 1 --branch b6000 https://github.com/ggml-org/llama.cpp.git work/llama.cpp
(cd work/llama.cpp && ./build-xcframework.sh)
mv work/llama.cpp/build-apple/llama.xcframework out/
echo "OK: $(pwd)/out/llama.xcframework"
