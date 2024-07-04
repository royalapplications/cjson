#!/usr/bin/env bash

set -e

CJSON_VERSION_STABLE="1.7.18" # https://github.com/DaveGamble/cJSON/releases
IOS_VERSION_MIN="13.4"
MACOS_VERSION_MIN="11.0"
CODESIGN_ID="-"

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

BUILD_ROOT_DIR="${SCRIPT_PATH}/../build"
echo "Build Path: ${BUILD_ROOT_DIR}"
mkdir -p "${BUILD_ROOT_DIR}"

if [[ -z $CJSON_VERSION ]]; then
  echo "CJSON_VERSION not set; falling back to ${CJSON_VERSION_STABLE} (Stable)"
  CJSON_VERSION="${CJSON_VERSION_STABLE}"
fi

if [[ ! -f "${BUILD_ROOT_DIR}/v${CJSON_VERSION}.tar.gz" ]]; then
  echo "Downloading v${CJSON_VERSION}.tar.gz"
  curl -fL "https://github.com/DaveGamble/cJSON/archive/refs/tags/v${CJSON_VERSION}.tar.gz" -o "${BUILD_ROOT_DIR}/v${CJSON_VERSION}.tar.gz"
fi

SRC_DIR="${BUILD_ROOT_DIR}/cjson-src-${CJSON_VERSION}"
BUILD_DIR="${BUILD_ROOT_DIR}/cjson-build-${CJSON_VERSION}"

if [[ ! -d "${SRC_DIR}" ]]; then
  mkdir -p "${SRC_DIR}"
  tar xzf "${BUILD_ROOT_DIR}/v${CJSON_VERSION}.tar.gz" -C "${SRC_DIR}" --strip-components=1
fi

if [[ -d "${BUILD_DIR}" ]]; then
  rm -r "${BUILD_DIR}"
fi

mkdir -p "${BUILD_DIR}"

BUILD_DIR_MACOS="${BUILD_DIR}/macosx"
BUILD_DIR_IOS="${BUILD_DIR}/iphoneos"
BUILD_DIR_IOS_SIM="${BUILD_DIR}/iphonesimulator"

if [[ ! -d "${BUILD_DIR_MACOS}" ]]; then
  mkdir -p "${BUILD_DIR_MACOS}"
fi

if [[ ! -d "${BUILD_DIR_IOS}" ]]; then
  mkdir -p "${BUILD_DIR_IOS}"
fi

if [[ ! -d "${BUILD_DIR_IOS_SIM}" ]]; then
  mkdir -p "${BUILD_DIR_IOS_SIM}"
fi

if [[ ! -d "${BUILD_DIR_MACOS}_temp" ]]; then
  mkdir -p "${BUILD_DIR_MACOS}_temp"
fi

if [[ ! -d "${BUILD_DIR_IOS}_temp" ]]; then
  mkdir -p "${BUILD_DIR_IOS}_temp"
fi

if [[ ! -d "${BUILD_DIR_IOS_SIM}_temp" ]]; then
  mkdir -p "${BUILD_DIR_IOS_SIM}_temp"
fi

copy_output() {
  local target_dir="$1"

  mkdir "${target_dir}/lib"
  cp "libcjson.a" "${target_dir}/lib"

  mkdir "${target_dir}/include"
  mkdir "${target_dir}/include/cjson"
  cp "${SRC_DIR}/cJSON.h" "${target_dir}/include/cjson"
}

build_macos() {
  echo "Building for macOS Universal"

  pushd "${BUILD_DIR_MACOS}_temp"

  local sdk_root=$(xcrun --sdk macosx --show-sdk-path)
  local additional_c_flags="-mmacosx-version-min=${MACOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DENABLE_CJSON_TEST=Off \
    -DBUILD_SHARED_LIBS=Off \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="Darwin" \
    -DCMAKE_C_FLAGS="${additional_c_flags}"

  make

  copy_output "${BUILD_DIR_MACOS}"

  popd
}

build_ios() {
  echo "Building for iOS ARM64"

  pushd "${BUILD_DIR_IOS}_temp"

  local sdk_root=$(xcrun --sdk iphoneos --show-sdk-path)
  local additional_c_flags="-mios-version-min=${IOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DENABLE_CJSON_TEST=Off \
    -DBUILD_SHARED_LIBS=Off \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    -DCMAKE_C_FLAGS="${additional_c_flags}"

  make

  copy_output "${BUILD_DIR_IOS}"

  popd
}

build_ios_sim() {
  echo "Building for iOS Simulator"

  pushd "${BUILD_DIR_IOS_SIM}_temp"

  local sdk_root=$(xcrun --sdk iphonesimulator --show-sdk-path)
  local additional_c_flags="-mios-simulator-version-min=${IOS_VERSION_MIN}"

  cmake "${SRC_DIR}" \
    -DENABLE_CJSON_TEST=Off \
    -DBUILD_SHARED_LIBS=Off \
    -DCMAKE_SYSROOT="${sdk_root}" \
    -DCMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
    -DCMAKE_SYSTEM_NAME="iOS" \
    -DCMAKE_C_FLAGS="${additional_c_flags}"

  make

  copy_output "${BUILD_DIR_IOS_SIM}"

  popd
}

build_macos
build_ios
build_ios_sim

if [[ ! -d "${BUILD_DIR}/cJSON.xcframework" ]]; then
  xcodebuild -create-xcframework \
    -library "${BUILD_DIR_MACOS}/lib/libcjson.a" \
    -library "${BUILD_DIR_IOS}/lib/libcjson.a" \
    -library "${BUILD_DIR_IOS_SIM}/lib/libcjson.a" \
    -output "${BUILD_DIR}/cJSON.xcframework"

  codesign \
    --force --deep --strict \
    --sign "${CODESIGN_ID}" \
    "${BUILD_DIR}/cJSON.xcframework"
fi