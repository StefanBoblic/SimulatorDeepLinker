#!/bin/zsh
set -euo pipefail

APP_NAME="SimulatorDeepLinker"
SCHEME="SimulatorDeepLinker"
VERSION="${1:?Usage: scripts/package_release.sh 0.1.0}"

BUILD_DIR="./build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"
CLI_BUILD_PATH="${BUILD_DIR}/cli"
CLI_BINARY_PATH="${CLI_BUILD_PATH}/release/simulator-deep-linker"
CLI_ZIP_PATH="${BUILD_DIR}/simulator-deep-linker-cli-${VERSION}.zip"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

xcodebuild \
  -scheme "${SCHEME}" \
  -configuration Release \
  -archivePath "${ARCHIVE_PATH}" \
  archive

ditto -c -k --keepParent \
  "${APP_PATH}" \
  "${ZIP_PATH}"

swift build \
  --package-path CLI \
  --configuration release \
  --scratch-path "${CLI_BUILD_PATH}"

ditto -c -k \
  "${CLI_BINARY_PATH}" \
  "${CLI_ZIP_PATH}"

echo ""
echo "Release zip:"
echo "${ZIP_PATH}"
echo "${CLI_ZIP_PATH}"

echo ""
echo "sha256:"
shasum -a 256 "${ZIP_PATH}"
shasum -a 256 "${CLI_ZIP_PATH}"
