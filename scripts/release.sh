#!/usr/bin/env bash

set -e

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
echo "Script Path: ${SCRIPT_PATH}"

if [[ -z $CJSON_VERSION ]]; then
  echo "CJSON_VERSION not set; aborting"
  exit 1
fi

BUILD_DIR="${SCRIPT_PATH}/../build/cjson-build-${CJSON_VERSION}"
echo "Build Path: ${BUILD_DIR}"

if [[ ! -d "${BUILD_DIR}" ]]; then
  echo "Build dir not found: ${BUILD_DIR}"
  exit 1
fi

pushd "${BUILD_DIR}"

echo "Creating ${BUILD_DIR}/cjson.tar.gz"
rm -f "cjson.tar.gz"
tar czf "cjson.tar.gz" iphoneos iphonesimulator macosx

echo "Creating ${BUILD_DIR}/cJSON.xcframework.tar.gz"
rm -f "cJSON.xcframework.tar.gz"
tar czf "cJSON.xcframework.tar.gz" cJSON.xcframework

popd