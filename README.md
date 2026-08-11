# SimulatorDeepLinker

<p align="center">
  <img src="docs/logo.png" alt="SimulatorDeepLinker icon" width="160">
</p>

A small native macOS app for saving deep links and opening them in an iOS Simulator with one click.

## Features

- Save, search, edit, reorder, and delete deep links
- Open universal links, web URLs, and custom URL schemes
- Target the currently booted simulator or a simulator by UDID
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
