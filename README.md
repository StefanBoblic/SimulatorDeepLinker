# SimulatorDeepLinker

<p align="center">
  <img src="docs/logo.png" alt="SimulatorDeepLinker icon" width="160">
</p>

A small native macOS app for saving deep links and opening them in an iOS Simulator with one click.

## Features

- Save, search, edit, reorder, and delete deep links
- Open universal links, web URLs, and custom URL schemes
- Target the currently booted simulator or a simulator by UDID
- Use the interface in English or Russian
- Keep everything locally in a JSON file — no accounts or tracking

## Install

With Homebrew:

```bash
brew tap StefanBoblic/tap
brew install --cask simulator-deep-linker
```

Or download the latest app from [GitHub Releases](https://github.com/StefanBoblic/SimulatorDeepLinker/releases/latest), unzip it, and move it to `/Applications`.

## Use

1. Start an iOS Simulator.
2. Add a URL such as `myapp://product/123` or `https://example.com/product/123`.
3. Choose **Booted simulator** or enter a simulator UDID.
4. Click **Open** or press `⌘↩`.

SimulatorDeepLinker runs:

```bash
xcrun simctl openurl <device> <url>
```

Xcode and at least one iOS Simulator are required.

## Shared storage

Open **Settings → Shared Storage** to choose an existing JSON file, create a shared copy, copy its path, or return to the default location. Changes made by external tools are reloaded automatically.

The file contains a JSON array. Dates use ISO 8601:

```json
[
  {
    "id": "8DB1E10D-20DB-4A4B-95B8-845156B4873A",
    "title": "Product details",
    "urlString": "myapp://product/123",
    "createdAt": "2026-08-11T09:00:00Z",
    "updatedAt": "2026-08-11T09:00:00Z"
  }
]
```

For a Raycast extension, expose the path as a required preference with `"type": "file"`, then use Node's `fs` APIs to read and atomically replace the JSON file.

## Development

```bash
git clone https://github.com/StefanBoblic/SimulatorDeepLinker.git
cd SimulatorDeepLinker
open SimulatorDeepLinker.xcodeproj
```

Build and run the app from Xcode. The target intentionally does not use App Sandbox because sandboxed apps cannot execute `xcrun`.

To package a release:

```bash
./scripts/package_release.sh 0.1.0
```

Saved links stay on your Mac under Application Support. See [LICENSE](LICENSE) for license information.
