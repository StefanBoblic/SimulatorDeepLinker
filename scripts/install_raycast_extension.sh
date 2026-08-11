#!/bin/zsh
set -euo pipefail

SCRIPT_DIRECTORY="${0:A:h}"
PROJECT_DIRECTORY="${SCRIPT_DIRECTORY:h}"
EXTENSION_DIRECTORY="${PROJECT_DIRECTORY}/RaycastExtension"

if ! open -Ra Raycast 2>/dev/null; then
    echo "Raycast is not installed. Download it from https://www.raycast.com/"
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "npm is required to install the local Raycast extension."
    exit 1
fi

echo "Installing Raycast extension dependencies…"
cd "${EXTENSION_DIRECTORY}"
npm ci

echo "Importing SimulatorDeepLinker into Raycast…"
echo "Keep this process running while developing. Press Control-C to stop."
npm run dev
